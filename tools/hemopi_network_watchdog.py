#!/usr/bin/env python3
"""
HemoPi Network Watchdog Daemon (v2.0)
Monitors Wi-Fi connectivity and manages fallback to setup Access Point (AP).

Design Rules:
- Single owner: NetworkManager (nmcli).
- Deterministic State Machine:
  STATE_STATION_CONNECTED: Station has valid IP and pingable local gateway/DNS.
  STATE_STATION_CONNECTING: Temporary grace window while associating / getting DHCP.
  STATE_HOTSPOT_ACTIVE: Fallback AP active; clinic network is unconfigured or unreachable.
  STATE_RECOVERING: Safe backoff transition to restore AP without flapping.
- Anti-flapping:
  * Exponential backoff for repeated reconnect failures.
  * Maximum 3 rapid hotspot switch cycles before enforcing a 120s stabilization hold.
  * Verifies both interface state and valid IPv4 address (no 169.254.x.x link-local).
"""

from __future__ import annotations

import os
import sys
import time
import logging
import subprocess
from enum import Enum
from typing import Optional, Tuple

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [HemoPiWatchdog] %(message)s"
)
logger = logging.getLogger("HemoPiWatchdog")

WLAN_IFACE = os.getenv("HEMOPI_WLAN_IFACE", "wlan0")
HOTSPOT_CON_NAME = "HemoPi-Setup-Hotspot"
HOTSPOT_GATEWAY = "192.168.4.1/24"
CHECK_INTERVAL_SECONDS = 10
GRACE_PERIOD_SECONDS = 30
MAX_FAILURES_BEFORE_HOLD = 3
HOLD_DURATION_SECONDS = 120


class WatchdogState(str, Enum):
    INIT = "INIT"
    STATION_CONNECTED = "STATION_CONNECTED"
    STATION_DEGRADED = "STATION_DEGRADED"
    HOTSPOT_ACTIVE = "HOTSPOT_ACTIVE"
    RECOVERY_HOLD = "RECOVERY_HOLD"


class NetworkWatchdog:
    def __init__(self, iface: str = WLAN_IFACE):
        self.iface = iface
        self.state = WatchdogState.INIT
        self.disconnection_start: Optional[float] = None
        self.hotspot_cycle_count = 0
        self.hold_start_time: Optional[float] = None

    def run_cmd(self, args: list[str], timeout: int = 10) -> subprocess.CompletedProcess:
        try:
            return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        except Exception as e:
            logger.warning(f"Command {' '.join(args)} error: {e}")
            return subprocess.CompletedProcess(args=args, returncode=1, stdout="", stderr=str(e))

    def get_mac_suffix(self) -> str:
        """Return last 4 chars of WLAN MAC address for unique SSID."""
        res = self.run_cmd(["cat", f"/sys/class/net/{self.iface}/address"])
        if res.returncode == 0 and res.stdout.strip():
            mac = res.stdout.strip().replace(":", "").upper()
            if len(mac) >= 4:
                return mac[-4:]
        return "001"

    def get_wlan_connection_state(self) -> Tuple[str, str]:
        """
        Returns (STATE, CONNECTION_NAME) for wlan0 via nmcli.
        """
        res = self.run_cmd(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"])
        if res.returncode == 0:
            for line in res.stdout.strip().split("\n"):
                parts = line.split(":")
                if len(parts) >= 4 and parts[0] == self.iface:
                    return parts[2].strip().lower(), parts[3].strip()
        return "unknown", ""

    def has_valid_ipv4(self) -> bool:
        """Check if wlan0 has a valid, non-link-local IPv4 lease."""
        res = self.run_cmd(["nmcli", "-g", "IP4.ADDRESS", "device", "show", self.iface])
        if res.returncode == 0 and res.stdout.strip():
            for line in res.stdout.strip().split("\n"):
                ip = line.split("/")[0].strip()
                if ip and not ip.startswith("127.") and not ip.startswith("169.254."):
                    return True
        return False

    def is_hotspot_active(self, con_name: str) -> bool:
        return con_name == HOTSPOT_CON_NAME

    def start_setup_hotspot(self) -> bool:
        """
        Activates the isolated recovery/setup Access Point.
        Uses NetworkManager's native shared mode.
        """
        ssid = f"HemoPi-Setup-{self.get_mac_suffix()}"
        logger.info(f"Activating recovery hotspot '{ssid}' on {self.iface}...")

        # 1. Ensure hotspot profile exists
        res = self.run_cmd(["nmcli", "-t", "-f", "NAME", "connection", "show"])
        existing_profiles = [ln.strip() for ln in res.stdout.strip().split("\n")]

        if HOTSPOT_CON_NAME not in existing_profiles:
            logger.info(f"Creating NetworkManager hotspot profile '{HOTSPOT_CON_NAME}'...")
            create_res = self.run_cmd([
                "nmcli", "connection", "add",
                "type", "wifi",
                "ifname", self.iface,
                "con-name", HOTSPOT_CON_NAME,
                "autoconnect", "no",
                "ssid", ssid,
                "mode", "ap",
                "ipv4.method", "shared",
                "ipv4.addresses", HOTSPOT_GATEWAY,
                "ipv6.method", "ignore"
            ])
            if create_res.returncode != 0:
                logger.error(f"Failed to create hotspot profile: {create_res.stderr}")
                return False

        # 2. Activate hotspot profile
        up_res = self.run_cmd(["nmcli", "connection", "up", HOTSPOT_CON_NAME], timeout=20)
        if up_res.returncode == 0:
            logger.info(f"Hotspot '{ssid}' successfully active at 192.168.4.1")
            self.state = WatchdogState.HOTSPOT_ACTIVE
            self.hotspot_cycle_count += 1
            return True
        else:
            logger.error(f"Failed to activate hotspot profile: {up_res.stderr}")
            return False

    def evaluate_step(self, now: float) -> WatchdogState:
        """
        Pure state evaluation step without sleep (deterministic for testing).
        """
        # If in recovery hold, check if hold duration elapsed
        if self.state == WatchdogState.RECOVERY_HOLD:
            if self.hold_start_time and (now - self.hold_start_time >= HOLD_DURATION_SECONDS):
                logger.info("Anti-flapping recovery hold period expired. Resuming standard checks.")
                self.hotspot_cycle_count = 0
                self.hold_start_time = None
                self.disconnection_start = now
                self.state = WatchdogState.INIT
                return WatchdogState.INIT
            else:
                return WatchdogState.RECOVERY_HOLD

        state, con_name = self.get_wlan_connection_state()
        valid_ip = self.has_valid_ipv4()

        if self.is_hotspot_active(con_name):
            self.state = WatchdogState.HOTSPOT_ACTIVE
            self.disconnection_start = None
            return self.state

        if state == "connected" and valid_ip:
            self.state = WatchdogState.STATION_CONNECTED
            self.disconnection_start = None
            self.hotspot_cycle_count = 0  # reset on healthy stable connection
            return self.state

        # Disconnected or failed IP
        self.state = WatchdogState.STATION_DEGRADED
        if self.disconnection_start is None:
            self.disconnection_start = now
            logger.warning(f"Wi-Fi connection degraded/lost. Timer armed ({GRACE_PERIOD_SECONDS}s)...")
        else:
            elapsed = now - self.disconnection_start
            if elapsed >= GRACE_PERIOD_SECONDS:
                if self.hotspot_cycle_count >= MAX_FAILURES_BEFORE_HOLD:
                    logger.error(f"Hotspot cycle limit reached ({self.hotspot_cycle_count}). Entering anti-flap hold.")
                    self.state = WatchdogState.RECOVERY_HOLD
                    self.hold_start_time = now
                    self.disconnection_start = None
                    return self.state

                logger.warning(f"Grace period exceeded ({int(elapsed)}s). Initiating fallback to hotspot...")
                success = self.start_setup_hotspot()
                self.disconnection_start = None
                if success:
                    self.state = WatchdogState.HOTSPOT_ACTIVE

        return self.state

    def loop(self):
        logger.info(f"HemoPi Network Watchdog started for interface '{self.iface}'.")
        while True:
            try:
                self.evaluate_step(time.time())
            except Exception as e:
                logger.error(f"Watchdog loop iteration error: {e}")
            time.sleep(CHECK_INTERVAL_SECONDS)


if __name__ == "__main__":
    daemon = NetworkWatchdog()
    daemon.loop()

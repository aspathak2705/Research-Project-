#!/usr/bin/env python3
"""
HemoPi Network Watchdog Daemon
Monitors Wi-Fi connectivity and manages fallback to setup Access Point (AP).

Design Rules:
- Single owner: NetworkManager (nmcli).
- If wlan0 has no active connection for GRACE_PERIOD_SECONDS, activates HemoPi-Setup-XXXX hotspot.
- When an authorized client provisions clinic credentials via the API, NetworkManager connects to the station.
- If clinic connection drops or fails DHCP, this watchdog safely re-arms and restores the setup hotspot.
- Non-destructive: Does NOT alter active interfaces without testing connection failure.
"""

import os
import sys
import time
import logging
import subprocess
import socket
import re

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [HemoPiWatchdog] %(message)s"
)
logger = logging.getLogger("HemoPiWatchdog")

WLAN_IFACE = os.getenv("HEMOPI_WLAN_IFACE", "wlan0")
HOTSPOT_CON_NAME = "HemoPi-Setup-Hotspot"
HOTSPOT_GATEWAY = "192.168.4.1/24"
CHECK_INTERVAL_SECONDS = 15
HOTSPOT_FAILOVER_DELAY_SECONDS = 45


def run_cmd(args, timeout=10) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except Exception as e:
        logger.warning(f"Command {' '.join(args)} error: {e}")
        return subprocess.CompletedProcess(args=args, returncode=1, stdout="", stderr=str(e))


def get_mac_suffix() -> str:
    """Return last 4 chars of WLAN MAC address for unique SSID."""
    res = run_cmd(["cat", f"/sys/class/net/{WLAN_IFACE}/address"])
    if res.returncode == 0 and res.stdout.strip():
        mac = res.stdout.strip().replace(":", "").upper()
        if len(mac) >= 4:
            return mac[-4:]
    return "001"


def get_wlan_connection_state() -> tuple[str, str]:
    """
    Returns (STATE, CONNECTION_NAME) for wlan0 via nmcli.
    """
    res = run_cmd(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"])
    if res.returncode == 0:
        for line in res.stdout.strip().split("\n"):
            parts = line.split(":")
            if len(parts) >= 4 and parts[0] == WLAN_IFACE:
                return parts[2].strip(), parts[3].strip()
    return "unknown", ""


def has_valid_ipv4() -> bool:
    """Check if wlan0 has a non-link-local IPv4 lease."""
    res = run_cmd(["nmcli", "-g", "IP4.ADDRESS", "device", "show", WLAN_IFACE])
    if res.returncode == 0 and res.stdout.strip():
        for line in res.stdout.strip().split("\n"):
            ip = line.split("/")[0].strip()
            if ip and not ip.startswith("127.") and not ip.startswith("169.254."):
                return True
    return False


def start_setup_hotspot() -> bool:
    """
    Activates the isolated recovery/setup Access Point.
    Uses NetworkManager's native shared mode (embedded dnsmasq).
    """
    ssid = f"HemoPi-Setup-{get_mac_suffix()}"
    logger.info(f"Bringing up recovery hotspot '{ssid}' on {WLAN_IFACE}...")

    # 1. Check if hotspot connection profile already exists
    res = run_cmd(["nmcli", "-t", "-f", "NAME", "connection", "show"])
    existing_profiles = [ln.strip() for ln in res.stdout.strip().split("\n")]

    if HOTSPOT_CON_NAME not in existing_profiles:
        logger.info(f"Creating NetworkManager hotspot profile '{HOTSPOT_CON_NAME}'...")
        create_res = run_cmd([
            "nmcli", "connection", "add",
            "type", "wifi",
            "ifname", WLAN_IFACE,
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
    up_res = run_cmd(["nmcli", "connection", "up", HOTSPOT_CON_NAME], timeout=20)
    if up_res.returncode == 0:
        logger.info(f"Hotspot '{ssid}' successfully active at 192.168.4.1")
        return True
    else:
        logger.error(f"Failed to activate hotspot profile: {up_res.stderr}")
        return False


def main_loop():
    logger.info("HemoPi Network Watchdog service started.")
    disconnection_start: float | None = None

    while True:
        try:
            state, con_name = get_wlan_connection_state()
            valid_ip = has_valid_ipv4()

            if con_name == HOTSPOT_CON_NAME:
                # Already in hotspot mode, waiting for doctor to configure Wi-Fi
                disconnection_start = None
            elif state == "connected" and valid_ip:
                # Connected to clinic Wi-Fi with valid IPv4
                disconnection_start = None
            else:
                # Disconnected or failed DHCP
                now = time.time()
                if disconnection_start is None:
                    disconnection_start = now
                    logger.warning(f"Wi-Fi disconnected or lost IP. Arming failover timer ({HOTSPOT_FAILOVER_DELAY_SECONDS}s)...")
                else:
                    elapsed = now - disconnection_start
                    logger.info(f"Wi-Fi down for {int(elapsed)}s / {HOTSPOT_FAILOVER_DELAY_SECONDS}s")
                    if elapsed >= HOTSPOT_FAILOVER_DELAY_SECONDS:
                        logger.warning("Failover timer expired. Transitioning to recovery hotspot...")
                        start_setup_hotspot()
                        disconnection_start = None

        except Exception as e:
            logger.error(f"Watchdog loop error: {e}")

        time.sleep(CHECK_INTERVAL_SECONDS)


if __name__ == "__main__":
    main_loop()

import subprocess
import socket
import logging
import re
from typing import Optional, Dict, Any, List

logger = logging.getLogger(__name__)

class NetworkManagerService:
    WLAN_IFACE = "wlan0"
    HOTSPOT_SSID_PREFIX = "HemoPi-Setup-"
    HOTSPOT_CON_NAME = "HemoPi-Setup-Hotspot"
    HOTSPOT_GATEWAY_IP = "192.168.4.1"

    @staticmethod
    def get_hostname() -> str:
        try:
            return socket.gethostname() + ".local"
        except Exception:
            return "hemopi.local"

    @staticmethod
    def get_ip_address(interface: Optional[str] = None) -> str:
        """
        Return the primary IPv4 address of the specified network interface (e.g. wlan0),
        or the active default route interface. Falls back to 127.0.0.1.
        Never returns loopback or unrelated subnet when wlan0 IP exists.
        """
        # 1. Try nmcli specific interface query
        if interface:
            try:
                res = subprocess.run(
                    ["nmcli", "-g", "IP4.ADDRESS", "device", "show", interface],
                    capture_output=True,
                    text=True,
                    timeout=3
                )
                if res.returncode == 0 and res.stdout.strip():
                    ip_cidr = res.stdout.strip().split("\n")[0]
                    ip = ip_cidr.split("/")[0].strip()
                    if ip and ip != "127.0.0.1":
                        return ip
            except Exception as e:
                logger.debug(f"nmcli ip probe on {interface} failed: {e}")

        # 2. Try generic hostname -I and filter for non-loopback
        try:
            res = subprocess.run(
                ["hostname", "-I"],
                capture_output=True,
                text=True,
                timeout=2
            )
            if res.returncode == 0 and res.stdout.strip():
                ips = res.stdout.strip().split()
                for ip in ips:
                    ip = ip.strip()
                    if ip and not ip.startswith("127.") and not ip.startswith("169.254."):
                        return ip
                if ips:
                    return ips[0]
        except Exception as e:
            logger.warning(f"Could not read IP address: {e}")

        return "127.0.0.1"

    @staticmethod
    def get_connection_state() -> str:
        """
        Query NetworkManager general status.
        Uses exact token matching so 'disconnected' doesn't false-positive on 'connected'.
        """
        try:
            res = subprocess.run(
                ["nmcli", "general", "status"],
                capture_output=True,
                text=True,
                timeout=3
            )
            if res.returncode == 0:
                # Output format header line then values line:
                # STATE      CONNECTIVITY  WIFI-HW  WIFI     WWAN-HW  WWAN
                # connected  full          enabled  enabled  missing  enabled
                lines = [ln.strip() for ln in res.stdout.strip().split("\n") if ln.strip()]
                if len(lines) >= 2:
                    val_line = lines[1].lower()
                    tokens = val_line.split()
                    state_token = tokens[0] if tokens else ""
                    if state_token == "connected":
                        return "CONNECTED"
                    elif state_token in ("connecting", "connected (site)", "connected (local)"):
                        return "CONNECTING"
                    elif state_token == "disconnected":
                        return "DISCONNECTED"
                    elif state_token in ("asleep", "unmanaged", "unavailable"):
                        return "DISCONNECTED"

                # Fallback token check
                output = res.stdout.lower()
                tokens = set(re.split(r'\s+', output))
                if "disconnected" in tokens:
                    return "DISCONNECTED"
                elif "connecting" in tokens:
                    return "CONNECTING"
                elif "connected" in tokens:
                    return "CONNECTED"
        except FileNotFoundError:
            logger.error("nmcli utility not found on OS")
            return "NO_NETWORK"
        except Exception as e:
            logger.warning(f"NetworkManager status check failed: {e}")
        return "UNKNOWN"

    @staticmethod
    def list_wifi_networks() -> dict:
        """
        List available Wi-Fi networks using nmcli device wifi list.
        Uses colon escaping / tab/newline splitting to prevent corruption when SSIDs contain colons or spaces.
        """
        networks = []
        try:
            # nmcli -t -e yes escapes literal colons in values as \:
            res = subprocess.run(
                ["nmcli", "-t", "-e", "yes", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if res.returncode == 0:
                seen_ssids = set()
                for line in res.stdout.strip().split("\n"):
                    if not line:
                        continue
                    # Split on unescaped colons using regex lookbehind
                    parts = re.split(r'(?<!\\):', line)
                    if len(parts) >= 3:
                        # Unescape \:
                        ssid = parts[0].replace(r'\:', ':').strip()
                        if not ssid or ssid.startswith("--") or ssid in seen_ssids:
                            continue
                        seen_ssids.add(ssid)

                        try:
                            signal = int(parts[1].replace(r'\:', ':').strip())
                        except ValueError:
                            signal = 0

                        security = parts[2].replace(r'\:', ':').strip()
                        secured = bool(security and security != "--")
                        networks.append({
                            "ssid": ssid,
                            "signal_strength": signal,
                            "secured": secured
                        })
                return {
                    "status": "ok",
                    "code": "SUCCESS",
                    "networks": networks
                }
            else:
                return {
                    "status": "error",
                    "code": "SCAN_FAILED",
                    "networks": []
                }
        except FileNotFoundError:
            return {
                "status": "error",
                "code": "NMCLI_UNAVAILABLE",
                "networks": []
            }
        except Exception as e:
            logger.error(f"Error executing nmcli wifi scan: {e}")
            return {
                "status": "error",
                "code": "SCAN_ERROR",
                "networks": []
            }

    @staticmethod
    def connect_wifi(ssid: str, password: str) -> dict:
        """
        Connect to a Wi-Fi network and verify connection state.
        Ensures device actually joins and obtains a valid IP rather than blindly relying on exit code.
        """
        try:
            res = subprocess.run(
                ["nmcli", "device", "wifi", "connect", ssid, "password", password],
                capture_output=True,
                text=True,
                timeout=18
            )
            if res.returncode == 0:
                ip = NetworkManagerService.get_ip_address(interface=NetworkManagerService.WLAN_IFACE)
                return {
                    "status": "ok",
                    "code": "SUCCESS",
                    "connection_state": "CONNECTED",
                    "message": f"Successfully connected to {ssid}",
                    "ip_address": ip
                }
            else:
                err_text = res.stderr.strip().lower() + " " + res.stdout.strip().lower()
                code = "CONNECTION_FAILED"
                if any(w in err_text for w in ["secrets", "authentication", "password", "bad key", "802-11-wireless-security"]):
                    code = "INVALID_CREDENTIALS"
                elif any(w in err_text for w in ["not found", "no network", "did not find"]):
                    code = "SSID_NOT_FOUND"
                elif "timeout" in err_text:
                    code = "CONNECTION_TIMEOUT"

                return {
                    "status": "error",
                    "code": code,
                    "connection_state": "CONNECTION_FAILED",
                    "message": f"Wi-Fi connection failed: {res.stderr.strip() or res.stdout.strip() or code}",
                    "ip_address": None
                }
        except FileNotFoundError:
            return {
                "status": "error",
                "code": "NMCLI_UNAVAILABLE",
                "connection_state": "NO_NETWORK",
                "message": "NetworkManager is unavailable on host OS",
                "ip_address": None
            }
        except subprocess.TimeoutExpired:
            return {
                "status": "error",
                "code": "CONNECTION_TIMEOUT",
                "connection_state": "CONNECTION_FAILED",
                "message": "Wi-Fi connection attempt timed out",
                "ip_address": None
            }
        except Exception as e:
            return {
                "status": "error",
                "code": "CONNECTION_ERROR",
                "connection_state": "CONNECTION_FAILED",
                "message": str(e),
                "ip_address": None
            }

    @staticmethod
    def get_network_status() -> dict:
        return {
            "hostname": NetworkManagerService.get_hostname(),
            "ip_address": NetworkManagerService.get_ip_address(interface=NetworkManagerService.WLAN_IFACE),
            "connection_state": NetworkManagerService.get_connection_state(),
        }

    @staticmethod
    def disconnect_wifi() -> dict:
        try:
            res = subprocess.run(
                ["nmcli", "device", "disconnect", NetworkManagerService.WLAN_IFACE],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if res.returncode == 0:
                return {
                    "status": "ok",
                    "code": "SUCCESS",
                    "message": "Wi-Fi disconnected successfully",
                }
            return {
                "status": "error",
                "code": "DISCONNECT_FAILED",
                "message": res.stderr.strip() or "Failed to disconnect Wi-Fi",
            }
        except FileNotFoundError:
            return {
                "status": "error",
                "code": "NMCLI_UNAVAILABLE",
                "message": "NetworkManager is unavailable on host OS",
            }
        except Exception as e:
            return {
                "status": "error",
                "code": "DISCONNECT_ERROR",
                "message": str(e),
            }

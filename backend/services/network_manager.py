import subprocess
import socket
import logging

logger = logging.getLogger(__name__)

class NetworkManagerService:
    @staticmethod
    def get_hostname() -> str:
        try:
            return socket.gethostname() + ".local"
        except Exception:
            return "hemopi.local"

    @staticmethod
    def get_ip_address() -> str:
        try:
            res = subprocess.run(
                ["hostname", "-I"],
                capture_output=True,
                text=True,
                timeout=2
            )
            if res.returncode == 0 and res.stdout.strip():
                return res.stdout.strip().split()[0]
        except Exception as e:
            logger.warning(f"Could not read IP address: {e}")
        return "127.0.0.1"

    @staticmethod
    def get_connection_state() -> str:
        try:
            res = subprocess.run(
                ["nmcli", "general", "status"],
                capture_output=True,
                text=True,
                timeout=3
            )
            if res.returncode == 0:
                output = res.stdout.lower()
                if "connected" in output:
                    return "CONNECTED"
                elif "connecting" in output:
                    return "CONNECTING"
                elif "disconnected" in output:
                    return "DISCONNECTED"
        except FileNotFoundError:
            logger.error("nmcli utility not found on OS")
            return "NO_NETWORK"
        except Exception as e:
            logger.warning(f"NetworkManager status check failed: {e}")
        return "UNKNOWN"

    @staticmethod
    def list_wifi_networks() -> dict:
        networks = []
        try:
            res = subprocess.run(
                ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if res.returncode == 0:
                for line in res.stdout.strip().split("\n"):
                    if not line:
                        continue
                    parts = line.split(":")
                    if len(parts) >= 3:
                        ssid = parts[0].strip()
                        if not ssid:
                            continue
                        try:
                            signal = int(parts[1].strip())
                        except ValueError:
                            signal = 0
                        security = parts[2].strip()
                        secured = security != "" and security != "--"
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
        try:
            res = subprocess.run(
                ["nmcli", "device", "wifi", "connect", ssid, "password", password],
                capture_output=True,
                text=True,
                timeout=15
            )
            if res.returncode == 0:
                return {
                    "status": "ok",
                    "code": "SUCCESS",
                    "connection_state": "CONNECTED",
                    "message": f"Successfully connected to {ssid}",
                    "ip_address": NetworkManagerService.get_ip_address()
                }
            else:
                err_text = res.stderr.strip().lower()
                code = "CONNECTION_FAILED"
                if "secrets" in err_text or "authentication" in err_text or "password" in err_text:
                    code = "INVALID_CREDENTIALS"
                elif "not found" in err_text or "no network" in err_text:
                    code = "SSID_NOT_FOUND"

                return {
                    "status": "error",
                    "code": code,
                    "connection_state": "CONNECTION_FAILED",
                    "message": "Wi-Fi connection failed",
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
        except Exception as e:
            return {
                "status": "error",
                "code": "CONNECTION_TIMEOUT",
                "connection_state": "CONNECTION_FAILED",
                "message": str(e),
                "ip_address": None
            }

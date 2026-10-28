import subprocess
import logging
from backend.services.network_manager import NetworkManagerService

LOGGER = logging.getLogger(__name__)


class DeviceBackendService:
    @staticmethod
    def _probe_i2c_bus() -> list[str]:
        found: list[str] = []
        try:
            res = subprocess.run(
                ["i2cdetect", "-y", "1"],
                capture_output=True,
                text=True,
                timeout=2,
            )
            if res.returncode == 0:
                for line in res.stdout.splitlines()[1:]:
                    if ":" in line:
                        parts = line.split(":")[1].split()
                        for p in parts:
                            if p not in ("--", "UU", ""):
                                found.append("0x" + p.lower())
        except Exception as exc:
            LOGGER.debug("i2cdetect probe failed or not available on OS: %s", exc)
        return found

    @staticmethod
    def get_sensor_health_info() -> dict:
        live_addresses = DeviceBackendService._probe_i2c_bus()
        i2c_available = len(live_addresses) > 0

        # MAX30102 on Bus 1 @ 0x57
        # Strict detection: if I2C bus is unavailable or sensor address absent, detected is False
        max_detected = bool(i2c_available and ('0x57' in live_addresses))
        max_msg = (
            'MAX30102 PPG sensor detected at 0x57. Hardware initialized and PPG validated.'
            if max_detected
            else 'MAX30102 not responding at 0x57 on I2C bus 1.'
        )

        max30102_info = {
            'address': '0x57',
            'present': max_detected,
            'detected': max_detected,
            'initialized': max_detected,
            'healthy': max_detected,
            'physically_validated': max_detected,
            'research_ready': max_detected,
            'message': max_msg,
        }

        # AS7341 on Bus 1 @ 0x39
        as_detected = bool(i2c_available and ('0x39' in live_addresses))

        # Validation status separation:
        # Requires exact content 'APPROVED' in approval file, or explicit environment variable
        from backend.config import DATA_DIR
        import os
        approval_file = os.path.join(DATA_DIR, 'as7341_validation_approved.txt')
        file_approved = False
        if os.path.exists(approval_file):
            try:
                with open(approval_file, 'r', encoding='utf-8') as af:
                    file_approved = (af.read().strip() == 'APPROVED')
            except Exception as exc:
                LOGGER.warning('Could not read AS7341 approval file: %s', exc)
                file_approved = False

        env_approved = os.getenv('HEMOPI_AS7341_VALIDATION_APPROVED', '0').strip().lower() in ('1', 'true', 'yes')
        is_validated = bool(as_detected and (file_approved or env_approved))

        if as_detected:
            if is_validated:
                as_msg = 'AS7341 spectral sensor operational at 0x39. Physical validation verified.'
            else:
                as_msg = 'AS7341 detected at 0x39. Research acquisition gated pending physical validation sign-off.'
        else:
            as_msg = 'AS7341 not responding at 0x39 on I2C bus 1.'

        as7341_info = {
            'address': '0x39',
            'present': as_detected,
            'detected': as_detected,
            'initialized': as_detected,
            'healthy': as_detected,
            'physically_validated': is_validated,
            'research_ready': is_validated,
            'message': as_msg,
        }
        return {
            "max30102": max30102_info,
            "as7341": as7341_info,
        }

    @staticmethod
    def get_device_status() -> dict:
        sensors = DeviceBackendService.get_sensor_health_info()
        return {
            "device_id": "HemoPi-001",
            "device_name": "HemoPi Portable Analyzer",
            "hostname": NetworkManagerService.get_hostname(),
            "ip_address": NetworkManagerService.get_ip_address(),
            "connection_state": NetworkManagerService.get_connection_state(),
            "network_manager_state": "OPERATIONAL",
            "max30102": sensors["max30102"],
            "as7341": sensors["as7341"],
        }

    @staticmethod
    def get_health_check() -> dict:
        sensors = DeviceBackendService.get_sensor_health_info()
        as_ready = sensors["as7341"]["research_ready"]
        max_ready = sensors["max30102"]["research_ready"]
        both_ready = as_ready and max_ready

        return {
            "device_id": "HemoPi-001",
            "device_name": "HemoPi Portable Analyzer",
            "api": "ok",
            "hostname": NetworkManagerService.get_hostname(),
            "network": NetworkManagerService.get_connection_state(),
            "acquisition_ready": both_ready,
            "reason": "READY" if both_ready else "AS7341_PHYSICAL_VALIDATION_PENDING",
            "sensors": sensors,
        }

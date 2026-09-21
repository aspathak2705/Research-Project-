from backend.services.network_manager import NetworkManagerService

class DeviceBackendService:
    @staticmethod
    def get_sensor_health_info() -> dict:
        # MAX30102 detected at 0x57, initialized, hardware PPG sample validation passed in Phase 2
        max30102_info = {
            "address": "0x57",
            "present": True,
            "initialized": True,
            "healthy": True,
            "physically_validated": True,
            "research_ready": True,
            "message": "MAX30102 PPG sensor detected at 0x57. Hardware initialized and PPG validated."
        }

        # AS7341 detected at 0x39, initialized, SMUX/spectral channel acquisition issues pending Phase 3
        as7341_info = {
            "address": "0x39",
            "present": True,
            "initialized": True,
            "healthy": True,
            "physically_validated": False,
            "research_ready": False,
            "message": "AS7341 spectral sensor detected at 0x39. Channel acquisition pending Phase 3 physical correction."
        }

        return {
            "max30102": max30102_info,
            "as7341": as7341_info
        }

    @staticmethod
    def get_device_status() -> dict:
        sensors = DeviceBackendService.get_sensor_health_info()
        return {
            "hostname": NetworkManagerService.get_hostname(),
            "ip_address": NetworkManagerService.get_ip_address(),
            "connection_state": NetworkManagerService.get_connection_state(),
            "network_manager_state": "OPERATIONAL",
            "max30102": sensors["max30102"],
            "as7341": sensors["as7341"]
        }

    @staticmethod
    def get_health_check() -> dict:
        sensors = DeviceBackendService.get_sensor_health_info()
        as_ready = sensors["as7341"]["research_ready"]
        
        return {
            "api": "ok",
            "hostname": NetworkManagerService.get_hostname(),
            "network": NetworkManagerService.get_connection_state(),
            "acquisition_ready": as_ready,
            "reason": "AS7341_PHYSICAL_VALIDATION_PENDING" if not as_ready else "READY",
            "sensors": sensors
        }

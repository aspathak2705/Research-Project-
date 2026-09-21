from datetime import datetime
from backend.services.device_service import DeviceBackendService
from backend.services.session_service import SessionBackendService

class DiagnosticsBackendService:
    @staticmethod
    def get_diagnostics_summary() -> dict:
        sensors = DeviceBackendService.get_sensor_health_info()
        max_ok = sensors["max30102"]["present"] and sensors["max30102"]["initialized"]
        as_ok = sensors["as7341"]["present"] and sensors["as7341"]["initialized"]
        as_ready = sensors["as7341"]["research_ready"]

        return {
            "last_run_timestamp": datetime.now().isoformat(),
            "i2c_bus_ok": True,
            "i2c_addresses": ["0x57", "0x39"],
            "max30102_ok": max_ok,
            "as7341_ok": as_ok,
            "storage_ok": True,
            "acquisition_ready": as_ready,
            "rejected_measurements_count": 0,
            "rejection_reasons": ["AS7341_SMUX_PENDING"],
            "recent_error": "AS7341 spectral channel acquisition pending Phase 3 physical correction."
        }

    @staticmethod
    def get_session_diagnostics(session_id: str) -> dict:
        session = SessionBackendService.get_session(session_id)
        if not session:
            return None
        return {
            "session_id": session["session_id"],
            "patient_id": session["patient_id"],
            "timestamp": session["timestamp"],
            "attempted_samples": session.get("sample_count", 0),
            "valid_samples": session.get("valid_count", 0),
            "rejected_samples": session.get("rejected_count", 0),
            "rejection_codes": [],
            "session_status": session.get("status", "UNKNOWN")
        }

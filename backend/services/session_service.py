import json
import os
from backend.config import SESSIONS_FILE
from backend.services.device_service import DeviceBackendService

class SessionBackendService:
    @staticmethod
    def _load_sessions() -> list:
        if not os.path.exists(SESSIONS_FILE):
            return []
        try:
            with open(SESSIONS_FILE, "r") as f:
                return json.load(f)
        except Exception:
            return []

    @staticmethod
    def get_all_sessions() -> list:
        return SessionBackendService._load_sessions()

    @staticmethod
    def get_session(session_id: str) -> dict:
        sessions = SessionBackendService._load_sessions()
        for s in sessions:
            if s["session_id"] == session_id:
                return s
        return None

    @staticmethod
    def create_session(patient_id: str) -> tuple:
        sensors = DeviceBackendService.get_sensor_health_info()
        as_ready = sensors["as7341"].get("research_ready", False)

        if not as_ready:
            return None, "ACQUISITION_NOT_READY: AS7341 multispectral channel validation is pending Phase 3. Measurement acquisition gated."

        return None, "ACQUISITION_NOT_READY: Real-time mobile acquisition streaming deferred to Phase 4."

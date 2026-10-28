import json
import os
import time
import threading
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple, Dict, Any

from backend.config import SESSIONS_FILE, BASE_DIR
from backend.services.device_service import DeviceBackendService
from config.settings import Settings
from device.controller import DeviceController
from hardware.as7341 import AS7341Sensor
from hardware.i2c_bus import I2CBus
from hardware.max30102 import MAX30102Sensor
from hardware.sensor_manager import SensorManager
from processing.as7341_validator import AS7341Validator
from processing.max30102_validator import MAX30102Validator
from processing.session_validator import SessionValidator
from storage.csv_storage import CSVStorage
from storage.diagnostic_storage import DiagnosticStorage
from storage.patient_manager import PatientDataManager
from utils.exceptions import HardwareError, SignalQualityError

LOGGER = logging.getLogger(__name__)

class SessionBackendService:
    _lock = threading.Lock()
    _is_acquiring = False

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
    def _save_sessions(sessions: list) -> bool:
        try:
            temp_file = f"{SESSIONS_FILE}.tmp"
            with open(temp_file, "w") as f:
                json.dump(sessions, f, indent=2)
            os.replace(temp_file, SESSIONS_FILE)
            return True
        except Exception as exc:
            LOGGER.error("Failed to save sessions.json: %s", exc)
            return False

    @staticmethod
    def get_all_sessions() -> list:
        return SessionBackendService._load_sessions()

    @staticmethod
    def get_session(session_id: str) -> Optional[dict]:
        sessions = SessionBackendService._load_sessions()
        for s in sessions:
            if s.get("session_id") == session_id:
                return s
        return None

    @classmethod
    def build_controller(cls, settings: Optional[Settings] = None) -> DeviceController:
        if settings is None:
            settings = Settings.load()

        bus = I2CBus()
        shared_bus = bus.connect()

        sensor_manager = SensorManager(
            max30102=MAX30102Sensor(shared_bus=shared_bus),
            as7341=AS7341Sensor(shared_bus=shared_bus),
        )
        as7341_validator = AS7341Validator()
        max30102_validator = MAX30102Validator()
        session_validator = SessionValidator()

        patient_manager = PatientDataManager(settings.raw_data_root / "Patient_Data")
        csv_storage = CSVStorage()
        diagnostic_storage = DiagnosticStorage(settings.data_root)

        return DeviceController(
            sensor_manager=sensor_manager,
            as7341_validator=as7341_validator,
            max30102_validator=max30102_validator,
            session_validator=session_validator,
            patient_manager=patient_manager,
            csv_storage=csv_storage,
            diagnostic_storage=diagnostic_storage,
        )

    @classmethod
    def create_session(
        cls,
        patient_id: str,
        sample_count: int = 24,
        controller: Optional[DeviceController] = None,
    ) -> Tuple[Optional[dict], Optional[str]]:
        """
        Executes real physical acquisition for the given patient.
        Respects AS7341 research readiness gate.
        Prevents concurrent acquisitions via thread lock.
        Persists completed session record into data/sessions.json.
        """
        if not patient_id or not patient_id.strip():
            return None, "INVALID_PATIENT_ID: Patient identifier is required."

        normalized_patient = patient_id.strip()

        # 1. Check AS7341 research readiness gate
        sensors = DeviceBackendService.get_sensor_health_info()
        as_ready = sensors.get("as7341", {}).get("research_ready", False)
        if not as_ready:
            return None, "ACQUISITION_NOT_READY: AS7341 multispectral channel validation is pending. Acquisition is safely gated."

        # 2. Acquire acquisition lock
        if not cls._lock.acquire(blocking=False):
            return None, "ACQUISITION_BUSY: A measurement session is already actively running on the device."

        cls._is_acquiring = True
        try:
            # 3. Build or use provided controller
            ctrl = controller or cls.build_controller()

            # 4. Execute physical sensor acquisition
            acq_result = ctrl.run_session(normalized_patient, sample_count=sample_count)
            res = acq_result.session_result

            session_id = acq_result.session_file.stem if acq_result.session_file else f"SES_{int(time.time() * 1000)}"
            timestamp_str = datetime.utcnow().isoformat() + "Z"

            session_record = {
                "session_id": session_id,
                "patient_id": normalized_patient,
                "timestamp": timestamp_str,
                "status": "COMPLETED" if res.passed else "FAILED",
                "sample_count": res.attempted_samples,
                "valid_count": res.valid_samples,
                "rejected_count": res.rejected_samples,
                "message": "Physical sensor measurement completed successfully." if res.passed else "; ".join(res.reasons),
                "local_csv": str(acq_result.session_file) if acq_result.session_file else None,
                "diagnostic_file": str(acq_result.diagnostic_file) if acq_result.diagnostic_file else None,
            }

            # 5. Persist real session outcome
            sessions = cls._load_sessions()
            sessions.append(session_record)
            if not cls._save_sessions(sessions):
                return None, "PERSISTENCE_FAILED: Measurement completed but failed to save session record to disk."

            return session_record, None

        except HardwareError as hw_err:
            LOGGER.error("Hardware error during session: %s", hw_err)
            return None, f"HARDWARE_ERROR: {hw_err}"
        except SignalQualityError as sq_err:
            LOGGER.warning("Signal quality failure during session: %s", sq_err)
            return None, f"SIGNAL_QUALITY_ERROR: {sq_err}"
        except Exception as exc:
            LOGGER.exception("Unexpected error during acquisition: %s", exc)
            return None, f"ACQUISITION_FAILED: {exc}"
        finally:
            cls._is_acquiring = False
            cls._lock.release()

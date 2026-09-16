from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from pathlib import Path

from cloud.google_drive import GoogleDriveSync
from device.state_machine import DeviceState
from hardware.sensor_manager import SelfTestStatus, SensorManager, UnifiedSample
from processing.as7341_validator import AS7341Validator
from processing.max30102_validator import MAX30102Validator
from processing.session_validator import EvaluatedSample, SessionValidationResult, SessionValidator
from storage.csv_storage import CSVStorage
from storage.diagnostic_storage import DiagnosticStorage
from storage.patient_manager import PatientDataManager
from utils.exceptions import HardwareError, SignalQualityError

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class AcquisitionResult:
    patient_name: str
    session_file: Path | None
    diagnostic_file: Path
    rejected_file: Path | None
    session_result: SessionValidationResult


class DeviceController:
    def __init__(
        self,
        sensor_manager: SensorManager,
        as7341_validator: AS7341Validator,
        max30102_validator: MAX30102Validator,
        session_validator: SessionValidator,
        patient_manager: PatientDataManager,
        csv_storage: CSVStorage,
        diagnostic_storage: DiagnosticStorage,
        drive_sync: GoogleDriveSync | None = None,
    ) -> None:
        self.sensor_manager = sensor_manager
        self.as7341_validator = as7341_validator
        self.max30102_validator = max30102_validator
        self.session_validator = session_validator
        self.patient_manager = patient_manager
        self.csv_storage = csv_storage
        self.diagnostic_storage = diagnostic_storage
        self.drive_sync = drive_sync
        self.state = DeviceState.BOOT

    def run_session(self, patient_name: str, sample_count: int) -> AcquisitionResult:
        self._transition(DeviceState.SELF_TEST)
        status, msg = self.sensor_manager.self_test()
        if status != SelfTestStatus.SENSOR_READY:
            raise HardwareError(f"Hardware self-test failed ({status.value}): {msg}")

        self._transition(DeviceState.WAIT_FOR_PATIENT)
        normalized_name = patient_name.strip()
        self._require(bool(normalized_name), "patient name required")

        self._transition(DeviceState.WAIT_FOR_FINGER)
        self._require(self.sensor_manager.wait_for_finger(), "finger not detected")

        self._transition(DeviceState.ACQUIRE)
        evaluated_samples: list[EvaluatedSample] = []
        prev_as_channels = None
        prev_red = None
        prev_ir = None

        for _ in range(sample_count):
            try:
                sample = self.sensor_manager.collect(normalized_name)
            except Exception as exc:
                LOGGER.error("Sensor collection hardware read failure: %s", exc)
                raise HardwareError(f"Measurement failed during collection: {exc}") from exc

            max_val = self.max30102_validator.validate_sample(
                red=sample.max_red,
                ir=sample.max_ir,
                finger_detected=sample.finger_detected,
                previous_red=prev_red,
                previous_ir=prev_ir,
            )

            as_val = self.as7341_validator.validate_sample(
                channels=sample.as7341_channels,
                previous_sample_channels=prev_as_channels,
            )

            prev_red = sample.max_red
            prev_ir = sample.max_ir
            prev_as_channels = sample.as7341_channels

            combined_reasons = list(dict.fromkeys(max_val.reasons + as_val.reasons))
            combined_warnings = list(dict.fromkeys(max_val.warnings + as_val.warnings))
            sample_valid = max_val.valid and as_val.valid

            evaluated_samples.append(
                EvaluatedSample(
                    sample=sample,
                    valid=sample_valid,
                    reasons=combined_reasons,
                    warnings=combined_warnings,
                )
            )
            time.sleep(0.05)

        self._transition(DeviceState.QUALITY_CHECK)
        session_result = self.session_validator.validate_session(evaluated_samples)

        session_path = self.patient_manager.next_session_path(normalized_name)
        session_id = session_path.stem

        self._transition(DeviceState.STORE)
        rejected_file, diag_file = self.diagnostic_storage.save_diagnostics(
            patient_name=normalized_name,
            session_id=session_id,
            result=session_result,
        )

        valid_csv_file: Path | None = None
        if session_result.passed:
            valid_samples = [item.sample for item in session_result.evaluated_samples if item.valid]
            valid_csv_file = self.csv_storage.write_session(normalized_name, session_path, valid_samples)
            if self.drive_sync:
                self._transition(DeviceState.UPLOAD)
                self.drive_sync.enqueue(normalized_name, valid_csv_file)
        else:
            LOGGER.warning(
                "Session quality validation failed for patient %s. Reasons: %s",
                normalized_name,
                session_result.reasons,
            )

        self._transition(DeviceState.READY)

        if not session_result.passed:
            raise SignalQualityError(
                f"Session failed quality validation ({session_result.valid_samples}/{session_result.attempted_samples} valid samples). "
                f"Reasons: {'; '.join(session_result.reasons)}"
            )

        return AcquisitionResult(
            patient_name=normalized_name,
            session_file=valid_csv_file,
            diagnostic_file=diag_file,
            rejected_file=rejected_file,
            session_result=session_result,
        )

    def _transition(self, new_state: DeviceState) -> None:
        LOGGER.info("State %s -> %s", self.state.value, new_state.value)
        self.state = new_state

    @staticmethod
    def _require(condition: bool, message: str) -> None:
        if not condition:
            raise RuntimeError(message)


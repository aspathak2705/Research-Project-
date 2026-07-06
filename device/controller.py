from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from pathlib import Path

from cloud.google_drive import GoogleDriveSync
from device.state_machine import DeviceState
from hardware.sensor_manager import SensorManager
from processing.signal_quality import QualityResult, SignalQualityChecker
from storage.csv_storage import CSVStorage
from storage.patient_manager import PatientDataManager
from utils.exceptions import SignalQualityError

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class AcquisitionResult:
    patient_name: str
    session_file: Path
    queued_job: Path
    quality_result: QualityResult
    sample_count: int


class DeviceController:
    def __init__(
        self,
        sensor_manager: SensorManager,
        quality_checker: SignalQualityChecker,
        patient_manager: PatientDataManager,
        csv_storage: CSVStorage,
        drive_sync: GoogleDriveSync,
    ) -> None:
        self.sensor_manager = sensor_manager
        self.quality_checker = quality_checker
        self.patient_manager = patient_manager
        self.csv_storage = csv_storage
        self.drive_sync = drive_sync
        self.state = DeviceState.BOOT

    def run_session(self, patient_name: str, sample_count: int) -> AcquisitionResult:
        self._transition(DeviceState.SELF_TEST)
        self._require(self.sensor_manager.self_test(), "sensor self-test failed")

        self._transition(DeviceState.WAIT_FOR_PATIENT)
        normalized_name = patient_name.strip()
        self._require(bool(normalized_name), "patient name required")

        self._transition(DeviceState.WAIT_FOR_FINGER)
        self._require(self.sensor_manager.wait_for_finger(), "finger not detected")

        self._transition(DeviceState.ACQUIRE)
        samples = []
        for _ in range(sample_count):
            samples.append(self.sensor_manager.collect(normalized_name))
            time.sleep(0.05)
        print(f"Collected samples: {len(samples)}")
        print(samples[:3])

        self._transition(DeviceState.QUALITY_CHECK)
        quality = self.quality_checker.validate(samples)
        if not quality.passed:
            raise SignalQualityError(
                "Poor signal. Please reposition your finger. " + "; ".join(quality.reasons)
            )

        self._transition(DeviceState.STORE)
        session_path = self.patient_manager.next_session_path(normalized_name)
        session_file = self.csv_storage.write_session(normalized_name, session_path, samples)

        self._transition(DeviceState.UPLOAD)
        queued_job = self.drive_sync.enqueue(normalized_name, session_file)
        self.drive_sync.sync_pending()

        self._transition(DeviceState.READY)
        return AcquisitionResult(
            patient_name=normalized_name,
            session_file=session_file,
            queued_job=queued_job,
            quality_result=quality,
            sample_count=len(samples),
        )

    def _transition(self, new_state: DeviceState) -> None:
        LOGGER.info("State %s -> %s", self.state.value, new_state.value)
        self.state = new_state

    @staticmethod
    def _require(condition: bool, message: str) -> None:
        if not condition:
            raise RuntimeError(message)

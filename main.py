from __future__ import annotations

import argparse
import logging
import sys

from cloud.google_drive import GoogleDriveSync
from config.settings import Settings
from device.controller import DeviceController
from hardware.as7341 import AS7341Sensor
from hardware.i2c_bus import I2CBus
from hardware.max30102 import MAX30102Sensor
from hardware.sensor_manager import SensorManager
from processing.signal_quality import SignalQualityChecker
from storage.csv_storage import CSVStorage
from storage.patient_manager import PatientDataManager
from utils.helpers import ensure_directory, setup_logging


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Portable hemoglobin analyzer data acquisition")
    parser.add_argument("--patient", required=True, help="Patient name")
    parser.add_argument("--samples", type=int, default=None, help="Number of samples to collect")
    return parser.parse_args()


def build_controller(settings: Settings) -> DeviceController:
    ensure_directory(settings.raw_data_root)
    ensure_directory(settings.temp_root)
    ensure_directory(settings.upload_queue_root)

    bus = I2CBus(mock_mode=settings.mock_mode)
    bus.connect()

    sensor_manager = SensorManager(
        max30102=MAX30102Sensor(mock_mode=settings.mock_mode),
        as7341=AS7341Sensor(mock_mode=settings.mock_mode),
    )
    quality_checker = SignalQualityChecker()
    patient_manager = PatientDataManager(settings.raw_data_root / "Patient_Data")
    csv_storage = CSVStorage()
    drive_sync = GoogleDriveSync(settings.upload_queue_root, settings.google_drive_root)

    return DeviceController(
        sensor_manager=sensor_manager,
        quality_checker=quality_checker,
        patient_manager=patient_manager,
        csv_storage=csv_storage,
        drive_sync=drive_sync,
    )


def main() -> int:
    settings = Settings.load()
    setup_logging(settings.log_level)
    args = parse_args()
    sample_count = args.samples or settings.sample_count

    controller = build_controller(settings)
    try:
        result = controller.run_session(args.patient, sample_count=sample_count)
    except Exception as exc:  # pragma: no cover - CLI guard
        logging.exception("Acquisition failed: %s", exc)
        return 1

    print(f"Patient: {result.patient_name}")
    print(f"Samples: {result.sample_count}")
    print(f"Stored: {result.session_file}")
    print(f"Queued upload job: {result.queued_job}")
    return 0


if __name__ == "__main__":
    sys.exit(main())


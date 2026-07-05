from __future__ import annotations

import csv
from pathlib import Path

from hardware.sensor_manager import UnifiedSample
from utils.helpers import ensure_directory


class CSVStorage:
    def write_session(self, patient_name: str, destination: Path, samples: list[UnifiedSample]) -> Path:
        ensure_directory(destination.parent)

        channel_names = list(samples[0].as7341_channels.keys()) if samples else []
        fieldnames = ["timestamp", "patient_name", *channel_names, "max30102_red", "max30102_ir"]

        with destination.open("w", newline="", encoding="utf-8") as csv_file:
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()
            for sample in samples:
                row = {
                    "timestamp": sample.timestamp,
                    "patient_name": patient_name,
                    "max30102_red": sample.max_red,
                    "max30102_ir": sample.max_ir,
                }
                row.update(sample.as7341_channels)
                writer.writerow(row)

        return destination


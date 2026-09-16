from __future__ import annotations

import csv
from pathlib import Path

from hardware.sensor_manager import UnifiedSample
from utils.helpers import ensure_directory


class CSVStorage:
    def write_session(
        self,
        patient_name: str,
        destination: Path,
        samples: list[UnifiedSample],
        session_id: str | None = None,
    ) -> Path:
        ensure_directory(destination.parent)

        channel_names = list(samples[0].as7341_channels.keys()) if samples else []
        fieldnames = [
            "session_id",
            "patient_name",
            "sample_index",
            "timestamp",
            *channel_names,
            "max30102_red",
            "max30102_ir",
            "finger_detected",
        ]

        sid = session_id or destination.stem

        with destination.open("w", newline="", encoding="utf-8") as csv_file:
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()
            for idx, sample in enumerate(samples, start=1):
                row = {
                    "session_id": sid,
                    "patient_name": patient_name,
                    "sample_index": idx,
                    "timestamp": sample.timestamp,
                    "max30102_red": sample.max_red,
                    "max30102_ir": sample.max_ir,
                    "finger_detected": sample.finger_detected,
                }
                row.update(sample.as7341_channels)
                writer.writerow(row)

        return destination



from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from validation.as7341.config import SPECTRAL_CHANNELS

# Standard Raw CSV Header
RAW_CSV_COLUMNS = [
    "timestamp",
    "sample_index",
    "condition",
    "415nm",
    "445nm",
    "480nm",
    "515nm",
    "555nm",
    "590nm",
    "630nm",
    "680nm",
    "acquisition_duration_ms",
    "valid",
    "sensor_status",
    "integration_time",
    "gain",
]

@dataclass(frozen=True)
class ValidationSample:
    timestamp: str
    sample_index: int
    condition: str
    channels: dict[str, int]
    acquisition_duration_ms: float
    valid: bool
    sensor_status: str
    integration_time: float
    gain: int

    def to_csv_row(self) -> list[Any]:
        return [
            self.timestamp,
            self.sample_index,
            self.condition,
            self.channels.get("415", 0),
            self.channels.get("445", 0),
            self.channels.get("480", 0),
            self.channels.get("515", 0),
            self.channels.get("555", 0),
            self.channels.get("590", 0),
            self.channels.get("630", 0),
            self.channels.get("680", 0),
            f"{self.acquisition_duration_ms:.2f}",
            str(self.valid).lower(),
            self.sensor_status,
            f"{self.integration_time:.1f}",
            self.gain,
        ]

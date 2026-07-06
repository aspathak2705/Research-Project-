from __future__ import annotations

import logging
import time
from dataclasses import dataclass

from hardware.as7341 import AS7341Sensor
from hardware.max30102 import MAX30102Sensor

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class UnifiedSample:
    timestamp: float
    patient: str
    AS7341_415nm: int
    AS7341_445nm: int
    AS7341_480nm: int
    AS7341_515nm: int
    AS7341_555nm: int
    AS7341_590nm: int
    AS7341_630nm: int
    AS7341_680nm: int
    MAX30102_RED: int
    MAX30102_IR: int
    finger_detected: bool
    as7341_saturated: bool

    @property
    def max_red(self) -> int:
        return self.MAX30102_RED

    @property
    def max_ir(self) -> int:
        return self.MAX30102_IR

    @property
    def as7341_channels(self) -> dict[str, int]:
        return {
            "AS7341_415nm": self.AS7341_415nm,
            "AS7341_445nm": self.AS7341_445nm,
            "AS7341_480nm": self.AS7341_480nm,
            "AS7341_515nm": self.AS7341_515nm,
            "AS7341_555nm": self.AS7341_555nm,
            "AS7341_590nm": self.AS7341_590nm,
            "AS7341_630nm": self.AS7341_630nm,
            "AS7341_680nm": self.AS7341_680nm,
        }


class SensorManager:
    def __init__(self, max30102: MAX30102Sensor, as7341: AS7341Sensor) -> None:
        self.max30102 = max30102
        self.as7341 = as7341

    def self_test(self) -> bool:
        self.max30102.initialize()
        self.as7341.initialize()
        return True

    def wait_for_finger(self, retries: int = 5, delay_seconds: float = 0.25) -> bool:
        for _ in range(retries):
            if self.max30102.finger_detected():
                return True
            time.sleep(delay_seconds)
        return False

    def collect(self, patient: str) -> UnifiedSample:
        max_sample = self.max30102.read_sample()
        as_sample = self.as7341.read_sample()
        channels = as_sample.channels
        return UnifiedSample(
            timestamp=time.time(),
            patient=patient,
            AS7341_415nm=channels["415"],
            AS7341_445nm=channels["445"],
            AS7341_480nm=channels["480"],
            AS7341_515nm=channels["515"],
            AS7341_555nm=channels["555"],
            AS7341_590nm=channels["590"],
            AS7341_630nm=channels["630"],
            AS7341_680nm=channels["680"],
            MAX30102_RED=max_sample["red"],
            MAX30102_IR=max_sample["ir"],
            finger_detected=self.max30102.finger_detected(),
            as7341_saturated=as_sample.saturated,
        )

    def close(self) -> None:
        self.max30102.close()
        self.as7341.close()

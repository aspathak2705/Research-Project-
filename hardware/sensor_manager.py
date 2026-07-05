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
    max_red: int
    max_ir: int
    finger_detected: bool
    as7341_channels: dict[str, int]
    as7341_saturated: bool


class SensorManager:
    def __init__(self, max30102: MAX30102Sensor, as7341: AS7341Sensor) -> None:
        self.max30102 = max30102
        self.as7341 = as7341

    def self_test(self) -> bool:
        self.max30102.configure()
        self.as7341.configure()
        return True

    def wait_for_finger(self, retries: int = 5, delay_seconds: float = 0.25) -> bool:
        for _ in range(retries):
            if self.max30102.finger_detected():
                return True
            time.sleep(delay_seconds)
        return False

    def acquire_samples(self, sample_count: int, interval_seconds: float = 0.05) -> list[UnifiedSample]:
        samples: list[UnifiedSample] = []
        for _ in range(sample_count):
            max_sample = self.max30102.read_sample()
            as_sample = self.as7341.read_sample()
            samples.append(
                UnifiedSample(
                    timestamp=time.time(),
                    max_red=max_sample.red,
                    max_ir=max_sample.ir,
                    finger_detected=max_sample.finger_detected,
                    as7341_channels=as_sample.channels,
                    as7341_saturated=as_sample.saturated,
                )
            )
            time.sleep(interval_seconds)

        LOGGER.info("Collected %s synchronized samples.", len(samples))
        return samples


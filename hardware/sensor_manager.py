from __future__ import annotations

import logging
import time
from dataclasses import dataclass

from hardware.as7341 import AS7341Sensor
from hardware.max30102 import MAX30102Sensor

LOGGER = logging.getLogger(__name__)


from enum import Enum


class SelfTestStatus(Enum):
    SENSOR_READY = "SENSOR_READY"
    DEVICE_NOT_FOUND = "DEVICE_NOT_FOUND"
    INITIALIZATION_FAILED = "INITIALIZATION_FAILED"
    MEASUREMENT_FAILED = "MEASUREMENT_FAILED"
    INVALID_MEASUREMENT = "INVALID_MEASUREMENT"


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

    def self_test(self) -> tuple[SelfTestStatus, str]:
        try:
            self.max30102.initialize()
        except Exception as exc:
            LOGGER.error("MAX30102 initialization failed: %s", exc)
            return SelfTestStatus.INITIALIZATION_FAILED, f"MAX30102 init failed: {exc}"

        try:
            self.as7341.initialize()
        except Exception as exc:
            LOGGER.error("AS7341 initialization failed: %s", exc)
            return SelfTestStatus.INITIALIZATION_FAILED, f"AS7341 init failed: {exc}"

        try:
            test_max = self.max30102.read_sample()
            test_as = self.as7341.read_sample()
            if test_max.get("red") is None or test_max.get("ir") is None:
                return SelfTestStatus.INVALID_MEASUREMENT, "MAX30102 sample returned None"
            if len(test_as.channels) != 8:
                return SelfTestStatus.INVALID_MEASUREMENT, "AS7341 channel count incomplete"
        except Exception as exc:
            LOGGER.error("Sensor self-test measurement read failed: %s", exc)
            return SelfTestStatus.MEASUREMENT_FAILED, f"Measurement test read failed: {exc}"

        return SelfTestStatus.SENSOR_READY, "All physical sensors operational"

    def wait_for_finger(self, retries: int = 5, delay_seconds: float = 0.25) -> bool:
        for _ in range(retries):
            try:
                if self.max30102.finger_detected():
                    return True
            except Exception as exc:
                LOGGER.warning("Error checking finger status: %s", exc)
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


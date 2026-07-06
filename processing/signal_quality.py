from __future__ import annotations

from dataclasses import dataclass

from config.constants import (
    AS7341_SATURATION_LIMIT,
    MAX30102_AC_MIN,
    MAX30102_DC_MIN,
    MAX30102_MOTION_LIMIT,
    MINIMUM_SAMPLE_COUNT,
)
from hardware.sensor_manager import UnifiedSample



@dataclass(frozen=True)
class QualityResult:
    passed: bool
    reasons: list[str]


class SignalQualityChecker:
    def validate(self, samples: list[UnifiedSample]) -> QualityResult:
        reasons: list[str] = []

        if len(samples) < MINIMUM_SAMPLE_COUNT:
            reasons.append("minimum required samples not met")

        if not all(sample.finger_detected for sample in samples):
            reasons.append("finger not consistently detected")

        ir_values = [sample.max_ir for sample in samples]
        red_values = [sample.max_red for sample in samples]

        if not ir_values or min(ir_values) < MAX30102_DC_MIN:
            reasons.append("unstable or weak DC signal")

        if (max(ir_values) - min(ir_values)) < MAX30102_AC_MIN:
            reasons.append("insufficient AC amplitude")

        if any(sample.as7341_saturated for sample in samples):
            reasons.append("AS7341 reported saturation")

        if any(
            max(channel_value for channel_value in sample.as7341_channels.values()) >= AS7341_SATURATION_LIMIT
            for sample in samples
        ):
            reasons.append("AS7341 channel saturation threshold exceeded")

        # -------------------------------
        # Motion detection disabled
        # Milestone 0: Data acquisition
        # -------------------------------

        # if self._motion_score(red_values, ir_values) > MAX30102_MOTION_LIMIT:
        #     reasons.append("excessive motion detected")

        print(f"Quality check received {len(samples)} samples")
        print(reasons)
        return QualityResult(passed=not reasons, reasons=reasons)

    @staticmethod
    def _motion_score(red_values: list[int], ir_values: list[int]) -> int:
        if len(red_values) < 2 or len(ir_values) < 2:
            return 0

        red_delta = sum(abs(curr - prev) for prev, curr in zip(red_values, red_values[1:]))
        ir_delta = sum(abs(curr - prev) for prev, curr in zip(ir_values, ir_values[1:]))
        return (red_delta + ir_delta) // max(len(red_values) - 1, 1)

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any

from config.constants import (
    MAX30102_ADC_MAX,
    MAX30102_DC_MIN,
    REASON_MAX30102_INVALID_VALUE,
    REASON_MAX30102_LOW_SIGNAL,
    REASON_MAX30102_NO_FINGER,
    REASON_MAX30102_OUT_OF_RANGE,
    REASON_MAX30102_STALE_DATA,
    REASON_MAX30102_ZERO_SIGNAL,
)


@dataclass(frozen=True)
class MAX30102ValidationResult:
    valid: bool
    finger_detected: bool
    reasons: list[str]
    warnings: list[str]
    red_valid: bool
    ir_valid: bool


class MAX30102Validator:
    def __init__(
        self,
        adc_max: int = MAX30102_ADC_MAX,
        dc_min: int = MAX30102_DC_MIN,
    ) -> None:
        self.adc_max = adc_max
        self.dc_min = dc_min

    def validate_sample(
        self,
        red: Any,
        ir: Any,
        finger_detected: bool,
        previous_red: Any = None,
        previous_ir: Any = None,
    ) -> MAX30102ValidationResult:
        reasons: list[str] = []
        warnings: list[str] = []
        red_valid = True
        ir_valid = True

        # Check 1 & 2: Non-numeric, None, NaN, Inf
        if red is None or isinstance(red, bool) or not isinstance(red, (int, float)):
            reasons.append(REASON_MAX30102_INVALID_VALUE)
            red_valid = False
        elif math.isnan(red) or math.isinf(red):
            reasons.append(REASON_MAX30102_INVALID_VALUE)
            red_valid = False

        if ir is None or isinstance(ir, bool) or not isinstance(ir, (int, float)):
            if REASON_MAX30102_INVALID_VALUE not in reasons:
                reasons.append(REASON_MAX30102_INVALID_VALUE)
            ir_valid = False
        elif math.isnan(ir) or math.isinf(ir):
            if REASON_MAX30102_INVALID_VALUE not in reasons:
                reasons.append(REASON_MAX30102_INVALID_VALUE)
            ir_valid = False

        if not red_valid or not ir_valid:
            return MAX30102ValidationResult(
                valid=False,
                finger_detected=finger_detected,
                reasons=reasons,
                warnings=warnings,
                red_valid=red_valid,
                ir_valid=ir_valid,
            )

        red_val = int(red)
        ir_val = int(ir)

        # Check 3: ADC range check (18-bit 0..262143)
        if red_val < 0 or red_val > self.adc_max or ir_val < 0 or ir_val > self.adc_max:
            reasons.append(REASON_MAX30102_OUT_OF_RANGE)

        # Check 4: Finger detection vs sample validity
        if not finger_detected:
            reasons.append(REASON_MAX30102_NO_FINGER)

        # Check 5: Zero signal
        if red_val == 0 and ir_val == 0:
            reasons.append(REASON_MAX30102_ZERO_SIGNAL)
        elif ir_val < self.dc_min and finger_detected:
            reasons.append(REASON_MAX30102_LOW_SIGNAL)

        # Check 6: Stale data check
        if previous_red is not None and previous_ir is not None:
            if int(previous_red) == red_val and int(previous_ir) == ir_val and (red_val > 0 or ir_val > 0):
                warnings.append(REASON_MAX30102_STALE_DATA)

        unique_reasons = list(dict.fromkeys(reasons))
        overall_valid = len(unique_reasons) == 0

        return MAX30102ValidationResult(
            valid=overall_valid,
            finger_detected=finger_detected,
            reasons=unique_reasons,
            warnings=warnings,
            red_valid=True,
            ir_valid=True,
        )

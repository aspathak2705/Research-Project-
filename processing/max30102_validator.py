from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any, Sequence

from config.constants import (
    MAX30102_ADC_MAX,
    MAX30102_ADC_MIN,
    MAX30102_ADC_OUT_OF_RANGE,
    MAX30102_DC_MIN,
    MAX30102_FIFO_OVERFLOW,
    MAX30102_INVALID_NUMERIC_VALUE,
    MAX30102_LOW_SIGNAL,
    MAX30102_NO_FINGER,
    MAX30102_STALE_DATA,
    MAX30102_ZERO_SIGNAL,
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
        adc_min: int = MAX30102_ADC_MIN,
        adc_max: int = MAX30102_ADC_MAX,
        dc_min: int = MAX30102_DC_MIN,
        stale_limit: int = 5,
    ) -> None:
        self.adc_min = adc_min
        self.adc_max = adc_max
        self.dc_min = dc_min
        self.stale_limit = stale_limit

    def validate_sample(
        self,
        red: Any,
        ir: Any,
        finger_detected: bool,
        overflow_counter: int = 0,
        history: Sequence[tuple[Any, Any]] | None = None,
    ) -> MAX30102ValidationResult:
        reasons: list[str] = []
        warnings: list[str] = []
        red_valid = True
        ir_valid = True

        # Check 7: FIFO Overflow
        if overflow_counter > 0:
            reasons.append(MAX30102_FIFO_OVERFLOW)

        # Check 1: Non-numeric, None, NaN, Inf, negative
        if red is None or isinstance(red, bool) or not isinstance(red, (int, float)):
            reasons.append(MAX30102_INVALID_NUMERIC_VALUE)
            red_valid = False
        elif math.isnan(red) or math.isinf(red):
            reasons.append(MAX30102_INVALID_NUMERIC_VALUE)
            red_valid = False

        if ir is None or isinstance(ir, bool) or not isinstance(ir, (int, float)):
            if MAX30102_INVALID_NUMERIC_VALUE not in reasons:
                reasons.append(MAX30102_INVALID_NUMERIC_VALUE)
            ir_valid = False
        elif math.isnan(ir) or math.isinf(ir):
            if MAX30102_INVALID_NUMERIC_VALUE not in reasons:
                reasons.append(MAX30102_INVALID_NUMERIC_VALUE)
            ir_valid = False

        if not red_valid or not ir_valid:
            unique_reasons = list(dict.fromkeys(reasons))
            return MAX30102ValidationResult(
                valid=False,
                finger_detected=finger_detected,
                reasons=unique_reasons,
                warnings=warnings,
                red_valid=red_valid,
                ir_valid=ir_valid,
            )

        red_val = int(red)
        ir_val = int(ir)

        # Check 2: ADC range check (18-bit 0..262143)
        if red_val < self.adc_min or red_val > self.adc_max or ir_val < self.adc_min or ir_val > self.adc_max:
            reasons.append(MAX30102_ADC_OUT_OF_RANGE)

        # Check 5: Finger detection state
        if not finger_detected:
            reasons.append(MAX30102_NO_FINGER)

        # Check 3: Zero signal
        if red_val == 0 and ir_val == 0:
            reasons.append(MAX30102_ZERO_SIGNAL)
        # Check 4: Low signal
        elif ir_val < self.dc_min and finger_detected:
            reasons.append(MAX30102_LOW_SIGNAL)

        # Check 6: Stale frame check over consecutive history
        if history and len(history) >= self.stale_limit:
            last_n = list(history)[-self.stale_limit:]
            if all(item == (red_val, ir_val) for item in last_n) and (red_val > 0 or ir_val > 0):
                warnings.append(MAX30102_STALE_DATA)

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


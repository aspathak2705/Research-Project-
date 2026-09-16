from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any

from config.constants import (
    AS7341_ADC_MAX,
    AS7341_NEAR_ZERO_THRESHOLD,
    AS7341_SATURATION_LIMIT,
    REASON_AS7341_CONSTANT_SPECTRUM,
    REASON_AS7341_INVALID_RANGE,
    REASON_AS7341_MISSING_CHANNEL,
    REASON_AS7341_NEAR_ZERO,
    REASON_AS7341_NON_NUMERIC,
    REASON_AS7341_SATURATION,
    REASON_AS7341_STALE_DATA,
    REASON_AS7341_ZERO_SIGNAL,
)

EXPECTED_CHANNELS = ("415", "445", "480", "515", "555", "590", "630", "680")


@dataclass(frozen=True)
class ChannelValidationResult:
    channel: str
    value: Any
    valid: bool
    reasons: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class AS7341ValidationResult:
    valid: bool
    reasons: list[str]
    warnings: list[str]
    channel_results: dict[str, ChannelValidationResult]
    saturated_channels: list[str]


class AS7341Validator:
    def __init__(
        self,
        near_zero_threshold: int = AS7341_NEAR_ZERO_THRESHOLD,
        saturation_threshold: int = AS7341_SATURATION_LIMIT,
        adc_max: int = AS7341_ADC_MAX,
    ) -> None:
        self.near_zero_threshold = near_zero_threshold
        self.saturation_threshold = saturation_threshold
        self.adc_max = adc_max

    def validate_sample(
        self,
        channels: dict[str, Any] | None,
        previous_sample_channels: dict[str, Any] | None = None,
    ) -> AS7341ValidationResult:
        reasons: list[str] = []
        warnings: list[str] = []
        channel_results: dict[str, ChannelValidationResult] = {}
        saturated_channels: list[str] = []

        if channels is None or not isinstance(channels, dict):
            return AS7341ValidationResult(
                valid=False,
                reasons=[REASON_AS7341_MISSING_CHANNEL],
                warnings=[],
                channel_results={},
                saturated_channels=[],
            )

        # Check 1: Missing channels
        for ch in EXPECTED_CHANNELS:
            if ch not in channels:
                reasons.append(REASON_AS7341_MISSING_CHANNEL)
                channel_results[ch] = ChannelValidationResult(
                    channel=ch, value=None, valid=False, reasons=[REASON_AS7341_MISSING_CHANNEL]
                )

        if len(channels) != len(EXPECTED_CHANNELS):
            if REASON_AS7341_MISSING_CHANNEL not in reasons:
                reasons.append(REASON_AS7341_MISSING_CHANNEL)

        # Check 2: Non-numeric, NaN, Inf, and range checks per channel
        valid_numeric_values: list[int] = []

        for ch in EXPECTED_CHANNELS:
            if ch in channel_results and not channel_results[ch].valid:
                continue

            val = channels[ch]
            ch_reasons: list[str] = []

            if val is None or isinstance(val, bool) or not isinstance(val, (int, float)):
                ch_reasons.append(REASON_AS7341_NON_NUMERIC)
            elif math.isnan(val) or math.isinf(val):
                ch_reasons.append(REASON_AS7341_NON_NUMERIC)
            else:
                numeric_val = int(val)
                if numeric_val < 0 or numeric_val > self.adc_max:
                    ch_reasons.append(REASON_AS7341_INVALID_RANGE)
                else:
                    valid_numeric_values.append(numeric_val)

                if numeric_val >= self.saturation_threshold:
                    ch_reasons.append(REASON_AS7341_SATURATION)
                    saturated_channels.append(ch)

            is_valid = len(ch_reasons) == 0
            channel_results[ch] = ChannelValidationResult(
                channel=ch, value=val, valid=is_valid, reasons=ch_reasons
            )

        if any(r == REASON_AS7341_NON_NUMERIC for cr in channel_results.values() for r in cr.reasons):
            reasons.append(REASON_AS7341_NON_NUMERIC)
        if any(r == REASON_AS7341_INVALID_RANGE for cr in channel_results.values() for r in cr.reasons):
            reasons.append(REASON_AS7341_INVALID_RANGE)

        if saturated_channels:
            reasons.append(REASON_AS7341_SATURATION)

        # Numerical checks across spectrum if all numeric values available
        if len(valid_numeric_values) == len(EXPECTED_CHANNELS):
            # Check 3: All-zero
            if all(v == 0 for v in valid_numeric_values):
                reasons.append(REASON_AS7341_ZERO_SIGNAL)

            # Check 4: Near-zero
            elif all(v <= self.near_zero_threshold for v in valid_numeric_values):
                reasons.append(REASON_AS7341_NEAR_ZERO)

            # Check 5: Constant spectrum across channels
            if len(set(valid_numeric_values)) == 1:
                reasons.append(REASON_AS7341_CONSTANT_SPECTRUM)

            # Check 10: Temporal consistency (stale duplicate frames)
            if previous_sample_channels and isinstance(previous_sample_channels, dict):
                prev_vals = [previous_sample_channels.get(ch) for ch in EXPECTED_CHANNELS]
                if prev_vals == valid_numeric_values:
                    warnings.append(REASON_AS7341_STALE_DATA)

        # Deduplicate reasons while preserving order
        unique_reasons = list(dict.fromkeys(reasons))
        overall_valid = len(unique_reasons) == 0

        return AS7341ValidationResult(
            valid=overall_valid,
            reasons=unique_reasons,
            warnings=warnings,
            channel_results=channel_results,
            saturated_channels=saturated_channels,
        )

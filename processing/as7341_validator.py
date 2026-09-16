from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any, Sequence

from config.constants import (
    AS7341_ADC_MAX,
    AS7341_ADC_MIN,
    AS7341_ADC_OUT_OF_RANGE,
    AS7341_ALL_ZERO,
    AS7341_CONSTANT_SPECTRUM,
    AS7341_INVALID_CHANNEL_SET,
    AS7341_INVALID_NUMERIC_VALUE,
    AS7341_MEASUREMENT_INCOMPLETE,
    AS7341_MISSING_CHANNEL,
    AS7341_NEAR_ZERO,
    AS7341_NEAR_ZERO_THRESHOLD,
    AS7341_SATURATION,
    AS7341_SATURATION_LIMIT,
    AS7341_SMUX_INCOMPLETE,
    AS7341_STALE_DATA,
    AS7341_TEMPORAL_SATURATION_ANOMALY,
    AS7341_TEMPORAL_ZERO_COLLAPSE,
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
        adc_min: int = AS7341_ADC_MIN,
        adc_max: int = AS7341_ADC_MAX,
        near_zero_threshold: int = AS7341_NEAR_ZERO_THRESHOLD,
        saturation_threshold: int = AS7341_SATURATION_LIMIT,
        stale_limit: int = 3,
    ) -> None:
        self.adc_min = adc_min
        self.adc_max = adc_max
        self.near_zero_threshold = near_zero_threshold
        self.saturation_threshold = saturation_threshold
        self.stale_limit = stale_limit

    def validate_sample(
        self,
        channels: dict[str, Any] | None,
        measurement_complete: bool = True,
        smux_complete: bool = True,
        history: Sequence[dict[str, Any]] | None = None,
    ) -> AS7341ValidationResult:
        reasons: list[str] = []
        warnings: list[str] = []
        channel_results: dict[str, ChannelValidationResult] = {}
        saturated_channels: list[str] = []

        # Check 8: Measurement completion
        if not measurement_complete:
            reasons.append(AS7341_MEASUREMENT_INCOMPLETE)

        # Check 9: SMUX completion
        if not smux_complete:
            reasons.append(AS7341_SMUX_INCOMPLETE)

        if channels is None or not isinstance(channels, dict):
            reasons.append(AS7341_MISSING_CHANNEL)
            unique_reasons = list(dict.fromkeys(reasons))
            return AS7341ValidationResult(
                valid=False,
                reasons=unique_reasons,
                warnings=[],
                channel_results={},
                saturated_channels=[],
            )

        # Check 1: Channel set completeness and validity
        for ch in EXPECTED_CHANNELS:
            if ch not in channels:
                reasons.append(AS7341_MISSING_CHANNEL)
                channel_results[ch] = ChannelValidationResult(
                    channel=ch, value=None, valid=False, reasons=[AS7341_MISSING_CHANNEL]
                )

        extra_keys = [k for k in channels if k not in EXPECTED_CHANNELS]
        if extra_keys or len(channels) != len(EXPECTED_CHANNELS):
            reasons.append(AS7341_INVALID_CHANNEL_SET)

        # Check 2 & 3 & 7: Numeric validity, ADC range, and Saturation per channel
        valid_numeric_values: list[int] = []

        for ch in EXPECTED_CHANNELS:
            if ch in channel_results and not channel_results[ch].valid:
                continue

            val = channels[ch]
            ch_reasons: list[str] = []

            if val is None or isinstance(val, bool) or not isinstance(val, (int, float)):
                ch_reasons.append(AS7341_INVALID_NUMERIC_VALUE)
            elif math.isnan(val) or math.isinf(val):
                ch_reasons.append(AS7341_INVALID_NUMERIC_VALUE)
            else:
                numeric_val = int(val)
                if numeric_val < self.adc_min or numeric_val > self.adc_max:
                    ch_reasons.append(AS7341_ADC_OUT_OF_RANGE)
                else:
                    valid_numeric_values.append(numeric_val)

                if numeric_val >= self.saturation_threshold:
                    ch_reasons.append(AS7341_SATURATION)
                    saturated_channels.append(ch)

            is_valid = len(ch_reasons) == 0
            channel_results[ch] = ChannelValidationResult(
                channel=ch, value=val, valid=is_valid, reasons=ch_reasons
            )

        if any(r == AS7341_INVALID_NUMERIC_VALUE for cr in channel_results.values() for r in cr.reasons):
            reasons.append(AS7341_INVALID_NUMERIC_VALUE)
        if any(r == AS7341_ADC_OUT_OF_RANGE for cr in channel_results.values() for r in cr.reasons):
            reasons.append(AS7341_ADC_OUT_OF_RANGE)

        if saturated_channels:
            reasons.append(AS7341_SATURATION)

        # Numerical checks across spectrum
        if len(valid_numeric_values) == len(EXPECTED_CHANNELS):
            # Check 4: All-zero
            if all(v == 0 for v in valid_numeric_values):
                reasons.append(AS7341_ALL_ZERO)

            # Check 5: Near-zero
            elif all(v <= self.near_zero_threshold for v in valid_numeric_values):
                reasons.append(AS7341_NEAR_ZERO)

            # Check 6: Constant spectrum
            if len(set(valid_numeric_values)) == 1:
                reasons.append(AS7341_CONSTANT_SPECTRUM)

        # Phase 2B Temporal Checks using history
        if history and len(history) >= 1:
            recent = list(history)

            # Temporal Check 4: Stale frames
            if len(recent) >= self.stale_limit:
                last_n = recent[-self.stale_limit:]
                if all(h == channels for h in last_n):
                    warnings.append(AS7341_STALE_DATA)

            # Temporal Check 2: Zero collapse
            if all(v == 0 for v in valid_numeric_values):
                prev_sample = recent[-1]
                if isinstance(prev_sample, dict) and any(prev_sample.get(ch, 0) > self.near_zero_threshold for ch in EXPECTED_CHANNELS):
                    reasons.append(AS7341_TEMPORAL_ZERO_COLLAPSE)

            # Temporal Check 3: Saturation collapse
            if len(saturated_channels) == len(EXPECTED_CHANNELS):
                prev_sample = recent[-1]
                if isinstance(prev_sample, dict) and any(prev_sample.get(ch, 0) < self.saturation_threshold for ch in EXPECTED_CHANNELS):
                    reasons.append(AS7341_TEMPORAL_SATURATION_ANOMALY)

        unique_reasons = list(dict.fromkeys(reasons))
        overall_valid = len(unique_reasons) == 0

        return AS7341ValidationResult(
            valid=overall_valid,
            reasons=unique_reasons,
            warnings=warnings,
            channel_results=channel_results,
            saturated_channels=saturated_channels,
        )


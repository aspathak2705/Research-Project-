from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence

from config.constants import (
    MAX30102_AC_MIN,
    MAX30102_DC_MIN,
    MINIMUM_SAMPLE_COUNT,
    REASON_SESSION_EXCESSIVE_REJECTIONS,
    REASON_SESSION_POOR_SIGNAL_QUALITY,
    REASON_SESSION_TOO_FEW_VALID_SAMPLES,
)
from hardware.sensor_manager import UnifiedSample


from enum import Enum


class SessionStatus(Enum):
    SESSION_ACCEPTED = "SESSION_ACCEPTED"
    SESSION_REJECTED = "SESSION_REJECTED"
    SESSION_ABORTED = "SESSION_ABORTED"
    SESSION_INCOMPLETE = "SESSION_INCOMPLETE"


@dataclass(frozen=True)
class EvaluatedSample:
    sample: UnifiedSample
    valid: bool
    reasons: list[str]
    warnings: list[str]


@dataclass(frozen=True)
class SessionValidationResult:
    status: SessionStatus
    passed: bool
    attempted_samples: int
    valid_samples: int
    rejected_samples: int
    rejection_ratio: float
    as7341_valid_samples: int
    as7341_rejected_samples: int
    max30102_valid_samples: int
    max30102_rejected_samples: int
    reasons: list[str]
    rejection_histogram: dict[str, int]
    evaluated_samples: list[EvaluatedSample]


class SessionValidator:
    def __init__(
        self,
        min_valid_samples: int = MINIMUM_SAMPLE_COUNT,
        max_rejection_ratio: float = 0.35,
    ) -> None:
        self.min_valid_samples = min_valid_samples
        self.max_rejection_ratio = max_rejection_ratio

    def validate_session(
        self,
        evaluated_samples: Sequence[EvaluatedSample],
        is_aborted: bool = False,
        is_incomplete: bool = False,
    ) -> SessionValidationResult:
        attempted = len(evaluated_samples)
        valid_items = [item for item in evaluated_samples if item.valid]
        valid_count = len(valid_items)
        rejected_count = attempted - valid_count
        rejection_ratio = (rejected_count / attempted) if attempted > 0 else (0.0 if attempted == 0 else 1.0)

        as7341_rejected = sum(1 for item in evaluated_samples if any("AS7341" in r for r in item.reasons))
        as7341_valid = attempted - as7341_rejected

        max30102_rejected = sum(1 for item in evaluated_samples if any("MAX30102" in r for r in item.reasons))
        max30102_valid = attempted - max30102_rejected

        histogram: dict[str, int] = {}
        for item in evaluated_samples:
            for r in item.reasons:
                histogram[r] = histogram.get(r, 0) + 1

        reasons: list[str] = []

        if valid_count < self.min_valid_samples:
            reasons.append(REASON_SESSION_TOO_FEW_VALID_SAMPLES)

        if rejection_ratio > self.max_rejection_ratio:
            reasons.append(REASON_SESSION_EXCESSIVE_REJECTIONS)

        if valid_items:
            ir_values = [item.sample.max_ir for item in valid_items]
            ac_amplitude = max(ir_values) - min(ir_values)
            if ac_amplitude < MAX30102_AC_MIN:
                reasons.append(REASON_SESSION_POOR_SIGNAL_QUALITY)

        unique_reasons = list(dict.fromkeys(reasons))
        passed = len(unique_reasons) == 0 and not is_aborted and not is_incomplete

        if is_aborted:
            status = SessionStatus.SESSION_ABORTED
        elif is_incomplete:
            status = SessionStatus.SESSION_INCOMPLETE
        elif passed:
            status = SessionStatus.SESSION_ACCEPTED
        else:
            status = SessionStatus.SESSION_REJECTED

        return SessionValidationResult(
            status=status,
            passed=passed,
            attempted_samples=attempted,
            valid_samples=valid_count,
            rejected_samples=rejected_count,
            rejection_ratio=rejection_ratio,
            as7341_valid_samples=as7341_valid,
            as7341_rejected_samples=as7341_rejected,
            max30102_valid_samples=max30102_valid,
            max30102_rejected_samples=max30102_rejected,
            reasons=unique_reasons,
            rejection_histogram=histogram,
            evaluated_samples=list(evaluated_samples),
        )


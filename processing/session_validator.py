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


@dataclass(frozen=True)
class EvaluatedSample:
    sample: UnifiedSample
    valid: bool
    reasons: list[str]
    warnings: list[str]


@dataclass(frozen=True)
class SessionValidationResult:
    passed: bool
    attempted_samples: int
    valid_samples: int
    rejected_samples: int
    rejection_ratio: float
    reasons: list[str]
    evaluated_samples: list[EvaluatedSample]


class SessionValidator:
    def __init__(
        self,
        min_valid_samples: int = MINIMUM_SAMPLE_COUNT,
        max_rejection_ratio: float = 0.35,
    ) -> None:
        self.min_valid_samples = min_valid_samples
        self.max_rejection_ratio = max_rejection_ratio

    def validate_session(self, evaluated_samples: Sequence[EvaluatedSample]) -> SessionValidationResult:
        attempted = len(evaluated_samples)
        valid_items = [item for item in evaluated_samples if item.valid]
        valid_count = len(valid_items)
        rejected_count = attempted - valid_count
        rejection_ratio = (rejected_count / attempted) if attempted > 0 else 1.0

        reasons: list[str] = []

        if valid_count < self.min_valid_samples:
            reasons.append(REASON_SESSION_TOO_FEW_VALID_SAMPLES)

        if rejection_ratio > self.max_rejection_ratio:
            reasons.append(REASON_SESSION_EXCESSIVE_REJECTIONS)

        # Evaluate signal AC amplitude across valid samples if enough samples exist
        if valid_items:
            ir_values = [item.sample.max_ir for item in valid_items]
            ac_amplitude = max(ir_values) - min(ir_values)
            if ac_amplitude < MAX30102_AC_MIN:
                reasons.append(REASON_SESSION_POOR_SIGNAL_QUALITY)

        unique_reasons = list(dict.fromkeys(reasons))
        passed = len(unique_reasons) == 0

        return SessionValidationResult(
            passed=passed,
            attempted_samples=attempted,
            valid_samples=valid_count,
            rejected_samples=rejected_count,
            rejection_ratio=rejection_ratio,
            reasons=unique_reasons,
            evaluated_samples=list(evaluated_samples),
        )

from __future__ import annotations

import math
from typing import Sequence
from validation.as7341.config import SPECTRAL_CHANNELS

def calculate_channel_statistics(
    values: Sequence[int],
    *,
    condition: str | None = None,
) -> dict[str, float | int | str | bool | None]:
    if not values:
        return {
            "n": 0,
            "mean": None,
            "std_dev": None,
            "min": None,
            "max": None,
            "range": None,
            "cv_percent": None,
            "potentially_stuck": False,
            "diagnostic_flag": "NO_DATA",
        }

    n = len(values)
    mean = sum(values) / n
    variance = sum((x - mean) ** 2 for x in values) / (n - 1) if n > 1 else 0.0
    std_dev = math.sqrt(variance)
    v_min = min(values)
    v_max = max(values)
    v_range = v_max - v_min

    # Calculate CV% only if mean is positive and significantly above 0
    if mean > 1.0:
        cv_percent = (std_dev / mean) * 100.0
    else:
        cv_percent = None

    cond_upper = condition.strip().upper() if condition else None
    is_constant = (n >= 10 and v_range == 0)

    # Condition-aware diagnostic evaluation
    if cond_upper == "DARK" and is_constant and v_max == 0:
        # Legitimate dark baseline when sensor is covered and returning zero counts
        potentially_stuck = False
        diagnostic_flag = "ZERO_BASELINE"
    elif is_constant:
        # Constant readings under reference light, non-zero dark, or other conditions
        potentially_stuck = True
        diagnostic_flag = "POTENTIALLY_STUCK"
    else:
        # Varying readings within normal dynamic range
        potentially_stuck = False
        diagnostic_flag = "NORMAL"

    return {
        "n": n,
        "mean": round(mean, 2),
        "std_dev": round(std_dev, 2),
        "min": v_min,
        "max": v_max,
        "range": v_range,
        "cv_percent": round(cv_percent, 2) if cv_percent is not None else None,
        "potentially_stuck": potentially_stuck,
        "diagnostic_flag": diagnostic_flag,
    }

def calculate_drift(values: Sequence[int], duration_seconds: float) -> dict[str, float | None]:
    if len(values) < 2 or duration_seconds <= 0:
        return {
            "drift_units_per_minute": None,
            "percent_drift_total": None,
        }

    half = len(values) // 2
    initial_mean = sum(values[:half]) / half
    final_mean = sum(values[half:]) / (len(values) - half)

    delta = final_mean - initial_mean
    duration_minutes = duration_seconds / 60.0
    drift_rate = delta / duration_minutes if duration_minutes > 0 else 0.0

    percent_drift = (delta / initial_mean * 100.0) if initial_mean > 0 else None

    return {
        "drift_units_per_minute": round(drift_rate, 2),
        "percent_drift_total": round(percent_drift, 2) if percent_drift is not None else None,
    }

def compare_conditions(
    baseline_stats: dict[str, dict[str, Any]],
    response_stats: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
    comparison: list[dict[str, Any]] = []

    for ch in SPECTRAL_CHANNELS:
        b_mean = baseline_stats.get(ch, {}).get("mean")
        r_mean = response_stats.get(ch, {}).get("mean")

        if b_mean is not None and r_mean is not None:
            abs_diff = round(r_mean - b_mean, 2)
            rel_diff = round((abs_diff / b_mean) * 100.0, 2) if b_mean > 0 else None
        else:
            abs_diff = None
            rel_diff = None

        comparison.append({
            "channel": f"{ch}nm",
            "baseline_mean": b_mean,
            "response_mean": r_mean,
            "absolute_diff": abs_diff,
            "relative_diff_percent": rel_diff,
        })

    return comparison

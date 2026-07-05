from hardware.sensor_manager import UnifiedSample
from processing.signal_quality import SignalQualityChecker


def _sample(timestamp: float, red: int, ir: int) -> UnifiedSample:
    return UnifiedSample(
        timestamp=timestamp,
        max_red=red,
        max_ir=ir,
        finger_detected=True,
        as7341_channels={"f1_415nm": 10000, "nir": 12000},
        as7341_saturated=False,
    )


def test_signal_quality_passes_for_stable_batch() -> None:
    checker = SignalQualityChecker()
    samples = [_sample(float(i), 45000 + (i % 3) * 80, 50000 + (i % 4) * 90) for i in range(24)]

    result = checker.validate(samples)

    assert result.passed is True
    assert result.reasons == []

from hardware.sensor_manager import UnifiedSample
from processing.signal_quality import SignalQualityChecker


def _sample(timestamp: float, red: int, ir: int) -> UnifiedSample:
    return UnifiedSample(
        timestamp=timestamp,
        patient="Test",
        AS7341_415nm=10000,
        AS7341_445nm=10100,
        AS7341_480nm=10200,
        AS7341_515nm=10300,
        AS7341_555nm=10400,
        AS7341_590nm=10500,
        AS7341_630nm=10600,
        AS7341_680nm=10700,
        MAX30102_RED=red,
        MAX30102_IR=ir,
        finger_detected=True,
        as7341_saturated=False,
    )


def test_signal_quality_passes_for_stable_batch() -> None:
    checker = SignalQualityChecker()
    samples = [_sample(float(i), 45000 + (i % 3) * 80, 50000 + (i % 4) * 90) for i in range(24)]

    result = checker.validate(samples)

    assert result.passed is True
    assert result.reasons == []

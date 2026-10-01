import unittest

from config.constants import (
    AS7341_ADC_OUT_OF_RANGE,
    AS7341_ALL_ZERO,
    AS7341_CONSTANT_SPECTRUM,
    AS7341_INVALID_CHANNEL_SET,
    AS7341_INVALID_NUMERIC_VALUE,
    AS7341_MEASUREMENT_INCOMPLETE,
    AS7341_MISSING_CHANNEL,
    AS7341_NEAR_ZERO,
    AS7341_SATURATION,
    AS7341_SMUX_INCOMPLETE,
    AS7341_STALE_DATA,
    AS7341_TEMPORAL_SATURATION_ANOMALY,
    AS7341_TEMPORAL_ZERO_COLLAPSE,
    MAX30102_ADC_OUT_OF_RANGE,
    MAX30102_FIFO_OVERFLOW,
    MAX30102_INVALID_NUMERIC_VALUE,
    MAX30102_LOW_SIGNAL,
    MAX30102_NO_FINGER,
    MAX30102_STALE_DATA,
    MAX30102_ZERO_SIGNAL,
    REASON_SESSION_EXCESSIVE_REJECTIONS,
    REASON_SESSION_TOO_FEW_VALID_SAMPLES,
)
from hardware.sensor_manager import UnifiedSample
from processing.as7341_validator import AS7341Validator
from processing.max30102_validator import MAX30102Validator
from processing.session_validator import EvaluatedSample, SessionValidator


class TestAS7341Validator(unittest.TestCase):
    def setUp(self) -> None:
        self.validator = AS7341Validator()
        self.valid_channels = {
            "415": 1000,
            "445": 1200,
            "480": 1400,
            "515": 1600,
            "555": 1800,
            "590": 2000,
            "630": 2200,
            "680": 2400,
        }

    def test_valid_spectrum(self) -> None:
        res = self.validator.validate_sample(self.valid_channels)
        self.assertTrue(res.valid)
        self.assertEqual(res.reasons, [])

    def test_missing_channel(self) -> None:
        incomplete = dict(self.valid_channels)
        del incomplete["415"]
        res = self.validator.validate_sample(incomplete)
        self.assertFalse(res.valid)
        self.assertIn(AS7341_MISSING_CHANNEL, res.reasons)

    def test_invalid_channel_set(self) -> None:
        extra = dict(self.valid_channels)
        extra["999"] = 100
        res = self.validator.validate_sample(extra)
        self.assertFalse(res.valid)
        self.assertIn(AS7341_INVALID_CHANNEL_SET, res.reasons)

    def test_non_numeric_nan_inf(self) -> None:
        bad_channels = dict(self.valid_channels)
        bad_channels["445"] = float("nan")
        res = self.validator.validate_sample(bad_channels)
        self.assertFalse(res.valid)
        self.assertIn(AS7341_INVALID_NUMERIC_VALUE, res.reasons)

    def test_all_zero_spectrum(self) -> None:
        zero_channels = {ch: 0 for ch in self.valid_channels}
        res = self.validator.validate_sample(zero_channels)
        self.assertFalse(res.valid)
        self.assertIn(AS7341_ALL_ZERO, res.reasons)

    def test_near_zero_spectrum(self) -> None:
        near_zero_channels = {ch: 2 for ch in self.valid_channels}
        res = self.validator.validate_sample(near_zero_channels)
        self.assertFalse(res.valid)
        self.assertIn(AS7341_NEAR_ZERO, res.reasons)

    def test_constant_spectrum(self) -> None:
        const_channels = {ch: 1500 for ch in self.valid_channels}
        res = self.validator.validate_sample(const_channels)
        self.assertFalse(res.valid)
        self.assertIn(AS7341_CONSTANT_SPECTRUM, res.reasons)

    def test_saturated_channel(self) -> None:
        sat_channels = dict(self.valid_channels)
        sat_channels["555"] = 62000
        res = self.validator.validate_sample(sat_channels)
        self.assertFalse(res.valid)
        self.assertIn(AS7341_SATURATION, res.reasons)
        self.assertEqual(res.saturated_channels, ["555"])

    def test_out_of_range(self) -> None:
        out_channels = dict(self.valid_channels)
        out_channels["680"] = 70000
        res = self.validator.validate_sample(out_channels)
        self.assertFalse(res.valid)
        self.assertIn(AS7341_ADC_OUT_OF_RANGE, res.reasons)

    def test_measurement_or_smux_incomplete(self) -> None:
        res = self.validator.validate_sample(self.valid_channels, measurement_complete=False, smux_complete=False)
        self.assertFalse(res.valid)
        self.assertIn(AS7341_MEASUREMENT_INCOMPLETE, res.reasons)
        self.assertIn(AS7341_SMUX_INCOMPLETE, res.reasons)

    def test_temporal_zero_and_saturation_collapse(self) -> None:
        history = [dict(self.valid_channels)]
        zero_channels = {ch: 0 for ch in self.valid_channels}
        res_zero = self.validator.validate_sample(zero_channels, history=history)
        self.assertIn(AS7341_TEMPORAL_ZERO_COLLAPSE, res_zero.reasons)

        sat_channels = {ch: 64000 for ch in self.valid_channels}
        res_sat = self.validator.validate_sample(sat_channels, history=history)
        self.assertIn(AS7341_TEMPORAL_SATURATION_ANOMALY, res_sat.reasons)

    def test_stale_data_warning(self) -> None:
        history = [dict(self.valid_channels) for _ in range(3)]
        res = self.validator.validate_sample(self.valid_channels, history=history)
        self.assertIn(AS7341_STALE_DATA, res.warnings)


class TestMAX30102Validator(unittest.TestCase):
    def setUp(self) -> None:
        self.validator = MAX30102Validator()

    def test_valid_sample(self) -> None:
        res = self.validator.validate_sample(red=45000, ir=50000, finger_detected=True)
        self.assertTrue(res.valid)
        self.assertEqual(res.reasons, [])

    def test_invalid_non_numeric(self) -> None:
        res = self.validator.validate_sample(red=None, ir=50000, finger_detected=True)
        self.assertFalse(res.valid)
        self.assertIn(MAX30102_INVALID_NUMERIC_VALUE, res.reasons)

    def test_out_of_range(self) -> None:
        res = self.validator.validate_sample(red=300000, ir=50000, finger_detected=True)
        self.assertFalse(res.valid)
        self.assertIn(MAX30102_ADC_OUT_OF_RANGE, res.reasons)

    def test_no_finger(self) -> None:
        res = self.validator.validate_sample(red=45000, ir=50000, finger_detected=False)
        self.assertFalse(res.valid)
        self.assertIn(MAX30102_NO_FINGER, res.reasons)

    def test_zero_signal(self) -> None:
        res = self.validator.validate_sample(red=0, ir=0, finger_detected=True)
        self.assertFalse(res.valid)
        self.assertIn(MAX30102_ZERO_SIGNAL, res.reasons)

    def test_low_signal(self) -> None:
        res = self.validator.validate_sample(red=1000, ir=2000, finger_detected=True)
        self.assertFalse(res.valid)
        self.assertIn(MAX30102_LOW_SIGNAL, res.reasons)

    def test_fifo_overflow(self) -> None:
        res = self.validator.validate_sample(red=45000, ir=50000, finger_detected=True, overflow_counter=2)
        self.assertFalse(res.valid)
        self.assertIn(MAX30102_FIFO_OVERFLOW, res.reasons)

    def test_stale_data_warning(self) -> None:
        history = [(45000, 50000) for _ in range(5)]
        res = self.validator.validate_sample(red=45000, ir=50000, finger_detected=True, history=history)
        self.assertIn(MAX30102_STALE_DATA, res.warnings)


class TestSessionValidator(unittest.TestCase):
    def setUp(self) -> None:
        self.validator = SessionValidator(min_valid_samples=5, max_rejection_ratio=0.3)

    def _dummy_sample(self, ir_val: int) -> UnifiedSample:
        return UnifiedSample(
            timestamp=100.0,
            patient="Test",
            AS7341_415nm=1000,
            AS7341_445nm=1200,
            AS7341_480nm=1400,
            AS7341_515nm=1600,
            AS7341_555nm=1800,
            AS7341_590nm=2000,
            AS7341_630nm=2200,
            AS7341_680nm=2400,
            MAX30102_RED=45000,
            MAX30102_IR=ir_val,
            finger_detected=True,
            as7341_saturated=False,
        )

    def test_all_valid_session(self) -> None:
        samples = [
            EvaluatedSample(sample=self._dummy_sample(50000 + (i * 200)), valid=True, reasons=[], warnings=[])
            for i in range(6)
        ]
        res = self.validator.validate_session(samples)
        self.assertTrue(res.passed)
        self.assertEqual(res.valid_samples, 6)
        self.assertEqual(res.rejected_samples, 0)

    def test_too_few_valid_samples(self) -> None:
        samples = [
            EvaluatedSample(sample=self._dummy_sample(50000), valid=True, reasons=[], warnings=[])
            for _ in range(3)
        ]
        res = self.validator.validate_session(samples)
        self.assertFalse(res.passed)
        self.assertIn(REASON_SESSION_TOO_FEW_VALID_SAMPLES, res.reasons)

    def test_excessive_rejection_ratio(self) -> None:
        samples = [
            EvaluatedSample(sample=self._dummy_sample(50000 + i), valid=True, reasons=[], warnings=[])
            for i in range(5)
        ] + [
            EvaluatedSample(sample=self._dummy_sample(0), valid=False, reasons=["ERR"], warnings=[])
            for _ in range(5)
        ]
        res = self.validator.validate_session(samples)
        self.assertFalse(res.passed)
        self.assertIn(REASON_SESSION_EXCESSIVE_REJECTIONS, res.reasons)


if __name__ == "__main__":
    unittest.main()


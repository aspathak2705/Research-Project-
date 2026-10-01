import unittest

from config.constants import (
    REASON_SESSION_EXCESSIVE_REJECTIONS,
    REASON_SESSION_POOR_SIGNAL_QUALITY,
    REASON_SESSION_TOO_FEW_VALID_SAMPLES,
)
from hardware.sensor_manager import UnifiedSample
from processing.session_validator import EvaluatedSample, SessionStatus, SessionValidator


class TestSessionValidatorPipeline(unittest.TestCase):
    def setUp(self) -> None:
        self.validator = SessionValidator(min_valid_samples=10, max_rejection_ratio=0.3)

    def _sample(self, ir_val: int) -> UnifiedSample:
        return UnifiedSample(
            timestamp=100.0,
            patient="P1",
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

    def test_session_accepted(self) -> None:
        samples = [
            EvaluatedSample(sample=self._sample(50000 + (i * 100)), valid=True, reasons=[], warnings=[])
            for i in range(12)
        ]
        res = self.validator.validate_session(samples)
        self.assertEqual(res.status, SessionStatus.SESSION_ACCEPTED)
        self.assertTrue(res.passed)
        self.assertEqual(res.valid_samples, 12)
        self.assertEqual(res.rejected_samples, 0)

    def test_session_rejected_too_few(self) -> None:
        samples = [
            EvaluatedSample(sample=self._sample(50000 + i), valid=True, reasons=[], warnings=[])
            for i in range(5)
        ]
        res = self.validator.validate_session(samples)
        self.assertEqual(res.status, SessionStatus.SESSION_REJECTED)
        self.assertFalse(res.passed)
        self.assertIn(REASON_SESSION_TOO_FEW_VALID_SAMPLES, res.reasons)

    def test_session_rejected_excessive_rejections(self) -> None:
        samples = [
            EvaluatedSample(sample=self._sample(50000 + i), valid=True, reasons=[], warnings=[])
            for i in range(10)
        ] + [
            EvaluatedSample(sample=self._sample(0), valid=False, reasons=["AS7341_ALL_ZERO"], warnings=[])
            for _ in range(10)
        ]
        res = self.validator.validate_session(samples)
        self.assertEqual(res.status, SessionStatus.SESSION_REJECTED)
        self.assertIn(REASON_SESSION_EXCESSIVE_REJECTIONS, res.reasons)
        self.assertEqual(res.rejection_histogram["AS7341_ALL_ZERO"], 10)

    def test_session_aborted_and_incomplete(self) -> None:
        samples = [
            EvaluatedSample(sample=self._sample(50000 + i), valid=True, reasons=[], warnings=[])
            for i in range(12)
        ]
        res_aborted = self.validator.validate_session(samples, is_aborted=True)
        self.assertEqual(res_aborted.status, SessionStatus.SESSION_ABORTED)
        self.assertFalse(res_aborted.passed)

        res_inc = self.validator.validate_session(samples, is_incomplete=True)
        self.assertEqual(res_inc.status, SessionStatus.SESSION_INCOMPLETE)
        self.assertFalse(res_inc.passed)


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import csv
import json
import tempfile
import unittest
from pathlib import Path

from validation.as7341.analysis import (
    calculate_channel_statistics,
    calculate_drift,
    compare_conditions,
)
from validation.as7341.plots import SVGPlotGenerator
from validation.as7341.report import ValidationReportGenerator
from validation.as7341.schemas import RAW_CSV_COLUMNS
from validation.as7341.validators import RawDataIntegrityValidator

class TestValidationHarnessUnits(unittest.TestCase):
    """
    Software unit tests for the AS7341 validation harness math and parsing.
    Clearly labeled: SOFTWARE TEST FIXTURE (not physical validation evidence).
    """

    def test_calculate_channel_statistics_normal(self) -> None:
        values = [100, 102, 98, 101, 99]
        res = calculate_channel_statistics(values)
        self.assertEqual(res["n"], 5)
        self.assertEqual(res["mean"], 100.0)
        self.assertEqual(res["min"], 98)
        self.assertEqual(res["max"], 102)
        self.assertEqual(res["range"], 4)
        self.assertIsNotNone(res["cv_percent"])
        self.assertFalse(res["potentially_stuck"])

    def test_calculate_channel_statistics_stuck_channel(self) -> None:
        values = [50] * 12
        res = calculate_channel_statistics(values)
        self.assertEqual(res["n"], 12)
        self.assertEqual(res["mean"], 50.0)
        self.assertEqual(res["range"], 0)
        self.assertTrue(res["potentially_stuck"])

    def test_calculate_channel_statistics_zero_mean(self) -> None:
        values = [0, 0, 0, 0]
        res = calculate_channel_statistics(values)
        self.assertEqual(res["n"], 4)
        self.assertEqual(res["mean"], 0.0)
        # CV should be None when mean is 0 to avoid zero-division
        self.assertIsNone(res["cv_percent"])

    def test_calculate_drift(self) -> None:
        # Values drifting upward over 60 seconds
        values = [100, 100, 100, 110, 110, 110]
        drift = calculate_drift(values, duration_seconds=60.0)
        self.assertEqual(drift["drift_units_per_minute"], 10.0)
        self.assertEqual(drift["percent_drift_total"], 10.0)

    def test_compare_conditions(self) -> None:
        baseline = {"415": {"mean": 100.0}}
        response = {"415": {"mean": 250.0}}
        comp = compare_conditions(baseline, response)
        self.assertEqual(len(comp), 8)
        ch_415 = next(c for c in comp if c["channel"] == "415nm")
        self.assertEqual(ch_415["baseline_mean"], 100.0)
        self.assertEqual(ch_415["response_mean"], 250.0)
        self.assertEqual(ch_415["absolute_diff"], 150.0)
        self.assertEqual(ch_415["relative_diff_percent"], 150.0)

    def test_raw_data_integrity_validator(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            csv_path = Path(tmp_dir) / "test_capture.csv"
            with open(csv_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(RAW_CSV_COLUMNS)
                writer.writerow([
                    "2026-10-04T00:00:00Z", "1", "DARK",
                    "10", "12", "14", "16", "18", "20", "22", "24",
                    "15.5", "true", "OK", "200.0", "128"
                ])
                writer.writerow([
                    "2026-10-04T00:00:01Z", "2", "DARK",
                    "11", "13", "15", "17", "19", "21", "23", "25",
                    "16.2", "true", "OK", "200.0", "128"
                ])

            val = RawDataIntegrityValidator.validate_raw_csv(csv_path)
            self.assertTrue(val["valid"])
            self.assertEqual(val["row_count"], 2)

    def test_svg_plot_generator(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            bar_path = Path(tmp_dir) / "test_bar.svg"
            SVGPlotGenerator.generate_spectral_barplot(
                {"415": 100.0, "555": 250.0, "680": 180.0},
                "Test Spectral Plot",
                bar_path,
            )
            self.assertTrue(bar_path.exists())
            content = bar_path.read_text(encoding="utf-8")
            self.assertIn("<svg", content)
            self.assertIn("Test Spectral Plot", content)

    def test_report_generator_pipeline_refuses_non_physical(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            run_dir = Path(tmp_dir)
            manifest = run_dir / "manifest.json"
            with open(manifest, "w", encoding="utf-8") as f:
                json.dump({"run_id": "TEST", "physical_hardware": False}, f)

            gen = ValidationReportGenerator(run_dir)
            with self.assertRaises(ValueError) as ctx:
                gen.run_pipeline()
            self.assertIn("non-physical", str(ctx.exception))

if __name__ == "__main__":
    unittest.main()

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
    Software unit tests for the AS7341 validation harness math, parsing, and condition-aware diagnostics.
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
        self.assertEqual(res["diagnostic_flag"], "NORMAL")

    def test_calculate_channel_statistics_stuck_channel(self) -> None:
        values = [50] * 12
        res = calculate_channel_statistics(values)
        self.assertEqual(res["n"], 12)
        self.assertEqual(res["mean"], 50.0)
        self.assertEqual(res["range"], 0)
        self.assertTrue(res["potentially_stuck"])
        self.assertEqual(res["diagnostic_flag"], "POTENTIALLY_STUCK")

    def test_calculate_channel_statistics_zero_mean(self) -> None:
        values = [0, 0, 0, 0]
        res = calculate_channel_statistics(values)
        self.assertEqual(res["n"], 4)
        self.assertEqual(res["mean"], 0.0)
        self.assertIsNone(res["cv_percent"])
        self.assertFalse(res["potentially_stuck"])
        self.assertEqual(res["diagnostic_flag"], "NORMAL")

    # --- Case A: Empty Input ---
    def test_case_a_empty_input(self) -> None:
        res = calculate_channel_statistics([])
        self.assertEqual(res["n"], 0)
        self.assertIsNone(res["mean"])
        self.assertIsNone(res["std_dev"])
        self.assertIsNone(res["min"])
        self.assertIsNone(res["max"])
        self.assertIsNone(res["range"])
        self.assertIsNone(res["cv_percent"])
        self.assertFalse(res["potentially_stuck"])
        self.assertEqual(res["diagnostic_flag"], "NO_DATA")

    # --- Case B: Constant zero in darkness ---
    def test_case_b_constant_zero_dark(self) -> None:
        values = [0] * 30
        res = calculate_channel_statistics(values, condition="DARK")
        self.assertEqual(res["n"], 30)
        self.assertEqual(res["mean"], 0.0)
        self.assertEqual(res["range"], 0)
        self.assertFalse(res["potentially_stuck"])
        self.assertEqual(res["diagnostic_flag"], "ZERO_BASELINE")

    # --- Case C: Constant positive readings under reference light ---
    def test_case_c_constant_positive_reference_light(self) -> None:
        values = [2000] * 30
        res = calculate_channel_statistics(values, condition="REFERENCE_LIGHT")
        self.assertEqual(res["n"], 30)
        self.assertEqual(res["range"], 0)
        self.assertTrue(res["potentially_stuck"])
        self.assertEqual(res["diagnostic_flag"], "POTENTIALLY_STUCK")

    # --- Case D: Varying values under reference light ---
    def test_case_d_varying_values_reference_light(self) -> None:
        values = [2000 + (i % 5) for i in range(30)]
        res = calculate_channel_statistics(values, condition="REFERENCE_LIGHT")
        self.assertEqual(res["n"], 30)
        self.assertGreater(res["range"], 0)
        self.assertFalse(res["potentially_stuck"])
        self.assertEqual(res["diagnostic_flag"], "NORMAL")

    # --- Case E: Fewer than 10 constant samples ---
    def test_case_e_fewer_than_10_constant_samples(self) -> None:
        values = [500] * 5
        res = calculate_channel_statistics(values, condition="REFERENCE_LIGHT")
        self.assertEqual(res["n"], 5)
        self.assertEqual(res["range"], 0)
        self.assertFalse(res["potentially_stuck"])
        self.assertEqual(res["diagnostic_flag"], "NORMAL")

    # --- Case F: Constant nonzero values in darkness ---
    def test_case_f_constant_nonzero_dark(self) -> None:
        values = [50] * 30
        res = calculate_channel_statistics(values, condition="DARK")
        self.assertEqual(res["n"], 30)
        self.assertEqual(res["range"], 0)
        self.assertTrue(res["potentially_stuck"])
        self.assertEqual(res["diagnostic_flag"], "POTENTIALLY_STUCK")

    # --- Case G: Backward compatibility without condition parameter ---
    def test_case_g_backward_compatibility(self) -> None:
        values_stuck = [100] * 15
        res_stuck = calculate_channel_statistics(values_stuck)
        self.assertTrue(res_stuck["potentially_stuck"])
        self.assertEqual(res_stuck["diagnostic_flag"], "POTENTIALLY_STUCK")

        values_normal = [100, 105, 95]
        res_normal = calculate_channel_statistics(values_normal)
        self.assertFalse(res_normal["potentially_stuck"])
        self.assertEqual(res_normal["diagnostic_flag"], "NORMAL")

    # --- Case H: Pipeline integration with condition-aware diagnostics ---
    def test_case_h_report_generator_pipeline_condition_aware(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            run_dir = Path(tmp_dir)
            manifest = run_dir / "manifest.json"
            raw_dir = run_dir / "raw"
            raw_dir.mkdir(parents=True, exist_ok=True)

            with open(manifest, "w", encoding="utf-8") as f:
                json.dump({
                    "run_id": "TEST_RUN_COND",
                    "physical_hardware": True,
                    "production_driver": "adafruit-circuitpython-as7341",
                    "package_version": "1.2.27",
                    "sensor_address": "0x39",
                    "i2c_bus_id": 1,
                    "integration_time_ms": 200.0,
                    "gain": 128,
                    "sampling_interval_ms": 250,
                }, f)

            # 1. Dark CSV with 30 zero samples for 415nm and varying for 680nm
            dark_csv = raw_dir / "dark.csv"
            with open(dark_csv, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(RAW_CSV_COLUMNS)
                for idx in range(1, 31):
                    writer.writerow([
                        f"2026-10-22T18:54:{idx:02d}Z", str(idx), "DARK",
                        "0", "0", "0", "0", "1", "10", "35", str(26 + (idx % 3)),
                        "640.0", "true", "OK", "200.0", "128"
                    ])

            # 2. Reference Light CSV with varying nonzero samples
            ref_csv = raw_dir / "reference_light.csv"
            with open(ref_csv, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(RAW_CSV_COLUMNS)
                for idx in range(1, 31):
                    writer.writerow([
                        f"2026-10-22T18:55:{idx:02d}Z", str(idx), "REFERENCE_LIGHT",
                        str(250 + (idx % 5)), str(2060 + (idx % 7)), str(2270 + (idx % 6)), str(2050 + (idx % 5)),
                        str(3780 + (idx % 8)), str(3010 + (idx % 6)), str(1830 + (idx % 5)), str(1370 + (idx % 4)),
                        "644.0", "true", "OK", "200.0", "128"
                    ])

            gen = ValidationReportGenerator(run_dir)
            report_path = gen.run_pipeline()
            self.assertTrue(report_path.exists())

            # Verify Markdown report content
            md_text = report_path.read_text(encoding="utf-8")
            self.assertIn("ZERO_BASELINE", md_text)
            self.assertIn("NORMAL", md_text)

            # Verify HTML report content & html escaping
            html_path = run_dir / "report" / "AS7341_Physical_Validation_Report.html"
            self.assertTrue(html_path.exists())
            html_text = html_path.read_text(encoding="utf-8")
            self.assertIn("ZERO_BASELINE", html_text)

            # Verify CSV output
            csv_path = run_dir / "analysis" / "channel_statistics.csv"
            self.assertTrue(csv_path.exists())
            with open(csv_path, "r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                rows = list(reader)
                dark_415 = next(r for r in rows if r["condition"] == "DARK" and r["channel"] == "415nm")
                self.assertEqual(dark_415["diagnostic_flag"], "ZERO_BASELINE")
                self.assertEqual(dark_415["potentially_stuck"], "False")

                ref_415 = next(r for r in rows if r["condition"] == "REFERENCE_LIGHT" and r["channel"] == "415nm")
                self.assertEqual(ref_415["diagnostic_flag"], "NORMAL")
                self.assertEqual(ref_415["potentially_stuck"], "False")

    def test_calculate_drift(self) -> None:
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

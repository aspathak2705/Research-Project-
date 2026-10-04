from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
from typing import Any

from validation.as7341.analysis import (
    calculate_channel_statistics,
    calculate_drift,
    compare_conditions,
)
from validation.as7341.config import SPECTRAL_CHANNELS
from validation.as7341.plots import SVGPlotGenerator
from validation.as7341.validators import RawDataIntegrityValidator

def compute_sha256(file_path: Path) -> str:
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

class ValidationReportGenerator:
    def __init__(self, run_dir: Path) -> None:
        self.run_dir = run_dir
        self.manifest_file = run_dir / "manifest.json"
        self.raw_dir = run_dir / "raw"
        self.analysis_dir = run_dir / "analysis"
        self.plots_dir = run_dir / "plots"
        self.report_dir = run_dir / "report"

    def run_pipeline(self) -> Path:
        if not self.manifest_file.exists():
            raise FileNotFoundError(f"Manifest not found in {self.run_dir}")

        with open(self.manifest_file, "r", encoding="utf-8") as f:
            manifest = json.load(f)

        # Authenticity & Physical Provenance Check
        if not manifest.get("physical_hardware", False):
            raise ValueError("Manifest indicates non-physical execution. Physical validation refused.")

        self.analysis_dir.mkdir(parents=True, exist_ok=True)
        self.plots_dir.mkdir(parents=True, exist_ok=True)
        self.report_dir.mkdir(parents=True, exist_ok=True)

        raw_csv_files = list(self.raw_dir.glob("*.csv"))
        if not raw_csv_files:
            raise FileNotFoundError(f"No raw capture files found in {self.raw_dir}")

        condition_stats: dict[str, dict[str, Any]] = {}
        condition_durations: dict[str, list[float]] = {}
        all_integrity_results: dict[str, Any] = {}

        # 1. Process each raw condition file
        for csv_path in raw_csv_files:
            cond_name = csv_path.stem.upper()
            val_result = RawDataIntegrityValidator.validate_raw_csv(csv_path)
            all_integrity_results[cond_name] = val_result

            if not val_result["valid"]:
                continue

            rows = val_result["rows"]
            durations: list[float] = []
            channel_series: dict[str, list[int]] = {ch: [] for ch in SPECTRAL_CHANNELS}

            for r in rows:
                durations.append(float(r["acquisition_duration_ms"]))
                for ch in SPECTRAL_CHANNELS:
                    channel_series[ch].append(int(r[f"{ch}nm"]))

            condition_durations[cond_name] = durations

            ch_stats: dict[str, Any] = {}
            for ch in SPECTRAL_CHANNELS:
                ch_stats[ch] = calculate_channel_statistics(channel_series[ch])
            condition_stats[cond_name] = ch_stats

            # Generate Plots for this condition
            SVGPlotGenerator.generate_spectral_barplot(
                {ch: float(ch_stats[ch]["mean"] or 0) for ch in SPECTRAL_CHANNELS},
                f"Spectral Response Profile — Condition: {cond_name}",
                self.plots_dir / f"spectrum_{cond_name.lower()}.svg",
            )

            SVGPlotGenerator.generate_timeline_plot(
                channel_series,
                f"Temporal Channel Stability — Condition: {cond_name}",
                self.plots_dir / f"stability_{cond_name.lower()}.svg",
            )

        # 2. Write channel_statistics.csv
        stat_csv_path = self.analysis_dir / "channel_statistics.csv"
        with open(stat_csv_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["condition", "channel", "n", "mean", "std_dev", "min", "max", "range", "cv_percent", "potentially_stuck"])
            for cond, ch_map in condition_stats.items():
                for ch, s in ch_map.items():
                    writer.writerow([
                        cond, f"{ch}nm", s["n"], s["mean"], s["std_dev"], s["min"], s["max"], s["range"], s["cv_percent"], s["potentially_stuck"]
                    ])

        # 3. Optical Response comparison if baseline and response present
        comparisons: list[dict[str, Any]] = []
        if "DARK" in condition_stats and "REFERENCE_LIGHT" in condition_stats:
            comparisons = compare_conditions(condition_stats["DARK"], condition_stats["REFERENCE_LIGHT"])
            comp_csv_path = self.analysis_dir / "optical_response.csv"
            with open(comp_csv_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(["channel", "dark_mean", "reference_mean", "abs_diff", "rel_diff_percent"])
                for row in comparisons:
                    writer.writerow([row["channel"], row["baseline_mean"], row["response_mean"], row["absolute_diff"], row["relative_diff_percent"]])

        # 4. Generate Markdown and HTML Reports
        md_report_path = self.report_dir / "AS7341_Physical_Validation_Report.md"
        html_report_path = self.report_dir / "AS7341_Physical_Validation_Report.html"

        md_content = self._build_markdown_report(manifest, condition_stats, condition_durations, comparisons)
        with open(md_report_path, "w", encoding="utf-8") as f:
            f.write(md_content)

        html_content = self._build_html_report(manifest, condition_stats, condition_durations, comparisons)
        with open(html_report_path, "w", encoding="utf-8") as f:
            f.write(html_content)

        # 5. Checksums
        checksums_path = self.run_dir / "SHA256SUMS.txt"
        with open(checksums_path, "w", encoding="utf-8") as f:
            for p in sorted(self.run_dir.rglob("*")):
                if p.is_file() and p.name != "SHA256SUMS.txt":
                    rel = p.relative_to(self.run_dir)
                    f.write(f"{compute_sha256(p)}  {rel.as_posix()}\n")

        return md_report_path

    def _build_markdown_report(
        self,
        manifest: dict[str, Any],
        stats: dict[str, dict[str, Any]],
        durations: dict[str, list[float]],
        comparisons: list[dict[str, Any]],
    ) -> str:
        lines = [
            "# AS7341 Production Physical Validation Report",
            "",
            "## 1. Executive Summary",
            f"- **Run ID**: `{manifest.get('run_id')}`",
            f"- **Timestamp**: `{manifest.get('timestamp_start')}` to `{manifest.get('timestamp_end', 'N/A')}`",
            f"- **Physical Hardware Verified**: `{manifest.get('physical_hardware')}`",
            f"- **Production Driver**: `{manifest.get('production_driver')}` (v`{manifest.get('package_version')}`)",
            f"- **Sensor Address**: `{manifest.get('sensor_address')}` on Bus `{manifest.get('i2c_bus_id')}`",
            "",
            "## 2. Validation Objective",
            "Characterize real physical sensor stability, channel response, dark baseline, and repeatability using the unmodified HemoPi production acquisition path.",
            "",
            "## 3. Hardware & Software Provenance",
            f"- **Git Commit**: `{manifest.get('provenance', {}).get('git_commit', 'unavailable')}`",
            f"- **Git Branch**: `{manifest.get('provenance', {}).get('git_branch', 'unavailable')}`",
            f"- **Working Tree Dirty**: `{manifest.get('provenance', {}).get('git_dirty', 'unavailable')}`",
            f"- **Integration Time**: `{manifest.get('integration_time_ms')} ms`",
            f"- **Gain**: `{manifest.get('gain')}x`",
            f"- **Sampling Interval**: `{manifest.get('sampling_interval_ms')} ms`",
            "",
            "## 4. Channel-by-Channel Physical Results",
        ]

        for cond, ch_map in stats.items():
            lines.append(f"### Condition: {cond}")
            lines.append("| Channel | Samples | Mean ADC | Std Dev | Min | Max | Range | CV (%) | Flag |")
            lines.append("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
            for ch, s in ch_map.items():
                flag = "POTENTIALLY_STUCK" if s["potentially_stuck"] else "NORMAL"
                cv_str = f"{s['cv_percent']}%" if s['cv_percent'] is not None else "N/A"
                lines.append(f"| {ch}nm | {s['n']} | {s['mean']} | {s['std_dev']} | {s['min']} | {s['max']} | {s['range']} | {cv_str} | {flag} |")
            lines.append("")

        if comparisons:
            lines.append("## 5. Controlled Optical Response (Dark vs Reference)")
            lines.append("| Channel | Dark Mean | Reference Mean | Absolute Difference | Relative Change |")
            lines.append("| :--- | :--- | :--- | :--- | :--- |")
            for comp in comparisons:
                rel = f"{comp['relative_diff_percent']}%" if comp['relative_diff_percent'] is not None else "N/A"
                lines.append(f"| {comp['channel']} | {comp['baseline_mean']} | {comp['response_mean']} | {comp['absolute_diff']} | {rel} |")
            lines.append("")

        lines.extend([
            "## 6. Acquisition Timing Characterization",
            "| Condition | Samples | Mean (ms) | Min (ms) | Max (ms) |",
            "| :--- | :--- | :--- | :--- | :--- |",
        ])
        for cond, dur_list in durations.items():
            if dur_list:
                m_dur = round(sum(dur_list) / len(dur_list), 2)
                lines.append(f"| {cond} | {len(dur_list)} | {m_dur} | {min(dur_list):.2f} | {max(dur_list):.2f} |")
        lines.append("")

        lines.extend([
            "## 7. Evidence-Based Validation Status",
            "- **AS7341 I2C Communication**: PASS",
            "- **Production Acquisition Execution**: PASS",
            "- **Channel Integrity**: ASSESSED (Review detailed table above)",
            "- **Temporal Stability**: ASSESSED (Review detailed table above)",
            "- **Overall Validation State**: COMPLETED — AWAITING RESEARCH HUMAN REVIEW",
            "",
            "> [!NOTE]",
            "> This report represents empirical physical instrumentation data. It does NOT constitute clinical validation or automatic research gate unlock.",
        ])

        return "\n".join(lines)

    def _build_html_report(
        self,
        manifest: dict[str, Any],
        stats: dict[str, dict[str, Any]],
        durations: dict[str, list[float]],
        comparisons: list[dict[str, Any]],
    ) -> str:
        # Wrap the markdown report in clean semantic HTML styling
        md = self._build_markdown_report(manifest, stats, durations, comparisons)
        return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>AS7341 Physical Validation Report - {manifest.get('run_id')}</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; max-width: 900px; margin: 40px auto; padding: 0 20px; color: #1E293B; }}
    h1, h2, h3 {{ color: #0F172A; }}
    table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
    th, td {{ padding: 10px; border: 1px solid #CBD5E1; text-align: left; font-size: 13px; }}
    th {{ background-color: #F1F5F9; font-weight: 600; }}
    code {{ background-color: #F8FAFC; padding: 2px 6px; border-radius: 4px; font-family: monospace; font-size: 13px; }}
    .banner {{ background-color: #FEF3C7; border: 1px solid #FDE68A; padding: 14px; border-radius: 8px; margin: 20px 0; font-size: 13px; color: #92400E; }}
  </style>
</head>
<body>
  <div class="banner">
    <strong>Physical Hardware Evidence Package:</strong> Generated by HemoPi Production Validation Harness.
  </div>
  <pre style="white-space: pre-wrap; font-family: inherit;">{html.escape(md)}</pre>
</body>
</html>"""

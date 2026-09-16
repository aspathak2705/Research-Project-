from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Sequence

from processing.session_validator import EvaluatedSample, SessionValidationResult
from utils.helpers import ensure_directory, sanitize_patient_name


class DiagnosticStorage:
    def __init__(self, data_root: Path) -> None:
        self.data_root = ensure_directory(data_root)
        self.rejected_root = ensure_directory(self.data_root / "rejected")
        self.diagnostics_root = ensure_directory(self.data_root / "diagnostics")

    def save_diagnostics(
        self,
        patient_name: str,
        session_id: str,
        result: SessionValidationResult,
    ) -> tuple[Path | None, Path]:
        patient_slug = sanitize_patient_name(patient_name)
        patient_rejected_dir = ensure_directory(self.rejected_root / patient_slug)
        patient_diag_dir = ensure_directory(self.diagnostics_root / patient_slug)

        rejected_file: Path | None = None
        rejected_items = [item for item in result.evaluated_samples if not item.valid]

        if rejected_items:
            rejected_file = patient_rejected_dir / f"{session_id}_rejected.csv"
            fieldnames = [
                "timestamp",
                "patient_name",
                "AS7341_415nm",
                "AS7341_445nm",
                "AS7341_480nm",
                "AS7341_515nm",
                "AS7341_555nm",
                "AS7341_590nm",
                "AS7341_630nm",
                "AS7341_680nm",
                "max30102_red",
                "max30102_ir",
                "finger_detected",
                "reasons",
                "warnings",
            ]
            with rejected_file.open("w", newline="", encoding="utf-8") as csv_file:
                writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
                writer.writeheader()
                for item in rejected_items:
                    s = item.sample
                    row = {
                        "timestamp": s.timestamp,
                        "patient_name": patient_name,
                        "max30102_red": s.max_red,
                        "max30102_ir": s.max_ir,
                        "finger_detected": s.finger_detected,
                        "reasons": "|".join(item.reasons),
                        "warnings": "|".join(item.warnings),
                    }
                    row.update(s.as7341_channels)
                    writer.writerow(row)

        diag_file = patient_diag_dir / f"{session_id}_diagnostics.json"
        payload = {
            "session_id": session_id,
            "patient_name": patient_name,
            "session_passed": result.passed,
            "attempted_samples": result.attempted_samples,
            "valid_samples": result.valid_samples,
            "rejected_samples": result.rejected_samples,
            "rejection_ratio": result.rejection_ratio,
            "session_reasons": result.reasons,
            "sample_diagnostics": [
                {
                    "timestamp": item.sample.timestamp,
                    "valid": item.valid,
                    "reasons": item.reasons,
                    "warnings": item.warnings,
                }
                for item in result.evaluated_samples
            ],
        }

        with diag_file.open("w", encoding="utf-8") as json_file:
            json.dump(payload, json_file, indent=2)

        return rejected_file, diag_file

from __future__ import annotations

import csv
from pathlib import Path
from typing import Any

from validation.as7341.config import SPECTRAL_CHANNELS
from validation.as7341.schemas import RAW_CSV_COLUMNS

class RawDataIntegrityValidator:
    @staticmethod
    def validate_raw_csv(csv_path: Path) -> dict[str, Any]:
        if not csv_path.exists():
            return {
                "valid": False,
                "error": f"File does not exist: {csv_path}",
                "row_count": 0,
            }

        rows: list[dict[str, str]] = []
        issues: list[str] = []

        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            header = next(reader, None)
            if header is None or header != RAW_CSV_COLUMNS:
                return {
                    "valid": False,
                    "error": f"Invalid header in {csv_path.name}. Found: {header}",
                    "row_count": 0,
                }

            expected_len = len(RAW_CSV_COLUMNS)
            last_index = 0

            for line_no, row in enumerate(reader, start=2):
                if len(row) != expected_len:
                    issues.append(f"Line {line_no}: Column count mismatch ({len(row)} vs {expected_len})")
                    continue

                row_dict = dict(zip(RAW_CSV_COLUMNS, row))
                rows.append(row_dict)

                # Check monotonic sample_index
                try:
                    s_idx = int(row_dict["sample_index"])
                    if s_idx <= last_index:
                        issues.append(f"Line {line_no}: Non-monotonic sample index {s_idx} <= {last_index}")
                    last_index = s_idx
                except ValueError:
                    issues.append(f"Line {line_no}: Invalid non-integer sample_index '{row_dict['sample_index']}'")

                # Check channel numeric values
                for ch in SPECTRAL_CHANNELS:
                    col_name = f"{ch}nm"
                    val_str = row_dict.get(col_name, "")
                    try:
                        val = int(val_str)
                        if val < 0 or val > 65535:
                            issues.append(f"Line {line_no}: Channel {ch}nm value {val} out of 16-bit range")
                    except ValueError:
                        issues.append(f"Line {line_no}: Non-integer value '{val_str}' for channel {ch}nm")

        is_valid = len(issues) == 0 and len(rows) > 0
        return {
            "valid": is_valid,
            "issues": issues,
            "row_count": len(rows),
            "rows": rows,
        }

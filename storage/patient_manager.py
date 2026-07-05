from __future__ import annotations

from pathlib import Path

from utils.helpers import ensure_directory, sanitize_patient_name


class PatientDataManager:
    def __init__(self, patient_root: Path) -> None:
        self.patient_root = ensure_directory(patient_root)

    def get_patient_directory(self, patient_name: str) -> Path:
        return ensure_directory(self.patient_root / sanitize_patient_name(patient_name))

    def next_session_path(self, patient_name: str) -> Path:
        patient_dir = self.get_patient_directory(patient_name)
        existing = sorted(patient_dir.glob("session_*.csv"))
        session_number = len(existing) + 1
        return patient_dir / f"session_{session_number:03d}.csv"


from __future__ import annotations

from pathlib import Path

from utils.helpers import ensure_directory, sanitize_patient_name


import datetime
import uuid


class PatientDataManager:
    def __init__(self, patient_root: Path) -> None:
        self.patient_root = ensure_directory(patient_root)

    def get_patient_directory(self, patient_name: str) -> Path:
        return ensure_directory(self.patient_root / sanitize_patient_name(patient_name))

    def next_session_path(self, patient_name: str) -> Path:
        patient_dir = self.get_patient_directory(patient_name)
        timestamp_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S")
        unique_suffix = uuid.uuid4().hex[:4].upper()
        patient_slug = sanitize_patient_name(patient_name).upper()
        session_id = f"{patient_slug}_{timestamp_str}_{unique_suffix}"
        return patient_dir / f"{session_id}.csv"



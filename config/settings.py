from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from config.constants import DEFAULT_GOOGLE_DRIVE_ROOT, DEFAULT_SAMPLE_COUNT


def _env_flag(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    project_root: Path
    data_root: Path
    raw_data_root: Path
    temp_root: Path
    upload_queue_root: Path
    google_drive_root: str
    sample_count: int
    mock_mode: bool
    log_level: str

    @classmethod
    def load(cls) -> "Settings":
        project_root = Path(__file__).resolve().parent.parent
        data_root = Path(os.getenv("HEMO_DATA_ROOT", project_root / "data"))
        raw_data_root = data_root / "raw"
        temp_root = data_root / "temp"
        upload_queue_root = Path(os.getenv("HEMO_UPLOAD_QUEUE", temp_root / "upload_queue"))

        return cls(
            project_root=project_root,
            data_root=data_root,
            raw_data_root=raw_data_root,
            temp_root=temp_root,
            upload_queue_root=upload_queue_root,
            google_drive_root=os.getenv("HEMO_GOOGLE_DRIVE_ROOT", DEFAULT_GOOGLE_DRIVE_ROOT),
            sample_count=int(os.getenv("HEMO_SAMPLE_COUNT", str(DEFAULT_SAMPLE_COUNT))),
            mock_mode=_env_flag("HEMO_MOCK_MODE", True),
            log_level=os.getenv("HEMO_LOG_LEVEL", "INFO").upper(),
        )


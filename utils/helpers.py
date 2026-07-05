from __future__ import annotations

import logging
import re
from datetime import datetime, timezone
from pathlib import Path


def setup_logging(level: str) -> None:
    logging.basicConfig(
        level=getattr(logging, level, logging.INFO),
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    )


def ensure_directory(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def sanitize_patient_name(name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9]+", "_", name.strip())
    return cleaned.strip("_") or "Unknown_Patient"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


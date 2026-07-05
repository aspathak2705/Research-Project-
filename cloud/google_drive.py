from __future__ import annotations

import json
import logging
import shutil
import socket
from dataclasses import dataclass
from pathlib import Path

from utils.helpers import ensure_directory, utc_now_iso

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class UploadJob:
    created_at: str
    patient_name: str
    local_file: str
    remote_root: str
    status: str = "pending"
    uploaded_at: str | None = None


class GoogleDriveSync:
    def __init__(self, queue_root: Path, drive_root_name: str) -> None:
        self.queue_root = ensure_directory(queue_root)
        self.drive_root_name = drive_root_name

    def enqueue(self, patient_name: str, session_file: Path) -> Path:
        job = UploadJob(
            created_at=utc_now_iso(),
            patient_name=patient_name,
            local_file=str(session_file),
            remote_root=self.drive_root_name,
        )
        job_path = self.queue_root / f"{session_file.stem}.json"
        job_path.write_text(json.dumps(job.__dict__, indent=2), encoding="utf-8")
        return job_path

    def sync_pending(self) -> list[Path]:
        synced: list[Path] = []
        if not self._internet_available():
            LOGGER.warning("Internet unavailable. Upload jobs remain queued.")
            return synced

        for job_file in sorted(self.queue_root.glob("*.json")):
            payload = json.loads(job_file.read_text(encoding="utf-8"))
            if payload.get("status") == "uploaded":
                continue

            job = UploadJob(**payload)
            self._upload_file(Path(job.local_file), job.patient_name)
            self._mark_uploaded(job_file, payload)
            synced.append(job_file)

        return synced

    def _upload_file(self, local_file: Path, patient_name: str) -> None:
        # Placeholder sync target. Replace with Google Drive API upload flow.
        mirror_root = ensure_directory(self.queue_root.parent / "drive_mirror" / self.drive_root_name / patient_name)
        shutil.copy2(local_file, mirror_root / local_file.name)
        LOGGER.info("Mirrored %s for patient %s.", local_file.name, patient_name)

    def _mark_uploaded(self, job_file: Path, payload: dict[str, str | None]) -> None:
        payload["status"] = "uploaded"
        payload["uploaded_at"] = utc_now_iso()
        job_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    @staticmethod
    def _internet_available(host: str = "8.8.8.8", port: int = 53, timeout: float = 1.0) -> bool:
        try:
            with socket.create_connection((host, port), timeout=timeout):
                return True
        except OSError:
            return False

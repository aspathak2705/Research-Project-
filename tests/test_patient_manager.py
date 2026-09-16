from pathlib import Path

from storage.patient_manager import PatientDataManager


def test_next_session_path_generates_unique(tmp_path: Path) -> None:
    manager = PatientDataManager(tmp_path)
    first = manager.next_session_path("Raj Alok")
    first.write_text("x", encoding="utf-8")
    second = manager.next_session_path("Raj Alok")

    assert "RAJ_ALOK" in first.name
    assert first.name != second.name



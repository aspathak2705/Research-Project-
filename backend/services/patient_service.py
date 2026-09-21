import json
import os
import threading
from datetime import datetime
from backend.config import PATIENTS_FILE

_patient_file_lock = threading.Lock()

class PatientBackendService:
    @staticmethod
    def _load_patients() -> list:
        if not os.path.exists(PATIENTS_FILE):
            return []
        try:
            with open(PATIENTS_FILE, "r") as f:
                return json.load(f)
        except Exception:
            return []

    @staticmethod
    def _save_patients(patients: list):
        temp_file = f"{PATIENTS_FILE}.tmp"
        with open(temp_file, "w") as f:
            json.dump(patients, f, indent=2)
        os.replace(temp_file, PATIENTS_FILE)

    @staticmethod
    def get_all_patients() -> list:
        with _patient_file_lock:
            return PatientBackendService._load_patients()

    @staticmethod
    def get_patient(patient_id: str) -> dict:
        with _patient_file_lock:
            patients = PatientBackendService._load_patients()
            for p in patients:
                if p["patient_id"] == patient_id:
                    return p
            return None

    @staticmethod
    def create_patient(patient_id: str, age: int = None, sex: str = None, notes: str = None) -> tuple:
        with _patient_file_lock:
            patients = PatientBackendService._load_patients()
            for p in patients:
                if p["patient_id"] == patient_id:
                    return None, f"Patient with ID '{patient_id}' already exists"
            
            new_patient = {
                "patient_id": patient_id,
                "age": age,
                "sex": sex,
                "notes": notes,
                "created_at": datetime.now().isoformat()
            }
            patients.append(new_patient)
            PatientBackendService._save_patients(patients)
            return new_patient, None

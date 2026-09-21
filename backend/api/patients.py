from fastapi import APIRouter, HTTPException
from backend.services.patient_service import PatientBackendService
from backend.schemas.patient import PatientCreateRequest, PatientResponse, PatientListResponse

router = APIRouter(prefix="/api/patients", tags=["Patients"])

@router.get("", response_model=PatientListResponse)
def list_patients():
    patients = PatientBackendService.get_all_patients()
    return {
        "status": "ok",
        "patients": patients
    }

@router.post("", response_model=PatientResponse)
def create_patient(req: PatientCreateRequest):
    patient, err = PatientBackendService.create_patient(
        patient_id=req.patient_id,
        age=req.age,
        sex=req.sex,
        notes=req.notes
    )
    if err:
        raise HTTPException(status_code=409, detail=err)
    return patient

@router.get("/{patient_id}", response_model=PatientResponse)
def get_patient(patient_id: str):
    patient = PatientBackendService.get_patient(patient_id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient record not found")
    return patient

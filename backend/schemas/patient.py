from pydantic import BaseModel
from typing import Optional, List

class PatientCreateRequest(BaseModel):
    patient_id: str
    age: Optional[int] = None
    sex: Optional[str] = None
    notes: Optional[str] = None

class PatientResponse(BaseModel):
    patient_id: str
    age: Optional[int] = None
    sex: Optional[str] = None
    notes: Optional[str] = None
    created_at: str

class PatientListResponse(BaseModel):
    status: str
    patients: List[PatientResponse]

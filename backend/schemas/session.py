from pydantic import BaseModel
from typing import Optional, List

class SessionCreateRequest(BaseModel):
    patient_id: str

class SessionResponse(BaseModel):
    session_id: str
    patient_id: str
    timestamp: str
    status: str
    sample_count: int
    valid_count: int
    rejected_count: int
    message: Optional[str] = None

class SessionListResponse(BaseModel):
    status: str
    sessions: List[SessionResponse]

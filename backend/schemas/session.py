from pydantic import BaseModel
from typing import Optional, List, Dict, Any

class SessionCreateRequest(BaseModel):
    patient_id: str
    demo_mode: bool = False

class SessionResponse(BaseModel):
    session_id: str
    patient_id: str
    timestamp: str
    status: str
    sample_count: int
    valid_count: int
    rejected_count: int
    is_demo: bool = False
    readings: Optional[Dict[str, Any]] = None
    message: Optional[str] = None
    local_csv: Optional[str] = None
    diagnostic_file: Optional[str] = None

class SessionListResponse(BaseModel):
    status: str
    sessions: List[SessionResponse]

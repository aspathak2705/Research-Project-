from pydantic import BaseModel
from typing import Optional, List, Dict, Any

class DiagnosticsResponse(BaseModel):
    last_run_timestamp: str
    i2c_bus_ok: bool
    i2c_addresses: List[str]
    max30102_ok: bool
    as7341_ok: bool
    storage_ok: bool
    acquisition_ready: bool
    rejected_measurements_count: int
    rejection_reasons: List[str]
    recent_error: str

class SessionDiagnosticsResponse(BaseModel):
    session_id: str
    patient_id: str
    timestamp: str
    attempted_samples: int
    valid_samples: int
    rejected_samples: int
    rejection_codes: List[str]
    session_status: str

from fastapi import APIRouter, HTTPException
from backend.services.diagnostics_service import DiagnosticsBackendService
from backend.schemas.diagnostics import DiagnosticsResponse, SessionDiagnosticsResponse

router = APIRouter(prefix="/api/diagnostics", tags=["Diagnostics"])

@router.get("", response_model=DiagnosticsResponse)
def get_diagnostics():
    return DiagnosticsBackendService.get_diagnostics_summary()

@router.get("/{session_id}", response_model=SessionDiagnosticsResponse)
def get_session_diagnostics(session_id: str):
    res = DiagnosticsBackendService.get_session_diagnostics(session_id)
    if not res:
        raise HTTPException(status_code=404, detail="Session diagnostics record not found")
    return res

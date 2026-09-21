from fastapi import APIRouter, HTTPException
from backend.services.session_service import SessionBackendService
from backend.schemas.session import SessionCreateRequest, SessionResponse, SessionListResponse

router = APIRouter(prefix="/api/sessions", tags=["Sessions"])

@router.get("", response_model=SessionListResponse)
def list_sessions():
    sessions = SessionBackendService.get_all_sessions()
    return {
        "status": "ok",
        "sessions": sessions
    }

@router.post("", response_model=SessionResponse)
def create_session(req: SessionCreateRequest):
    session, error_msg = SessionBackendService.create_session(req.patient_id)
    if error_msg:
        raise HTTPException(status_code=409, detail=error_msg)
    return session

@router.get("/{session_id}", response_model=SessionResponse)
def get_session(session_id: str):
    session = SessionBackendService.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session record not found")
    return session

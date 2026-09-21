from fastapi import APIRouter
from backend.services.device_service import DeviceBackendService
from backend.schemas.device import HealthCheckResponse

router = APIRouter(prefix="/api", tags=["Health"])

@router.get("/health", response_model=HealthCheckResponse)
def get_health():
    return DeviceBackendService.get_health_check()

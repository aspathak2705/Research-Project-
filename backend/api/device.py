from fastapi import APIRouter
from backend.services.device_service import DeviceBackendService
from backend.schemas.device import DeviceStatusResponse

router = APIRouter(prefix="/api/device", tags=["Device"])

@router.get("/status", response_model=DeviceStatusResponse)
def get_device_status():
    return DeviceBackendService.get_device_status()

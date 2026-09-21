from fastapi import APIRouter
from backend.services.network_manager import NetworkManagerService
from backend.schemas.network import WifiScanResponse, WifiConnectRequest, WifiConnectResponse

router = APIRouter(prefix="/api/network", tags=["Network"])

@router.get("/wifi", response_model=WifiScanResponse)
def scan_wifi():
    return NetworkManagerService.list_wifi_networks()

@router.post("/wifi/connect", response_model=WifiConnectResponse)
def connect_wifi(req: WifiConnectRequest):
    return NetworkManagerService.connect_wifi(req.ssid, req.password)

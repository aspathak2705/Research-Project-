from fastapi import APIRouter
from backend.services.network_manager import NetworkManagerService
from backend.schemas.network import (
    WifiScanResponse,
    WifiConnectRequest,
    WifiConnectResponse,
    NetworkStatusResponse,
    WifiDisconnectResponse,
)

router = APIRouter(prefix="/api/network", tags=["Network"])

@router.get("/status", response_model=NetworkStatusResponse)
def network_status():
    return NetworkManagerService.get_network_status()

@router.get("/wifi", response_model=WifiScanResponse)
def scan_wifi():
    return NetworkManagerService.list_wifi_networks()

@router.post("/wifi/connect", response_model=WifiConnectResponse)
def connect_wifi(req: WifiConnectRequest):
    return NetworkManagerService.connect_wifi(req.ssid, req.password)

@router.post("/wifi/disconnect", response_model=WifiDisconnectResponse)
def disconnect_wifi():
    return NetworkManagerService.disconnect_wifi()

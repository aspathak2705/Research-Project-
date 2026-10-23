from pydantic import BaseModel, Field
from typing import List, Optional

class WifiNetworkInfo(BaseModel):
    ssid: str
    signal_strength: int = Field(..., ge=0, le=100)
    secured: bool

class WifiScanResponse(BaseModel):
    status: str
    code: str = "SUCCESS"
    networks: List[WifiNetworkInfo]

class WifiConnectRequest(BaseModel):
    ssid: str
    password: str
    pin: Optional[str] = None  # Optional pairing PIN for authorization

class WifiConnectResponse(BaseModel):
    status: str
    code: str
    connection_state: str
    message: Optional[str] = None
    ip_address: Optional[str] = None
    target_ssid: Optional[str] = None

class NetworkStatusResponse(BaseModel):
    hostname: str
    ip_address: str
    connection_state: str
    mode: Optional[str] = "STATION"  # STATION or HOTSPOT
    ssid: Optional[str] = None
    hotspot_active: bool = False
    pairing_required: bool = False

class WifiDisconnectResponse(BaseModel):
    status: str
    code: str
    message: Optional[str] = None

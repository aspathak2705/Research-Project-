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

class WifiConnectResponse(BaseModel):
    status: str
    code: str
    connection_state: str
    message: Optional[str] = None
    ip_address: Optional[str] = None

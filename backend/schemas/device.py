from pydantic import BaseModel
from typing import Optional, Dict, Any

class SensorHealthInfo(BaseModel):
    address: str
    present: bool
    detected: Optional[bool] = None
    initialized: bool
    healthy: bool
    physically_validated: bool
    research_ready: bool
    message: str

class DeviceStatusResponse(BaseModel):
    device_id: Optional[str] = "HemoPi-001"
    device_name: Optional[str] = "HemoPi Portable Analyzer"
    hostname: str
    ip_address: Optional[str]
    connection_state: str
    network_manager_state: str
    max30102: SensorHealthInfo
    as7341: SensorHealthInfo

class HealthCheckResponse(BaseModel):
    device_id: Optional[str] = "HemoPi-001"
    device_name: Optional[str] = "HemoPi Portable Analyzer"
    api: str
    hostname: str
    network: str
    acquisition_ready: bool
    reason: str
    sensors: Dict[str, Dict[str, Any]]

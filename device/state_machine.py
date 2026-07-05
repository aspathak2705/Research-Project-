from __future__ import annotations

from enum import Enum


class DeviceState(str, Enum):
    BOOT = "BOOT"
    SELF_TEST = "SELF_TEST"
    WAIT_FOR_PATIENT = "WAIT_FOR_PATIENT"
    WAIT_FOR_FINGER = "WAIT_FOR_FINGER"
    ACQUIRE = "ACQUIRE"
    QUALITY_CHECK = "QUALITY_CHECK"
    STORE = "STORE"
    UPLOAD = "UPLOAD"
    READY = "READY"


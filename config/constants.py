from __future__ import annotations

from device.state_machine import DeviceState

DEFAULT_SAMPLE_COUNT = 24
MINIMUM_SAMPLE_COUNT = 20
MAXIMUM_SAMPLE_COUNT = 30
MAX30102_DC_MIN = 5_000
MAX30102_AC_MIN = 150
MAX30102_MOTION_LIMIT = 2_000
AS7341_SATURATION_LIMIT = 60_000
DEFAULT_GOOGLE_DRIVE_ROOT = "Portable_Hemoglobin_Data"

STATE_SEQUENCE = (
    DeviceState.BOOT,
    DeviceState.SELF_TEST,
    DeviceState.WAIT_FOR_PATIENT,
    DeviceState.WAIT_FOR_FINGER,
    DeviceState.ACQUIRE,
    DeviceState.QUALITY_CHECK,
    DeviceState.STORE,
    DeviceState.UPLOAD,
    DeviceState.READY,
)


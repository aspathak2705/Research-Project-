from __future__ import annotations

import os
from pathlib import Path

# Base Paths
PROJECT_ROOT = Path(__file__).resolve().parent.parent
VALIDATION_ROOT = PROJECT_ROOT / "validation"
OUTPUTS_DIR = VALIDATION_ROOT / "outputs"

# Sensor Constants
AS7341_I2C_ADDRESS = 0x39
I2C_BUS_ID = 1
REQUIRED_ADAFRUIT_VERSION = "1.2.27"

# Standard AS7341 Spectral Channels (nm)
SPECTRAL_CHANNELS = ("415", "445", "480", "515", "555", "590", "630", "680")

# Standard Validation Conditions
CONDITION_DARK = "DARK"
CONDITION_REFERENCE_LIGHT = "REFERENCE_LIGHT"
CONDITION_CONTROLLED_RESPONSE = "CONTROLLED_RESPONSE"

# Safe Defaults (Explicitly labeled as defaults)
DEFAULT_SAMPLE_COUNT = 30
DEFAULT_INTERVAL_MS = 250
DEFAULT_INTEGRATION_TIME_MS = 200.0
DEFAULT_GAIN = 128

# Saturation & ADC thresholds (from authoritative config/constants.py)
ADC_MIN = 0
ADC_MAX = 65535
SATURATION_LIMIT = 60000
NEAR_ZERO_THRESHOLD = 5

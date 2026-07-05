from __future__ import annotations

import logging

from utils.exceptions import HardwareError

LOGGER = logging.getLogger(__name__)


class I2CBus:
    def __init__(self, bus_id: int = 1, mock_mode: bool = True) -> None:
        self.bus_id = bus_id
        self.mock_mode = mock_mode
        self.bus = None

    def connect(self) -> None:
        if self.mock_mode:
            LOGGER.info("Mock I2C bus enabled on bus %s.", self.bus_id)
            return

        try:
            from smbus2 import SMBus
        except ImportError as exc:
            raise HardwareError("smbus2 not installed for real I2C mode.") from exc

        try:
            self.bus = SMBus(self.bus_id)
            LOGGER.info("I2C bus %s connected.", self.bus_id)
        except OSError as exc:
            raise HardwareError(f"Failed to open I2C bus {self.bus_id}.") from exc

    def close(self) -> None:
        if self.bus is not None:
            self.bus.close()
            self.bus = None


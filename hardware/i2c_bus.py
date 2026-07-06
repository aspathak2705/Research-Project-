from __future__ import annotations

import logging
import time
from dataclasses import dataclass

from utils.exceptions import HardwareError

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class I2CSharedBus:
    busio_bus: object | None
    smbus_bus: object | None


class I2CBus:
    def __init__(self, bus_id: int = 1, mock_mode: bool = True) -> None:
        self.bus_id = bus_id
        self.mock_mode = mock_mode
        self._busio = None
        self._smbus = None

    def connect(self) -> I2CSharedBus:
        if self.mock_mode:
            LOGGER.info("Mock I2C mode enabled. Shared bus objects not opened.")
            return self.shared_bus

        self._initialize_busio()
        self._initialize_smbus()
        devices = self.scan()
        LOGGER.info("I2C bus %s ready. Devices: %s", self.bus_id, [hex(device) for device in devices])
        return self.shared_bus

    @property
    def shared_bus(self) -> I2CSharedBus:
        return I2CSharedBus(busio_bus=self._busio, smbus_bus=self._smbus)

    def get_busio(self) -> object | None:
        return self._busio

    def get_smbus(self) -> object | None:
        return self._smbus

    def scan(self) -> list[int]:
        if self.mock_mode:
            return []

        if self._busio is not None:
            locked = False
            try:
                while not self._busio.try_lock():
                    time.sleep(0.01)
                locked = True
                return list(self._busio.scan())
            except Exception as exc:
                raise HardwareError("Failed to scan I2C devices using busio.") from exc
            finally:
                if locked:
                    self._busio.unlock()

        if self._smbus is None:
            return []

        found: list[int] = []
        for address in range(0x03, 0x78):
            try:
                self._smbus.write_quick(address)
                found.append(address)
            except OSError:
                continue
        return found

    def close(self) -> None:
        if self._busio is not None:
            try:
                self._busio.deinit()
            finally:
                self._busio = None

        if self._smbus is not None:
            self._smbus.close()
            self._smbus = None

    def _initialize_busio(self) -> None:
        try:
            import board
            import busio
        except ImportError as exc:
            raise HardwareError("board/busio not installed. Install Adafruit Blinka for Raspberry Pi I2C support.") from exc

        try:
            self._busio = busio.I2C(board.SCL, board.SDA)
        except Exception as exc:
            raise HardwareError("Failed to initialize busio.I2C.") from exc

    def _initialize_smbus(self) -> None:
        try:
            from smbus2 import SMBus
        except ImportError as exc:
            raise HardwareError("smbus2 not installed for Raspberry Pi I2C support.") from exc

        try:
            self._smbus = SMBus(self.bus_id)
        except OSError as exc:
            raise HardwareError(f"Failed to open smbus2 bus {self.bus_id}.") from exc

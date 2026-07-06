from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from math import sin

from hardware.i2c_bus import I2CSharedBus
from utils.exceptions import HardwareError

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class Max30102Reading:
    red: int
    ir: int
    finger_detected: bool


class MAX30102Sensor:
    ADDRESS = 0x57
    REG_INTR_ENABLE_1 = 0x02
    REG_INTR_ENABLE_2 = 0x03
    REG_FIFO_WR_PTR = 0x04
    REG_OVF_COUNTER = 0x05
    REG_FIFO_RD_PTR = 0x06
    REG_FIFO_DATA = 0x07
    REG_FIFO_CONFIG = 0x08
    REG_MODE_CONFIG = 0x09
    REG_SPO2_CONFIG = 0x0A
    REG_LED1_PA = 0x0C
    REG_LED2_PA = 0x0D
    REG_MULTI_LED_CTRL1 = 0x11
    REG_MULTI_LED_CTRL2 = 0x12
    REG_PART_ID = 0xFF
    FINGER_THRESHOLD = 15_000

    def __init__(self, shared_bus: I2CSharedBus | None = None, mock_mode: bool = True) -> None:
        self.mock_mode = mock_mode
        self.shared_bus = shared_bus
        self._smbus = None if shared_bus is None else shared_bus.smbus_bus
        self._sample_index = 0
        self._last_sample = Max30102Reading(red=0, ir=0, finger_detected=False)

    def initialize(self) -> None:
        if self.mock_mode:
            LOGGER.info("MAX30102 mock mode enabled.")
            return

        if self._smbus is None:
            raise HardwareError("MAX30102 requires shared smbus2 object.")

        self._write_u8(self.REG_MODE_CONFIG, 0x40)
        time.sleep(0.05)
        self._write_u8(self.REG_INTR_ENABLE_1, 0xC0)
        self._write_u8(self.REG_INTR_ENABLE_2, 0x00)
        self._write_u8(self.REG_FIFO_WR_PTR, 0x00)
        self._write_u8(self.REG_OVF_COUNTER, 0x00)
        self._write_u8(self.REG_FIFO_RD_PTR, 0x00)
        self._write_u8(self.REG_FIFO_CONFIG, 0x0F)
        self._write_u8(self.REG_MODE_CONFIG, 0x03)
        self._write_u8(self.REG_SPO2_CONFIG, 0x27)
        self._write_u8(self.REG_LED1_PA, 0x24)
        self._write_u8(self.REG_LED2_PA, 0x24)
        self._write_u8(self.REG_MULTI_LED_CTRL1, 0x21)
        self._write_u8(self.REG_MULTI_LED_CTRL2, 0x00)
        LOGGER.info("MAX30102 initialized at 0x57.")

    def read_sample(self) -> dict[str, int]:
        if self.mock_mode:
            self._last_sample = self._mock_sample()
            red = self._last_sample.red
            ir = self._last_sample.ir
            print("RED:", red, "IR:", ir)
            return {"red": red, "ir": ir}

        raw = self._read_fifo_frame()
        red = ((raw[0] << 16) | (raw[1] << 8) | raw[2]) & 0x03FFFF
        ir = ((raw[3] << 16) | (raw[4] << 8) | raw[5]) & 0x03FFFF
        self._last_sample = Max30102Reading(red=red, ir=ir, finger_detected=ir >= self.FINGER_THRESHOLD)
        print("RED:", red, "IR:", ir)
        return {"red": red, "ir": ir}

    def finger_detected(self) -> bool:
        if self.mock_mode:
            return True

        if self._last_sample.ir == 0:
            self.read_sample()
        return self._last_sample.ir >= self.FINGER_THRESHOLD

    def close(self) -> None:
        if not self.mock_mode and self._smbus is not None:
            self._write_u8(self.REG_MODE_CONFIG, 0x80)

    def _read_fifo_frame(self) -> list[int]:
        try:
            return self._smbus.read_i2c_block_data(self.ADDRESS, self.REG_FIFO_DATA, 6)
        except OSError as exc:
            raise HardwareError("MAX30102 FIFO read failed.") from exc

    def _write_u8(self, register: int, value: int) -> None:
        try:
            self._smbus.write_byte_data(self.ADDRESS, register, value & 0xFF)
        except OSError as exc:
            raise HardwareError(f"MAX30102 write failed at register 0x{register:02X}.") from exc

    def _mock_sample(self) -> Max30102Reading:
        self._sample_index += 1
        pulse = int(sin(self._sample_index / 2.5) * 220)
        drift = (self._sample_index % 5) * 15
        ir = 50_000 + drift - pulse
        red = 46_000 + drift + pulse
        return Max30102Reading(red=red, ir=ir, finger_detected=True)

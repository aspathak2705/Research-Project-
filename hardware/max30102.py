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

    def __init__(self, shared_bus: I2CSharedBus | None = None) -> None:
        self.shared_bus = shared_bus
        self._smbus = None if shared_bus is None else shared_bus.smbus_bus
        self._last_sample = Max30102Reading(red=0, ir=0, finger_detected=False)

    def initialize(self) -> None:
        if self._smbus is None:
            raise HardwareError("MAX30102 requires shared smbus2 object.")

        part_id = self._read_u8(self.REG_PART_ID)
        if part_id != 0x15:
            LOGGER.warning("MAX30102 Part ID read 0x%02X (expected 0x15). Proceeding with register setup.", part_id)

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

    def get_fifo_pointers(self) -> dict[str, int]:
        if self._smbus is None:
            raise HardwareError("MAX30102 I2C bus unavailable.")
        try:
            wr_ptr = self._read_u8(self.REG_FIFO_WR_PTR)
            ovf_cnt = self._read_u8(self.REG_OVF_COUNTER)
            rd_ptr = self._read_u8(self.REG_FIFO_RD_PTR)
            return {"write_pointer": wr_ptr, "overflow_counter": ovf_cnt, "read_pointer": rd_ptr}
        except OSError as exc:
            raise HardwareError("Failed to read MAX30102 FIFO pointers.") from exc

    def read_sample_reading(self) -> Max30102Reading:
        raw = self._read_fifo_frame()
        red = ((raw[0] << 16) | (raw[1] << 8) | raw[2]) & 0x03FFFF
        ir = ((raw[3] << 16) | (raw[4] << 8) | raw[5]) & 0x03FFFF
        self._last_sample = Max30102Reading(red=red, ir=ir, finger_detected=ir >= self.FINGER_THRESHOLD)
        return self._last_sample

    def read_sample(self) -> dict[str, int]:
        reading = self.read_sample_reading()
        return {"red": reading.red, "ir": reading.ir}


    def finger_detected(self) -> bool:
        if self._last_sample.ir == 0:
            self.read_sample()
        return self._last_sample.ir >= self.FINGER_THRESHOLD

    def close(self) -> None:
        if self._smbus is not None:
            try:
                self._write_u8(self.REG_MODE_CONFIG, 0x80)
            except Exception as exc:
                LOGGER.warning("Failed to reset MAX30102 on close: %s", exc)

    def _read_fifo_frame(self) -> list[int]:
        if self._smbus is None:
            raise HardwareError("MAX30102 I2C bus unavailable.")
        try:
            return self._smbus.read_i2c_block_data(self.ADDRESS, self.REG_FIFO_DATA, 6)
        except OSError as exc:
            raise HardwareError("MAX30102 FIFO read failed.") from exc

    def _read_u8(self, register: int) -> int:
        if self._smbus is None:
            raise HardwareError("MAX30102 I2C bus unavailable.")
        try:
            return self._smbus.read_byte_data(self.ADDRESS, register)
        except OSError as exc:
            raise HardwareError(f"MAX30102 read failed at register 0x{register:02X}.") from exc

    def _write_u8(self, register: int, value: int) -> None:
        if self._smbus is None:
            raise HardwareError("MAX30102 I2C bus unavailable.")
        try:
            self._smbus.write_byte_data(self.ADDRESS, register, value & 0xFF)
        except OSError as exc:
            raise HardwareError(f"MAX30102 write failed at register 0x{register:02X}.") from exc


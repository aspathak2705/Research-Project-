from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import Sequence

from hardware.i2c_bus import I2CSharedBus
from utils.exceptions import HardwareError

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class Max30102Reading:
    red: int
    ir: int
    finger_detected: bool
    overflow_count: int = 0
    fresh: bool = True
    timestamp: float = 0.0


class MAX30102Sensor:
    ADDRESS = 0x57
    REG_INTR_STATUS_1 = 0x00
    REG_INTR_STATUS_2 = 0x01
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

    DEFAULT_FINGER_THRESHOLD = 15_000

    def __init__(
        self,
        shared_bus: I2CSharedBus | None = None,
        finger_threshold: int = DEFAULT_FINGER_THRESHOLD,
    ) -> None:
        self.shared_bus = shared_bus
        self._smbus = None if shared_bus is None else shared_bus.smbus_bus
        self.finger_threshold = finger_threshold
        self._last_sample = Max30102Reading(
            red=0,
            ir=0,
            finger_detected=False,
            overflow_count=0,
            fresh=False,
            timestamp=0.0,
        )
        self._total_overflows = 0

    def initialize(self) -> None:
        if self._smbus is None:
            raise HardwareError("MAX30102 requires shared smbus2 object.")

        part_id = self._read_u8(self.REG_PART_ID)
        if part_id != 0x15:
            LOGGER.warning("MAX30102 Part ID read 0x%02X (expected 0x15). Proceeding with register setup.", part_id)

        # 1. Reset device
        self._write_u8(self.REG_MODE_CONFIG, 0x40)
        time.sleep(0.05)

        # 2. Configure interrupts (A_FULL_EN, PPG_RDY_EN)
        self._write_u8(self.REG_INTR_ENABLE_1, 0xC0)
        self._write_u8(self.REG_INTR_ENABLE_2, 0x00)

        # 3. Reset FIFO pointers & overflow counter
        self._write_u8(self.REG_FIFO_WR_PTR, 0x00)
        self._write_u8(self.REG_OVF_COUNTER, 0x00)
        self._write_u8(self.REG_FIFO_RD_PTR, 0x00)

        # 4. FIFO configuration:
        # SMP_AVE = 000 (1 sample), FIFO_ROLLOVER_EN = 0, FIFO_A_FULL = 15 (0x0F)
        self._write_u8(self.REG_FIFO_CONFIG, 0x0F)

        # 5. Operating mode: SpO2 mode (Red + IR)
        self._write_u8(self.REG_MODE_CONFIG, 0x03)

        # 6. SpO2 configuration:
        # ADC range: 4096nA (0x20), Sample rate: 100 Hz (0x04), LED pulse width: 411us / 18-bit (0x03) -> 0x27
        self._write_u8(self.REG_SPO2_CONFIG, 0x27)

        # 7. LED currents (typical ~7.2mA for finger PPG)
        self._write_u8(self.REG_LED1_PA, 0x24)
        self._write_u8(self.REG_LED2_PA, 0x24)

        # 8. Multi-LED slots (Slot 1: LED1/Red, Slot 2: LED2/IR)
        self._write_u8(self.REG_MULTI_LED_CTRL1, 0x21)
        self._write_u8(self.REG_MULTI_LED_CTRL2, 0x00)

        # 9. Clear any pending interrupt flags
        self._read_u8(self.REG_INTR_STATUS_1)
        self._read_u8(self.REG_INTR_STATUS_2)

        LOGGER.info("MAX30102 initialized at 0x57 in SpO2 mode.")

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

    def available_samples(self) -> int:
        ptrs = self.get_fifo_pointers()
        wr = ptrs["write_pointer"]
        rd = ptrs["read_pointer"]
        return (wr - rd) & 0x1F

    def read_sample_reading(self, timeout_sec: float = 0.5) -> Max30102Reading:
        if self._smbus is None:
            raise HardwareError("MAX30102 I2C bus unavailable.")

        start_time = time.monotonic()
        while True:
            ptrs = self.get_fifo_pointers()
            wr = ptrs["write_pointer"]
            rd = ptrs["read_pointer"]
            ovf = ptrs["overflow_counter"]

            num_available = (wr - rd) & 0x1F
            if num_available > 0:
                raw = self._read_fifo_frame()
                red = ((raw[0] << 16) | (raw[1] << 8) | raw[2]) & 0x03FFFF
                ir = ((raw[3] << 16) | (raw[4] << 8) | raw[5]) & 0x03FFFF
                ts = time.time()
                is_finger = ir >= self.finger_threshold

                if ovf > 0:
                    self._total_overflows += ovf
                    try:
                        self._write_u8(self.REG_OVF_COUNTER, 0x00)
                    except Exception:
                        pass

                self._last_sample = Max30102Reading(
                    red=red,
                    ir=ir,
                    finger_detected=is_finger,
                    overflow_count=ovf,
                    fresh=True,
                    timestamp=ts,
                )
                return self._last_sample

            if ovf > 0:
                # FIFO is completely full/overflowed, RD == WR
                self._total_overflows += ovf
                raw = self._read_fifo_frame()
                red = ((raw[0] << 16) | (raw[1] << 8) | raw[2]) & 0x03FFFF
                ir = ((raw[3] << 16) | (raw[4] << 8) | raw[5]) & 0x03FFFF
                ts = time.time()
                is_finger = ir >= self.finger_threshold
                try:
                    self._write_u8(self.REG_OVF_COUNTER, 0x00)
                except Exception:
                    pass

                self._last_sample = Max30102Reading(
                    red=red,
                    ir=ir,
                    finger_detected=is_finger,
                    overflow_count=ovf,
                    fresh=True,
                    timestamp=ts,
                )
                return self._last_sample

            if (time.monotonic() - start_time) >= timeout_sec:
                LOGGER.warning("MAX30102 FIFO read timeout: no fresh sample available within %ss.", timeout_sec)
                # Mark previous sample as stale
                self._last_sample = Max30102Reading(
                    red=self._last_sample.red,
                    ir=self._last_sample.ir,
                    finger_detected=self._last_sample.finger_detected,
                    overflow_count=0,
                    fresh=False,
                    timestamp=self._last_sample.timestamp,
                )
                return self._last_sample

            time.sleep(0.005)

    def read_batch_samples(self, max_samples: int = 32) -> list[Max30102Reading]:
        ptrs = self.get_fifo_pointers()
        wr = ptrs["write_pointer"]
        rd = ptrs["read_pointer"]
        ovf = ptrs["overflow_counter"]

        count = (wr - rd) & 0x1F
        if count == 0 and ovf > 0:
            count = 32

        to_read = min(count, max_samples)
        readings: list[Max30102Reading] = []

        for _ in range(to_read):
            raw = self._read_fifo_frame()
            red = ((raw[0] << 16) | (raw[1] << 8) | raw[2]) & 0x03FFFF
            ir = ((raw[3] << 16) | (raw[4] << 8) | raw[5]) & 0x03FFFF
            reading = Max30102Reading(
                red=red,
                ir=ir,
                finger_detected=ir >= self.finger_threshold,
                overflow_count=ovf,
                fresh=True,
                timestamp=time.time(),
            )
            readings.append(reading)
            self._last_sample = reading

        if ovf > 0:
            self._total_overflows += ovf
            try:
                self._write_u8(self.REG_OVF_COUNTER, 0x00)
            except Exception:
                pass

        return readings

    def read_sample(self) -> dict[str, int]:
        reading = self.read_sample_reading()
        return {
            "red": reading.red,
            "ir": reading.ir,
            "overflow_counter": reading.overflow_count,
            "fresh": 1 if reading.fresh else 0,
        }

    def finger_detected(self) -> bool:
        if self._last_sample.ir == 0:
            self.read_sample_reading(timeout_sec=0.1)
        return self._last_sample.ir >= self.finger_threshold

    def close(self) -> None:
        if self._smbus is not None:
            try:
                # Put MAX30102 into shutdown power-save mode (SHDN bit 7 of MODE_CONFIG)
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

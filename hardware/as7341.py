from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import Any

from hardware.i2c_bus import I2CSharedBus
from utils.exceptions import HardwareError

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class AS7341Reading:
    channels: dict[str, int]
    saturated: bool
    measurement_complete: bool = True
    smux_complete: bool = True


class AS7341Sensor:
    ADDRESS = 0x39
    ENABLE = 0x80
    ATIME = 0x81
    ASTEP_L = 0xCA
    ASTEP_H = 0xCB
    CFG0 = 0xA9
    CFG1 = 0xAA
    CFG6 = 0xAF
    STATUS2 = 0xA3
    STATUS5 = 0xA6
    STATUS = 0x93
    ASTATUS = 0x94
    AUXID = 0x90
    REVID = 0x91
    ID = 0x92
    SMUX_CMD = 0xAF
    CH0_DATA_L = 0x95

    GAIN_MAP = {
        0.5: 0,
        1: 1,
        2: 2,
        4: 3,
        8: 4,
        16: 5,
        32: 6,
        64: 7,
        128: 8,
        256: 9,
        512: 10,
    }

    CHANNEL_KEYS = ("415", "445", "480", "515", "555", "590", "630", "680")

    # Authoritative 20-byte SMUX RAM mappings (addresses 0x00 through 0x13) preserved
    _SMUX_BANK_1 = {
        0x00: 0x30, 0x01: 0x01, 0x02: 0x00, 0x03: 0x00, 0x04: 0x00,
        0x05: 0x42, 0x06: 0x00, 0x07: 0x00, 0x08: 0x50, 0x09: 0x00,
        0x0A: 0x00, 0x0B: 0x00, 0x0C: 0x20, 0x0D: 0x04, 0x0E: 0x00,
        0x0F: 0x30, 0x10: 0x01, 0x11: 0x50, 0x12: 0x00, 0x13: 0x06,
    }

    _SMUX_BANK_2 = {
        0x00: 0x00, 0x01: 0x00, 0x02: 0x00, 0x03: 0x40, 0x04: 0x02,
        0x05: 0x00, 0x06: 0x10, 0x07: 0x03, 0x08: 0x50, 0x09: 0x10,
        0x0A: 0x03, 0x0B: 0x00, 0x0C: 0x00, 0x0D: 0x00, 0x0E: 0x24,
        0x0F: 0x00, 0x10: 0x00, 0x11: 0x50, 0x12: 0x00, 0x13: 0x06,
    }

    def __init__(
        self,
        shared_bus: I2CSharedBus | None = None,
        integration_time_ms: float = 200.0,
        gain: int = 128,
    ) -> None:
        self.shared_bus = shared_bus
        self.integration_time_ms = integration_time_ms
        self.gain = gain
        self._driver: Any = None
        self._smbus = None if shared_bus is None else shared_bus.smbus_bus
        self._last_smux_complete = True
        self._last_avalid = True
        self._last_status5 = 0x00

        assert set(self._SMUX_BANK_1.keys()) == set(range(0x14)), "Bank 1 SMUX configuration incomplete"
        assert set(self._SMUX_BANK_2.keys()) == set(range(0x14)), "Bank 2 SMUX configuration incomplete"

    def initialize(self) -> None:
        if self.shared_bus is not None and self.shared_bus.busio_bus is not None:
            try:
                import adafruit_as7341
                self._driver = adafruit_as7341.AS7341(self.shared_bus.busio_bus)
                self.set_integration_time(self.integration_time_ms)
                self.set_gain(self.gain)
                LOGGER.info("AS7341 initialized via adafruit_as7341 at 0x39.")
                return
            except Exception as exc:
                LOGGER.warning("adafruit_as7341 initialization via busio failed (%s), falling back to smbus.", exc)

        if self._smbus is None:
            raise HardwareError("AS7341 requires shared bus (busio or smbus2).")

        self._write_u8(self.ENABLE, 0x01)
        time.sleep(0.01)
        self._write_u8(self.ENABLE, 0x03)
        self.set_integration_time(self.integration_time_ms)
        self.set_gain(self.gain)
        LOGGER.info("AS7341 initialized at 0x39 via smbus.")

    def set_integration_time(self, integration_time_ms: float) -> None:
        self.integration_time_ms = integration_time_ms
        if integration_time_ms <= 0:
            raise HardwareError("AS7341 integration time must be positive.")

        if self._driver is not None:
            try:
                if abs(integration_time_ms - 200.0) < 1.0:
                    self._driver.atime = 100
                    self._driver.astep = 999
                else:
                    astep = 999
                    atime = max(0, min(255, int(round((integration_time_ms * 1000.0) / (2.78 * (astep + 1)))) - 1))
                    self._driver.atime = atime
                    self._driver.astep = astep
                return
            except Exception as exc:
                raise HardwareError(f"Failed to set AS7341 integration time on Adafruit driver: {exc}") from exc

        if self._smbus is not None:
            if abs(integration_time_ms - 200.0) < 1.0:
                atime = 100
                astep = 999
            else:
                astep = 999
                atime = max(0, min(255, int(round((integration_time_ms * 1000.0) / (2.78 * (astep + 1)))) - 1))
            self._write_u8(self.ATIME, atime)
            self._write_u8(self.ASTEP_L, astep & 0xFF)
            self._write_u8(self.ASTEP_H, (astep >> 8) & 0xFF)

    def set_gain(self, gain: int) -> None:
        self.gain = gain
        reg_value = self.GAIN_MAP.get(gain)
        if reg_value is None:
            raise HardwareError(f"Unsupported AS7341 gain: {gain}")

        if self._driver is not None:
            try:
                import adafruit_as7341
                # Map gain value to adafruit_as7341.Gain enum
                gain_enum_map = {
                    0.5: adafruit_as7341.Gain.GAIN_0_5X,
                    1: adafruit_as7341.Gain.GAIN_1X,
                    2: adafruit_as7341.Gain.GAIN_2X,
                    4: adafruit_as7341.Gain.GAIN_4X,
                    8: adafruit_as7341.Gain.GAIN_8X,
                    16: adafruit_as7341.Gain.GAIN_16X,
                    32: adafruit_as7341.Gain.GAIN_32X,
                    64: adafruit_as7341.Gain.GAIN_64X,
                    128: adafruit_as7341.Gain.GAIN_128X,
                    256: adafruit_as7341.Gain.GAIN_256X,
                    512: adafruit_as7341.Gain.GAIN_512X,
                }
                self._driver.gain = gain_enum_map.get(gain, reg_value)
                return
            except Exception as exc:
                raise HardwareError(f"Failed to set AS7341 gain on Adafruit driver: {exc}") from exc

        if self._smbus is not None:
            self._write_u8(self.CFG1, reg_value)

    def read_channels(self) -> dict[str, int]:
        if self._driver is not None:
            try:
                raw_channels = self._driver.all_channels
                return {
                    "415": int(raw_channels[0]),
                    "445": int(raw_channels[1]),
                    "480": int(raw_channels[2]),
                    "515": int(raw_channels[3]),
                    "555": int(raw_channels[4]),
                    "590": int(raw_channels[5]),
                    "630": int(raw_channels[6]),
                    "680": int(raw_channels[7]),
                }
            except Exception as exc:
                raise HardwareError(f"Adafruit AS7341 read failure: {exc}") from exc

        if self._smbus is not None:
            first_bank = self._read_bank(self._SMUX_BANK_1)
            second_bank = self._read_bank(self._SMUX_BANK_2)
            return {
                "415": first_bank[0],
                "445": first_bank[1],
                "480": first_bank[2],
                "515": first_bank[3],
                "555": second_bank[0],
                "590": second_bank[1],
                "630": second_bank[2],
                "680": second_bank[3],
            }

        raise HardwareError("AS7341 driver not initialized.")

    def read_sample(self) -> AS7341Reading:
        channels = self.read_channels()
        saturated = any(value >= 0xFFF0 for value in channels.values())
        return AS7341Reading(
            channels=channels,
            saturated=saturated,
            measurement_complete=self._last_avalid,
            smux_complete=self._last_smux_complete,
        )

    def close(self) -> None:
        if self._driver is not None:
            try:
                self._driver = None
            except Exception as exc:
                LOGGER.warning("Failed to close Adafruit AS7341 driver: %s", exc)

        if self._smbus is not None:
            try:
                self._write_u8(self.ENABLE, 0x00)
            except Exception as exc:
                LOGGER.warning("Failed to reset AS7341 on close: %s", exc)

    def write_smux_ram(self, smux_config: dict[int, int]) -> None:
        if self._smbus is None:
            raise HardwareError("AS7341 I2C bus unavailable.")

        enable_val = self._read_u8(self.ENABLE)
        self._write_u8(self.ENABLE, enable_val & ~0x02)

        cfg0_val = self._read_u8(self.CFG0)
        self._write_u8(self.CFG0, cfg0_val | 0x10)

        for register, value in smux_config.items():
            self._write_u8(register, value)

        cfg0_val = self._read_u8(self.CFG0)
        self._write_u8(self.CFG0, cfg0_val & ~0x10)

    def _read_bank(self, smux_config: dict[int, int]) -> tuple[int, int, int, int, int, int]:
        if self._smbus is None:
            raise HardwareError("AS7341 I2C bus unavailable.")

        self.write_smux_ram(smux_config)
        self._write_u8(self.CFG6, 0x10)

        enable_val = self._read_u8(self.ENABLE)
        self._write_u8(self.ENABLE, (enable_val | 0x11) & ~0x02)

        self._last_smux_complete = self._wait_smux_complete()
        if not self._last_smux_complete:
            raise HardwareError("AS7341 SMUX execution timed out (SMUXEN remained 1).")

        try:
            self._last_status5 = self._read_u8(self.STATUS5)
        except Exception:
            self._last_status5 = 0x00

        enable_val = self._read_u8(self.ENABLE)
        self._write_u8(self.ENABLE, enable_val | 0x03)

        self._last_avalid = self._wait_avalid()

        try:
            raw = self._smbus.read_i2c_block_data(self.ADDRESS, self.ASTATUS, 13)
        except OSError as exc:
            raise HardwareError("AS7341 read bank failed.") from exc

        return tuple(raw[index] | (raw[index + 1] << 8) for index in range(1, 13, 2))

    def _wait_smux_complete(self, max_retries: int = 50) -> bool:
        for _ in range(max_retries):
            try:
                enable_val = self._read_u8(self.ENABLE)
                if not (enable_val & 0x10):
                    return True
            except HardwareError:
                raise
            except Exception:
                pass
            time.sleep(0.001)
        return False

    def _wait_avalid(self, timeout_sec: float = 1.0, max_retries: int | None = None) -> bool:
        if max_retries is not None:
            for _ in range(max_retries):
                try:
                    status2 = self._read_u8(self.STATUS2)
                    if status2 & 0x40:
                        return True
                except HardwareError:
                    raise
                except Exception:
                    pass
                time.sleep(0.001)
            return False

        min_integration_sec = (self.integration_time_ms / 1000.0) * 0.95
        time.sleep(min_integration_sec)

        start = time.time()
        while (time.time() - start) < (timeout_sec + 0.5):
            try:
                status2 = self._read_u8(self.STATUS2)
                if status2 & 0x40:
                    return True
            except HardwareError:
                raise
            except Exception:
                pass
            time.sleep(0.005)
        return False

    def _read_u8(self, register: int) -> int:
        if self._smbus is None:
            raise HardwareError("AS7341 I2C bus unavailable.")
        try:
            return self._smbus.read_byte_data(self.ADDRESS, register)
        except OSError as exc:
            raise HardwareError(f"AS7341 read failed at register 0x{register:02X}.") from exc

    def _write_u8(self, register: int, value: int) -> None:
        if self._smbus is None:
            raise HardwareError("AS7341 I2C bus unavailable.")
        try:
            self._write_byte_data_safe(register, value & 0xFF)
        except OSError as exc:
            raise HardwareError(f"AS7341 write failed at register 0x{register:02X}.") from exc

    def _write_byte_data_safe(self, register: int, value: int) -> None:
        self._smbus.write_byte_data(self.ADDRESS, register, value)

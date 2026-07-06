from __future__ import annotations

import logging
import time
from dataclasses import dataclass

from hardware.i2c_bus import I2CSharedBus
from utils.exceptions import HardwareError

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class AS7341Reading:
    channels: dict[str, int]
    saturated: bool


class AS7341Sensor:
    ADDRESS = 0x39
    ENABLE = 0x80
    ATIME = 0x81
    ASTEP_L = 0xCA
    ASTEP_H = 0xCB
    CFG0 = 0xA9
    CFG1 = 0xAA
    STATUS2 = 0xA3
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

    def __init__(
        self,
        shared_bus: I2CSharedBus | None = None,
        mock_mode: bool = True,
        integration_time_ms: float = 50.0,
        gain: int = 16,
    ) -> None:
        self.mock_mode = mock_mode
        self.shared_bus = shared_bus
        self.integration_time_ms = integration_time_ms
        self.gain = gain
        self._smbus = None if shared_bus is None else shared_bus.smbus_bus
        self._sample_index = 0

    def initialize(self) -> None:
        if self.mock_mode:
            LOGGER.info("AS7341 mock mode enabled.")
            return

        if self._smbus is None:
            raise HardwareError("AS7341 requires shared smbus2 object.")

        self._write_u8(self.ENABLE, 0x01)
        time.sleep(0.01)
        self._write_u8(self.ENABLE, 0x03)
        self.set_integration_time(self.integration_time_ms)
        self.set_gain(self.gain)
        LOGGER.info("AS7341 initialized at 0x39.")

    def set_integration_time(self, integration_time_ms: float) -> None:
        self.integration_time_ms = integration_time_ms
        if self.mock_mode:
            return

        if integration_time_ms <= 0:
            raise HardwareError("AS7341 integration time must be positive.")

        atime = max(0, min(255, int(integration_time_ms / 2.78) - 1))
        astep = max(1, min(65534, int((integration_time_ms * 1000) / (2.78 * (atime + 1))) - 1))
        self._write_u8(self.ATIME, atime)
        self._write_u8(self.ASTEP_L, astep & 0xFF)
        self._write_u8(self.ASTEP_H, (astep >> 8) & 0xFF)

    def set_gain(self, gain: int) -> None:
        self.gain = gain
        if self.mock_mode:
            return

        reg_value = self.GAIN_MAP.get(gain)
        if reg_value is None:
            raise HardwareError(f"Unsupported AS7341 gain: {gain}")
        self._write_u8(self.CFG1, reg_value)

    def read_channels(self) -> dict[str, int]:
        if self.mock_mode:
            channels = self._mock_channels()
            print(channels)
            return channels

        first_bank = self._read_bank(self._smux_config_f1_f4_clear_nir())
        second_bank = self._read_bank(self._smux_config_f5_f8_clear_nir())
        channels = {
            "415": first_bank[0],
            "445": first_bank[1],
            "480": first_bank[2],
            "515": first_bank[3],
            "555": second_bank[0],
            "590": second_bank[1],
            "630": second_bank[2],
            "680": second_bank[3],
        }
        print(channels)
        return channels

    def read_sample(self) -> AS7341Reading:
        channels = self.read_channels()
        saturated = any(value >= 0xFFF0 for value in channels.values())
        return AS7341Reading(channels=channels, saturated=saturated)

    def close(self) -> None:
        if not self.mock_mode and self._smbus is not None:
            self._write_u8(self.ENABLE, 0x00)

    def _read_bank(self, smux_config: dict[int, int]) -> tuple[int, int, int, int, int, int]:
        self._write_u8(self.ENABLE, 0x01)
        self._write_u8(self.CFG0, 0x10)
        for register, value in smux_config.items():
            self._write_u8(register, value)
        self._write_u8(self.SMUX_CMD, 0x10)
        self._write_u8(self.ENABLE, 0x13)
        time.sleep(max(self.integration_time_ms / 1000.0, 0.05))
        raw = self._smbus.read_i2c_block_data(self.ADDRESS, self.CH0_DATA_L, 12)
        return tuple(raw[index] | (raw[index + 1] << 8) for index in range(0, 12, 2))

    def _write_u8(self, register: int, value: int) -> None:
        try:
            self._smbus.write_byte_data(self.ADDRESS, register, value & 0xFF)
        except OSError as exc:
            raise HardwareError(f"AS7341 write failed at register 0x{register:02X}.") from exc

    def _mock_channels(self) -> dict[str, int]:
        self._sample_index += 1
        base = 12000 + (self._sample_index % 5) * 125
        return {
            "415": base + 10,
            "445": base + 55,
            "480": base + 95,
            "515": base + 135,
            "555": base + 175,
            "590": base + 215,
            "630": base + 255,
            "680": base + 295,
        }

    @staticmethod
    def _smux_config_f1_f4_clear_nir() -> dict[int, int]:
        return {
            0x00: 0x30,
            0x01: 0x01,
            0x02: 0x00,
            0x03: 0x00,
            0x04: 0x00,
            0x05: 0x42,
            0x06: 0x00,
            0x07: 0x00,
            0x08: 0x50,
            0x09: 0x00,
            0x0A: 0x00,
            0x0B: 0x39,
            0x0C: 0x00,
            0x0D: 0x00,
            0x0E: 0x24,
            0x0F: 0x00,
            0x10: 0x00,
            0x11: 0x00,
            0x12: 0x00,
        }

    @staticmethod
    def _smux_config_f5_f8_clear_nir() -> dict[int, int]:
        return {
            0x00: 0x00,
            0x01: 0x00,
            0x02: 0x00,
            0x03: 0x40,
            0x04: 0x02,
            0x05: 0x00,
            0x06: 0x10,
            0x07: 0x03,
            0x08: 0x50,
            0x09: 0x00,
            0x0A: 0x00,
            0x0B: 0x39,
            0x0C: 0x00,
            0x0D: 0x00,
            0x0E: 0x24,
            0x0F: 0x00,
            0x10: 0x00,
            0x11: 0x00,
            0x12: 0x00,
        }

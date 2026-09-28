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
    measurement_complete: bool = True
    smux_complete: bool = True


class AS7341Sensor:
    ADDRESS = 0x39
    ENABLE = 0x80
    ATIME = 0x81
    ASTEP_L = 0xCA
    ASTEP_H = 0xCB
    CFG0 = 0xA9  # Bit 4: REG_BANK (set to 1 to access SMUX RAM registers at 0x00..0x13)
    CFG1 = 0xAA  # Gain control
    CFG6 = 0xAF  # Bits [4:3]: SMUX_CMD (write 0x10 to execute SMUX RAM config)
    STATUS2 = 0xA3  # Bit 6: AVALID (spectral integration complete)
    STATUS5 = 0xA6  # Bit 2: SINT_SMUX (SMUX calculation complete)
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

    # Authoritative 20-byte SMUX RAM mappings (addresses 0x00 through 0x13)
    # Bank 1: F1 (415nm)->CH0, F2 (445nm)->CH1, F3 (480nm)->CH2, F4 (515nm)->CH3, Clear->CH4, NIR->CH5
    _SMUX_BANK_1 = {
        0x00: 0x30,  # CH0 left connected to F1 (PD1)
        0x01: 0x01,  # CH0 right connected to F1 (PD1)
        0x02: 0x00,  # CH1 left not connected
        0x03: 0x00,  # CH1 right not connected
        0x04: 0x00,  # CH2 left not connected
        0x05: 0x42,  # CH1 left connected to F2 (PD2) / CH2 right connected to F2
        0x06: 0x00,  # CH3 left not connected
        0x07: 0x00,  # CH3 right not connected
        0x08: 0x50,  # CH2 left connected to F3 (PD3)
        0x09: 0x00,  # CH4 left not connected
        0x0A: 0x00,  # CH4 right not connected
        0x0B: 0x39,  # CH3 connected to F4 (PD4)
        0x0C: 0x00,  # CH5 left not connected
        0x0D: 0x00,  # CH5 right not connected
        0x0E: 0x24,  # CH4 connected to Clear (PD_CLEAR)
        0x0F: 0x00,  # Reserved/NC
        0x10: 0x00,  # Reserved/NC
        0x11: 0x00,  # CH5 left connected to NIR
        0x12: 0x00,  # CH5 right connected to NIR
        0x13: 0x00,  # SMUX position 19 termination
    }

    # Bank 2: F5 (555nm)->CH0, F6 (590nm)->CH1, F7 (630nm)->CH2, F8 (680nm)->CH3, Clear->CH4, NIR->CH5
    _SMUX_BANK_2 = {
        0x00: 0x00,  # CH0 left not connected to F1
        0x01: 0x00,  # CH0 right not connected to F1
        0x02: 0x00,  # CH1 left not connected
        0x03: 0x40,  # CH0 connected to F5 (PD5)
        0x04: 0x02,  # CH0 connected to F5 (PD5)
        0x05: 0x00,  # CH1 left not connected to F2
        0x06: 0x10,  # CH1 connected to F6 (PD6)
        0x07: 0x03,  # CH1 connected to F6 (PD6)
        0x08: 0x50,  # CH2 connected to F7 (PD7)
        0x09: 0x00,  # CH4 left not connected
        0x0A: 0x00,  # CH4 right not connected
        0x0B: 0x39,  # CH3 connected to F8 (PD8)
        0x0C: 0x00,  # CH5 left not connected
        0x0D: 0x00,  # CH5 right not connected
        0x0E: 0x24,  # CH4 connected to Clear (PD_CLEAR)
        0x0F: 0x00,  # Reserved/NC
        0x10: 0x00,  # Reserved/NC
        0x11: 0x00,  # CH5 left connected to NIR
        0x12: 0x00,  # CH5 right connected to NIR
        0x13: 0x00,  # SMUX position 19 termination
    }

    def __init__(
        self,
        shared_bus: I2CSharedBus | None = None,
        integration_time_ms: float = 50.0,
        gain: int = 16,
    ) -> None:
        self.shared_bus = shared_bus
        self.integration_time_ms = integration_time_ms
        self.gain = gain
        self._smbus = None if shared_bus is None else shared_bus.smbus_bus
        self._last_smux_complete = True
        self._last_avalid = True
        self._last_status5 = 0x00

        # Class invariant validation
        assert set(self._SMUX_BANK_1.keys()) == set(range(0x14)), "Bank 1 SMUX configuration incomplete"
        assert set(self._SMUX_BANK_2.keys()) == set(range(0x14)), "Bank 2 SMUX configuration incomplete"

    def initialize(self) -> None:
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

        if integration_time_ms <= 0:
            raise HardwareError("AS7341 integration time must be positive.")

        # AS7341 Datasheet formula: t_int = (ATIME + 1) * (ASTEP + 1) * 2.78 µs
        atime = max(0, min(255, int(integration_time_ms / 2.78) - 1))
        astep = max(1, min(65534, int((integration_time_ms * 1000) / (2.78 * (atime + 1))) - 1))
        self._write_u8(self.ATIME, atime)
        self._write_u8(self.ASTEP_L, astep & 0xFF)
        self._write_u8(self.ASTEP_H, (astep >> 8) & 0xFF)

    def set_gain(self, gain: int) -> None:
        self.gain = gain
        reg_value = self.GAIN_MAP.get(gain)
        if reg_value is None:
            raise HardwareError(f"Unsupported AS7341 gain: {gain}")
        self._write_u8(self.CFG1, reg_value)

    def read_channels(self) -> dict[str, int]:
        first_bank = self._read_bank(self._SMUX_BANK_1)
        second_bank = self._read_bank(self._SMUX_BANK_2)
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
        return channels

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
        if self._smbus is not None:
            try:
                self._write_u8(self.ENABLE, 0x00)
            except Exception as exc:
                LOGGER.warning("Failed to reset AS7341 on close: %s", exc)

    def write_smux_ram(self, smux_config: dict[int, int], verify_readback: bool = True) -> tuple[bool, dict[int, tuple[int, int]]]:
        """
        Write 20-byte SMUX RAM configuration with optional readback verification.
        Returns (success, mismatches_dict) where mismatches_dict maps addr -> (expected, actual).
        """
        if self._smbus is None:
            raise HardwareError("AS7341 I2C bus unavailable.")

        # 1. Disable spectral measurement before SMUX RAM access
        enable_val = self._read_u8(self.ENABLE)
        self._write_u8(self.ENABLE, enable_val & ~0x02)  # Clear SP_EN (bit 1)

        # 2. Enable SMUX RAM access via CFG0 (bit 4: REG_BANK = 1) using read-modify-write
        cfg0_val = self._read_u8(self.CFG0)
        self._write_u8(self.CFG0, cfg0_val | 0x10)

        # 3. Write all 20 SMUX RAM configuration registers (0x00..0x13)
        for register, value in smux_config.items():
            self._write_u8(register, value)

        mismatches: dict[int, tuple[int, int]] = {}
        if verify_readback:
            for register, expected in smux_config.items():
                actual = self._read_u8(register)
                if actual != expected:
                    mismatches[register] = (expected, actual)

        return (len(mismatches) == 0, mismatches)

    def _read_bank(self, smux_config: dict[int, int]) -> tuple[int, int, int, int, int, int]:
        if self._smbus is None:
            raise HardwareError("AS7341 I2C bus unavailable.")

        # Write SMUX RAM configuration with readback verification
        success, mismatches = self.write_smux_ram(smux_config, verify_readback=True)
        if not success:
            raise HardwareError(f"AS7341 SMUX RAM readback mismatch: {mismatches}")

        # 4. Execute SMUX command: Write CFG6 (0xAF) bits [4:3] = 0x10 (Execute SMUX)
        self._write_u8(self.CFG6, 0x10)

        # 5. Enable SMUX calculation engine: set SMUXEN (bit 4) and PON (bit 0)
        enable_val = self._read_u8(self.ENABLE)
        self._write_u8(self.ENABLE, (enable_val | 0x11) & ~0x02)

        # 6. Wait / poll SMUX completion: ENABLE bit 4 (SMUXEN) clearing to 0
        self._last_smux_complete = self._wait_smux_complete()
        if not self._last_smux_complete:
            raise HardwareError("AS7341 SMUX execution timed out (SMUXEN remained 1).")

        # Capture diagnostic STATUS5 / SINT_SMUX state
        try:
            self._last_status5 = self._read_u8(self.STATUS5)
        except Exception:
            self._last_status5 = 0x00

        # 7. Restore normal register bank access: clear CFG0 bit 4 (REG_BANK = 0)
        cfg0_val = self._read_u8(self.CFG0)
        self._write_u8(self.CFG0, cfg0_val & ~0x10)

        # 8. Re-enable spectral measurement: set SP_EN (bit 1) and PON (bit 0)
        enable_val = self._read_u8(self.ENABLE)
        self._write_u8(self.ENABLE, enable_val | 0x03)

        # 9. Wait / poll AVALID bit (STATUS2 bit 6) for spectral integration completion
        self._last_avalid = self._wait_avalid()

        try:
            raw = self._smbus.read_i2c_block_data(self.ADDRESS, self.CH0_DATA_L, 12)
        except OSError as exc:
            raise HardwareError("AS7341 read bank failed.") from exc
        return tuple(raw[index] | (raw[index + 1] << 8) for index in range(0, 12, 2))

    def _wait_smux_complete(self, max_retries: int = 50) -> bool:
        """
        Polls ENABLE register bit 4 (SMUXEN) until it automatically clears to 0 upon SMUX completion.
        Preserves strict timeout and propagates hardware I2C errors.
        """
        for _ in range(max_retries):
            try:
                enable_val = self._read_u8(self.ENABLE)
                if not (enable_val & 0x10):  # Bit 4 (SMUXEN) cleared to 0
                    return True
            except HardwareError:
                raise
            except Exception:
                pass
            time.sleep(0.001)
        return False

    def _wait_avalid(self, max_retries: int = 30) -> bool:
        sleep_interval = max(self.integration_time_ms / 1000.0 / 5.0, 0.005)
        for _ in range(max_retries):
            try:
                status2 = self._read_u8(self.STATUS2)
                if status2 & 0x40:  # AVALID bit 6
                    return True
            except HardwareError:
                raise
            except Exception:
                pass
            time.sleep(sleep_interval)
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


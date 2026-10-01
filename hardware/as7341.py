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
        0x00: 0x30,  # NC_F3L: OUT2 = ADC2 (F3L -> ADC2)
        0x01: 0x01,  # F1L_NC: OUT1 = ADC0 (F1L -> ADC0)
        0x02: 0x00,  # NC_NC0
        0x03: 0x00,  # NC_F8L
        0x04: 0x00,  # F6L_NC
        0x05: 0x42,  # F2L_F4L: OUT1 = ADC1, OUT2 = ADC3 (F2L -> ADC1, F4L -> ADC3)
        0x06: 0x00,  # NC_F5L
        0x07: 0x00,  # F7L_NC
        0x08: 0x50,  # NC_CL: OUT2 = ADC4 (Clear Left -> ADC4)
        0x09: 0x00,  # NC_F5R
        0x0A: 0x00,  # F7R_NC
        0x0B: 0x00,  # NC_NC1
        0x0C: 0x20,  # NC_F2R: OUT2 = ADC1 (F2R -> ADC1)
        0x0D: 0x04,  # F4R_NC: OUT1 = ADC3 (F4R -> ADC3)
        0x0E: 0x00,  # F8R_F6R
        0x0F: 0x30,  # NC_F3R: OUT2 = ADC2 (F3R -> ADC2)
        0x10: 0x01,  # F1R_EXT_GPIO: OUT1 = ADC0 (F1R -> ADC0)
        0x11: 0x50,  # EXT_INT_CR: OUT2 = ADC4 (Clear Right -> ADC4)
        0x12: 0x00,  # NC_DARK
        0x13: 0x06,  # NIR_F: OUT1 = ADC5 (NIR -> ADC5)
    }

    # Bank 2: F5 (555nm)->CH0, F6 (590nm)->CH1, F7 (630nm)->CH2, F8 (680nm)->CH3, Clear->CH4, NIR->CH5
    _SMUX_BANK_2 = {
        0x00: 0x00,  # NC_F3L
        0x01: 0x00,  # F1L_NC
        0x02: 0x00,  # NC_NC0
        0x03: 0x40,  # NC_F8L: OUT2 = ADC3 (F8L -> ADC3)
        0x04: 0x02,  # F6L_NC: OUT1 = ADC1 (F6L -> ADC1)
        0x05: 0x00,  # F2L_F4L
        0x06: 0x10,  # NC_F5L: OUT2 = ADC0 (F5L -> ADC0)
        0x07: 0x03,  # F7L_NC: OUT1 = ADC2 (F7L -> ADC2)
        0x08: 0x50,  # NC_CL: OUT2 = ADC4 (Clear Left -> ADC4)
        0x09: 0x10,  # NC_F5R: OUT2 = ADC0 (F5R -> ADC0)
        0x0A: 0x03,  # F7R_NC: OUT1 = ADC2 (F7R -> ADC2)
        0x0B: 0x00,  # NC_NC1
        0x0C: 0x00,  # NC_F2R
        0x0D: 0x00,  # F4R_NC
        0x0E: 0x24,  # F8R_F6R: OUT1 = ADC3, OUT2 = ADC1 (F8R -> ADC3, F6R -> ADC1)
        0x0F: 0x00,  # NC_F3R
        0x10: 0x00,  # F1R_EXT_GPIO
        0x11: 0x50,  # EXT_INT_CR: OUT2 = ADC4 (Clear Right -> ADC4)
        0x12: 0x00,  # NC_DARK
        0x13: 0x06,  # NIR_F: OUT1 = ADC5 (NIR -> ADC5)
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

        # If exactly 200 ms (or close to 200ms baseline), match Adafruit v1.2.27 baseline:
        # ATIME = 100 (0x64), ASTEP = 999 (0x03E7) -> (100+1)*(999+1)*2.78µs = 280.78ms (historical 200ms baseline)
        if abs(integration_time_ms - 200.0) < 1.0:
            atime = 100
            astep = 999
        else:
            # Formula: t_int = (ATIME + 1) * (ASTEP + 1) * 2.78 µs with default ASTEP = 999
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

    def write_smux_ram(self, smux_config: dict[int, int]) -> None:
        """
        Write 20-byte SMUX RAM configuration registers (0x00..0x13).
        Enables SMUX RAM access via CFG0 (REG_BANK = 1), writes all 20 bytes,
        and restores normal register bank access (REG_BANK = 0).
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

        # 4. Restore normal register bank access: clear CFG0 bit 4 (REG_BANK = 0)
        # MUST be cleared before accessing CFG6 (0xAF) and ENABLE (0x80)
        cfg0_val = self._read_u8(self.CFG0)
        self._write_u8(self.CFG0, cfg0_val & ~0x10)

    def _read_bank(self, smux_config: dict[int, int]) -> tuple[int, int, int, int, int, int]:
        if self._smbus is None:
            raise HardwareError("AS7341 I2C bus unavailable.")

        # 1-4. Write SMUX RAM configuration and restore REG_BANK = 0
        self.write_smux_ram(smux_config)

        # 5. Execute SMUX command: Write CFG6 (0xAF) bits [4:3] = 0x10 (Execute SMUX: write RAM to SMUX chain)
        self._write_u8(self.CFG6, 0x10)

        # 6. Enable SMUX calculation engine: set SMUXEN (bit 4) and PON (bit 0)
        enable_val = self._read_u8(self.ENABLE)
        self._write_u8(self.ENABLE, (enable_val | 0x11) & ~0x02)

        # 7. Wait / poll SMUX completion: ENABLE bit 4 (SMUXEN) clearing to 0
        self._last_smux_complete = self._wait_smux_complete()
        if not self._last_smux_complete:
            raise HardwareError("AS7341 SMUX execution timed out (SMUXEN remained 1).")

        # Capture diagnostic STATUS5 / SINT_SMUX state
        try:
            self._last_status5 = self._read_u8(self.STATUS5)
        except Exception:
            self._last_status5 = 0x00

        # 8. Start a fresh spectral integration cycle: set SP_EN (bit 1) and PON (bit 0)
        enable_val = self._read_u8(self.ENABLE)
        self._write_u8(self.ENABLE, enable_val | 0x03)

        # 9. Wait for fresh AVALID bit (STATUS2 bit 6) to signal integration completion
        self._last_avalid = self._wait_avalid()

        # 10. Read 13 contiguous bytes starting from ASTATUS (0x94)
        # Per ams OSRAM AS7341 datasheet: Reading ASTATUS (0x94) latches all 12 spectral data bytes (0x95..0xA0)
        try:
            raw = self._smbus.read_i2c_block_data(self.ADDRESS, self.ASTATUS, 13)
        except OSError as exc:
            raise HardwareError("AS7341 read bank failed.") from exc

        # raw[0] is ASTATUS; raw[1:13] are 6 16-bit little-endian channels (CH0..CH5)
        return tuple(raw[index] | (raw[index + 1] << 8) for index in range(1, 13, 2))

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

    def _wait_avalid(self, timeout_sec: float = 1.0, max_retries: int | None = None) -> bool:
        """
        Waits for a fresh spectral measurement cycle to complete by polling STATUS2 bit 6 (AVALID).
        Initial wait guarantees measurement engine has entered the new integration cycle.
        """
        if max_retries is not None:
            # Fallback fast-poll loop for unit tests
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

        # Minimum wait for integration to begin: integration_time_ms is at least 200ms
        min_integration_sec = (self.integration_time_ms / 1000.0) * 0.95
        time.sleep(min_integration_sec)

        start = time.time()
        while (time.time() - start) < (timeout_sec + 0.5):
            try:
                status2 = self._read_u8(self.STATUS2)
                if status2 & 0x40:  # AVALID bit 6
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


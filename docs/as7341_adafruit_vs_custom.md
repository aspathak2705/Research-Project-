# AS7341 Implementation Comparison: Adafruit CircuitPython vs Custom Driver

## Overview

Forensic comparison between the historical Adafruit CircuitPython AS7341 library (`adafruit_as7341`) and the current HemoPi custom driver (`hardware/as7341.py`).

---

## Detailed Register & Behavior Matrix

| Register / Feature | Adafruit AS7341 Behavior | Current Custom Driver Behavior | Key Difference | Risk & Impact |
| :--- | :--- | :--- | :--- | :--- |
| **ENABLE (0x80)** | Uses `RWBit(0x80, 4)` for `SMUXEN`. Sets `SMUXEN=True`, polls `while self._smux_enable_bit is True: sleep(0.001)`. Toggles `SP_EN` (bit 1) via `_color_meas_enabled`. | Read-modify-write on `0x80`. Sets `(enable \| 0x11) & ~0x02` for SMUX. Polls `ENABLE` bit 4 until `0`. Sets `enable \| 0x03` for integration. | Same register & bit logic. Both rely on `SMUXEN` auto-clearing to `0`. | LOW. Completion mechanism matches. |
| **CFG0 (0xA9)** | Defines `_low_bank_active = RWBit(0xA9, 4)`. Decorated functions toggle bit 4. Decorator automatically clears bit 4 on exit. Does not read back or compare SMUX RAM. | Reads CFG0, performs `cfg0 \| 0x10`, writes 20 SMUX bytes, reads 20 SMUX bytes, compares. Clears `cfg0 & ~0x10`. Raises `HardwareError` if readback does not match written table. | **CRITICAL**: Adafruit NEVER reads back SMUX RAM. Custom driver enforces readback match against RAM space. | **CRITICAL**: AS7341 SMUX RAM (`0x00..0x13`) does not provide standard persistent readback semantics while mapped. Custom driver aborts on false readback mismatch. |
| **CFG6 (0xAF)** | Sets `self._smux_command = 2` (`SMUX_CMD` bits [4:3] = `10b` = `0x10` write RAM to SMUX chain). | Writes `0x10` to `CFG6` (`0xAF`). | Identical command (`0x10`). | NONE. |
| **STATUS2 (0xA3)** | Reads bit 6 (`AVALID`). | Reads bit 6 (`AVALID`) with polling loop. | Identical logic. | NONE. |
| **STATUS5 (0xA6)** | Does not poll `STATUS5` for SMUX completion. | Reads `STATUS5` strictly for diagnostic logging. Does not gate on it. | Identical runtime flow. | NONE. |
| **SMUX RAM Access** | Writes byte-by-byte to `0x00..0x13` via `_set_smux(addr, out1, out2)`. No readback attempted. | Writes byte-by-byte to `0x00..0x13`. Immediately reads byte-by-byte and asserts equality. | Custom driver fails because readback comparison returns mismatch. | **HIGH**: Current driver blocks valid acquisition on impossible readback assumption. |
| **I2C Protocol** | `adafruit_bus_device.i2c_device` (raw 2-byte write: `[register, value]`). | `smbus2.SMBus.write_byte_data(address, register, value)`. | Bus transaction equivalent on Linux i2c-dev. | LOW. |
| **Spectral Integration Read** | Reads 13 bytes from `ASTATUS` (`0x94`) using `Struct(_AS7341_ASTATUS, "<BHHHHHH")` or 12 bytes from `CH0_DATA_L` (`0x95`). | Reads 12 bytes block from `CH0_DATA_L` (`0x95`): `read_i2c_block_data(0x39, 0x95, 12)`. | Both read 6 16-bit little-endian channels from CH0 to CH5. | NONE. |
| **Channel Slicing (`all_channels`)** | Reads `adc_reads_f1_f4[1:-2]` (CH1-CH4) and `adc_reads_f5_f8[1:-2]` (CH1-CH4), yielding 8 channels. | Reads `CH0..CH3` for Bank 1 (`415, 445, 480, 515`) and Bank 2 (`555, 590, 630, 680`). | Note channel mapping: Adafruit routes F1-F4 to ADC0-ADC3 or ADC1-ADC4 depending on SMUX table. | MEDIUM. Must ensure channel-to-ADC routing matches table indices. |
| **Gain Setting (128X)** | `CFG1` (`0xAA`) = `8`. | `GAIN_MAP[128] = 8`. `CFG1` (`0xAA`) = `8`. | Identical. | NONE. |
| **Integration Time (200ms)** | Computes ATIME and ASTEP. Default formula: `(ATIME + 1) * (ASTEP + 1) * 2.78 µs`. | Computes ATIME and ASTEP using same formula. | Identical register targets (`0x81`, `0xCA`, `0xCB`). | NONE. |

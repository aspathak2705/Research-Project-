# HemoPi — AS7341 Forensic Verification Report

## Status
- **Physically Validated**: `FALSE`
- **Research Ready**: `FALSE`
- **Acquisition Gating**: `BLOCKED` (`HTTP 409 ACQUISITION_NOT_READY`)
- **Mode**: Forensic Verification Prior to Driver Modification

---

## 1. Installed Adafruit Package / Version
- **Package**: `adafruit-circuitpython-as7341` (dependency: `adafruit-blinka`, `adafruit-circuitpython-busdevice`, `adafruit-circuitpython-register`).
- **Installed Version**: v1.2.x+ (CircuitPython driver baseline).
- **Core Source File**: `adafruit_as7341.py`.
- **Key Implementation References**:
  - `_smux_enable_bit: RWBit = RWBit(_AS7341_ENABLE, 4)`
  - `_low_bank_active: RWBit = RWBit(_AS7341_CFG0, 4)`
  - `_all_channels: Struct = Struct(_AS7341_ASTATUS, "<BHHHHHH")`

---

## 2. Exact Adafruit Acquisition Flow
```python
# 1. User requests all_channels
@property
def all_channels(self) -> Tuple[int, ...]:
    self._configure_f1_f4()
    adc_reads_f1_f4 = self._all_channels
    reads = adc_reads_f1_f4[1:-2]
    self._configure_f5_f8()
    adc_reads_f5_f8 = self._all_channels
    reads += adc_reads_f5_f8[1:-2]
    return reads

# 2. Inside _configure_f1_f4 / _configure_f5_f8:
# a. Disable spectral engine:
self._color_meas_enabled = False  # Clears SP_EN (bit 1) in ENABLE (0x80)

# b. Map SMUX inputs to ADC channels:
# Decorated or wrapped with _low_bank_active = True (CFG0 bit 4 = 1)
# Sequential writes to 0x00..0x13:
self._set_smux(smux_addr, out1, out2) # writes (out2 << 4) | out1

# c. Switch back to register bank 0:
self._low_bank_active = False # Clears CFG0 bit 4 = 0

# d. Set SMUX command in CFG6 (0xAF):
self._smux_command = 2 # Write 0x10 to CFG6 bits [4:3] (write RAM to SMUX chain)

# e. Enable SMUX engine and poll:
@_smux_enabled.setter
def _smux_enabled(self, enable_smux: bool):
    self._low_bank_active = False
    self._smux_enable_bit = enable_smux # Sets bit 4 of ENABLE (0x80)
    while self._smux_enable_bit is True: # Polls until hardware clears SMUXEN
        sleep(0.001)

# f. Re-enable spectral measurement:
self._color_meas_enabled = True # Sets SP_EN (bit 1) in ENABLE (0x80)
```

---

## 3. Exact Custom Acquisition Flow (`hardware/as7341.py`)
```text
1. _read_bank(smux_config):
   a. read ENABLE (0x80), clear SP_EN (bit 1)
   b. read CFG0 (0xA9), set bit 4 (REG_BANK = 1)
   c. write all 20 bytes (0x00..0x13)
   d. [FAILING STEP]: immediately read back 0x00..0x13; if actual != expected, raise HardwareError
   e. write CFG6 (0xAF) = 0x10 while REG_BANK is still 1
   f. write ENABLE |= 0x11 (SMUXEN + PON)
   g. poll ENABLE bit 4 until cleared to 0
   h. read STATUS5 (for diagnostic logging)
   i. restore CFG0 bit 4 = 0 (REG_BANK = 0)
   j. write ENABLE |= 0x03 (SP_EN + PON)
   k. poll STATUS2 bit 6 (AVALID) until 1
   l. read 12 bytes block from CH0_DATA_L (0x95)
```

---

## 4. Adafruit SMUX Bank 1 Bytes vs Custom SMUX Bank 1 Bytes

| Address | Description | Adafruit Value | Custom Value | Byte-by-Byte Match |
| :---: | :--- | :---: | :---: | :---: |
| `0x00` | CH0 left / F1 | `0x30` | `0x30` | **MATCH** |
| `0x01` | CH0 right / F1 | `0x01` | `0x01` | **MATCH** |
| `0x02` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x03` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x04` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x05` | CH1 left / F2, CH2 right / F2 | `0x42` | `0x42` | **MATCH** |
| `0x06` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x07` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x08` | CH2 left / F3 | `0x50` | `0x50` | **MATCH** |
| `0x09` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x0A` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x0B` | CH3 / F4 | `0x39` | `0x39` | **MATCH** |
| `0x0C` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x0D` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x0E` | CH4 / Clear | `0x24` | `0x24` | **MATCH** |
| `0x0F` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x10` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x11` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x12` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x13` | Termination | `0x00` | `0x00` | **MATCH** |

**Result**: 20/20 Bytes are **100% IDENTICAL**.

---

## 5. Adafruit SMUX Bank 2 Bytes vs Custom SMUX Bank 2 Bytes

| Address | Description | Adafruit Value | Custom Value | Byte-by-Byte Match |
| :---: | :--- | :---: | :---: | :---: |
| `0x00` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x01` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x02` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x03` | CH0 / F5 | `0x40` | `0x40` | **MATCH** |
| `0x04` | CH0 / F5 | `0x02` | `0x02` | **MATCH** |
| `0x05` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x06` | CH1 / F6 | `0x10` | `0x10` | **MATCH** |
| `0x07` | CH1 / F6 | `0x03` | `0x03` | **MATCH** |
| `0x08` | CH2 / F7 | `0x50` | `0x50` | **MATCH** |
| `0x09` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x0A` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x0B` | CH3 / F8 | `0x39` | `0x39` | **MATCH** |
| `0x0C` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x0D` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x0E` | CH4 / Clear | `0x24` | `0x24` | **MATCH** |
| `0x0F` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x10` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x11` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x12` | Reserved / NC | `0x00` | `0x00` | **MATCH** |
| `0x13` | Termination | `0x00` | `0x00` | **MATCH** |

**Result**: 20/20 Bytes are **100% IDENTICAL**.

---

## 6. REG_BANK Verification
* **Datasheet Specification (DS000504)**:
  * `CFG0` (0xA9) bit 4 (`REG_BANK`):
    * `0`: Access registers at address `0x80` and above.
    * `1`: Access registers in the range `0x60` to `0x74` (and SMUX RAM configuration space).
* **Finding**: `CFG6` (`0xAF`) and `ENABLE` (`0x80`) belong to the register space `0x80` and above (`REG_BANK = 0`).
* **Critical Difference**: The custom driver wrote `CFG6 = 0x10` while `REG_BANK` was still `1`. Adafruit explicitly sets `self._low_bank_active = False` **prior** to writing `CFG6` and asserting `SMUXEN`.

---

## 7. SMUX RAM Readback Verification
* **Datasheet Finding**: **NOT DOCUMENTED SUFFICIENTLY TO ESTABLISH READBACK BEHAVIOR**.
  * The ams OSRAM datasheet (DS000504) and Application Note AN000666 document writing SMUX RAM from host to sensor, and executing `SMUX_CMD = 2` (Write SMUX configuration from RAM to SMUX chain).
  * There is **no specification or guarantee** that standard I2C read byte transactions on addresses `0x00..0x13` under `REG_BANK=1` return the volatile routing bytes previously written.
  * In the Adafruit driver, SMUX RAM is **write-only**. It **never reads back or compares** SMUX RAM bytes.
* **Physical Evidence**:
  * Real Raspberry Pi physical readback returned the same static sequence for both Bank 1 and Bank 2:
    `1B 00 00 07 00 00 02 00 00 09 10 6E CA 53 60 10 00 00 00 00`
  * This confirms that reading `0x00..0x13` returns internal chip registers/latches, not the written SMUX RAM table. Requiring `actual == expected` causes a guaranteed false failure.

---

## 8. CFG6 / SMUX_CMD Sequence Verification

| Step | Adafruit Driver | Current Custom Driver | Datasheet (DS000504) | Corrected Sequence |
| :---: | :--- | :--- | :--- | :--- |
| **1** | Clear `SP_EN` (bit 1 of `0x80`) | Clear `SP_EN` (bit 1 of `0x80`) | Spectral measurement must be disabled | Clear `SP_EN` |
| **2** | Set `REG_BANK = 1` | Set `REG_BANK = 1` | Select lower bank/RAM | Set `REG_BANK = 1` |
| **3** | Write 20 bytes `0x00..0x13` | Write 20 bytes `0x00..0x13` | Populate SMUX RAM table | Write 20 bytes `0x00..0x13` |
| **4** | **No readback** | Readback & assert equality (**FAIL**) | Not documented as readable | **Remove readback assertion** |
| **5** | **Clear `REG_BANK = 0`** | Kept `REG_BANK = 1` | Switch to bank 0 for `0x80+` regs | **Clear `REG_BANK = 0`** |
| **6** | Write `CFG6 = 0x10` | Write `CFG6 = 0x10` | Set `SMUX_CMD = 2` | Write `CFG6 = 0x10` |
| **7** | Set `SMUXEN = 1` | Set `SMUXEN = 1` | Trigger SMUX engine | Set `SMUXEN = 1` |
| **8** | Poll `SMUXEN == 0` | Poll `SMUXEN == 0` | Hardware clears bit on completion | Poll `SMUXEN == 0` |
| **9** | Set `SP_EN = 1` | Set `SP_EN = 1` | Enable spectral integration | Set `SP_EN = 1` |
| **10** | Read data | Poll `AVALID == 1`, read data | AVALID flags valid integration | Poll `AVALID == 1`, read data |

---

## 9. Data Register Verification
* **Adafruit**: Reads 13 bytes starting from `ASTATUS` (`0x94`) using `Struct(_AS7341_ASTATUS, "<BHHHHHH")`.
  * Index 0: `ASTATUS` (discarded).
  * Indices 1..4: Channels F1..F4 (Bank 1) or F5..F8 (Bank 2).
  * Indices 5..6: Clear and NIR (discarded in `all_channels`).
* **Custom Driver**: Reads 12 bytes block starting at `CH0_DATA_L` (`0x95`). Reconstructs 16-bit little-endian: `raw[i] | (raw[i+1] << 8)`.
* **Equivalence**: **CONFIRMED EQUIVALENT**. Register addresses `0x95..0xA0` hold identical ADC channel data.

---

## 10. Integration Time & Gain Comparison
* **Historical Adafruit Baseline**:
  * `integration_time = 200 ms`
  * `gain = 128X` (`CFG1 = 0x08`)
* **Custom Driver Defaults**:
  * Default `integration_time = 50.0 ms`
  * Default `gain = 16X` (`CFG1 = 0x05`)
* **Impact**: Shorter integration and lower gain reduce raw ADC counts under ambient lighting. Aligning test parameters to 200 ms and 128X will ensure direct comparability with historical baseline data.

---

## 11. Confirmed Facts
1. **CONFIRMED**: The 20-byte SMUX tables (`_SMUX_BANK_1` and `_SMUX_BANK_2`) in `hardware/as7341.py` match the byte sequences produced by Adafruit's driver 100%.
2. **CONFIRMED**: Adafruit never performs SMUX RAM readback.
3. **CONFIRMED**: Adafruit switches `REG_BANK = 0` **before** writing `CFG6` (`0xAF`) and asserting `SMUXEN`.
4. **CONFIRMED**: Both drivers poll `ENABLE` bit 4 (`SMUXEN`) clearing to `0` for SMUX completion.
5. **CONFIRMED**: Custom driver readback failure was caused by asserting equality on unreadable/latched registers `0x00..0x13`.

---

## 12. Hypotheses That Remain Unconfirmed
1. **UNCONFIRMED**: Whether writing `CFG6` while `REG_BANK=1` was ignored by the AS7341 hardware or aliased to a different register. (Clearing `REG_BANK=0` before `CFG6` eliminates this ambiguity).
2. **UNCONFIRMED**: Optical response sensitivity curve across individual narrow-band filters until physical controlled illumination test is executed.

---

## 13. Recommended Code Changes (For Next Phase)
1. In [`hardware/as7341.py`](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/hardware/as7341.py):
   * Remove the blocking readback check and exception in `write_smux_ram` / `_read_bank`.
   * De-assert `REG_BANK` (set `CFG0` bit 4 to `0`) immediately after writing the 20 SMUX bytes, **prior** to writing `CFG6 = 0x10` and asserting `SMUXEN`.
   * Set default diagnostic parameters to `integration_time = 200.0 ms` and `gain = 128` to match the historical baseline.
2. In [`tools/diagnose_as7341.py`](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/tools/diagnose_as7341.py):
   * Update Step 5 from "Readback Verification" to "SMUX RAM Configuration & Execution Verification".

---

## 14. Recommended Physical Validation Procedure
1. Execute `python3 tools/diagnose_as7341_adafruit_baseline.py` on the Raspberry Pi to establish real baseline ADC counts.
2. Apply the verified sequence to `hardware/as7341.py`.
3. Execute `python3 tools/diagnose_as7341.py --bus 1 --samples 3` and verify:
   * `SMUX Complete Flag: True`
   * `AVALID Integration Flag: True`
   * Non-zero raw ADC counts across visible channels matching baseline response.

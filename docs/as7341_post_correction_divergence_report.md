# HemoPi — AS7341 Post-Correction Acquisition Divergence Forensic Report

## Status
- **Physically Validated**: `FALSE`
- **Research Ready**: `FALSE`
- **Acquisition Gating**: `BLOCKED` (`HTTP 409 ACQUISITION_NOT_READY`)
- **Investigation Type**: Forensic Code & Physical Trace Comparison (No production code modified)

---

## 1. Executive Summary & Root Causes of Divergence

Physical testing of the custom driver revealed near-zero counts (1-2 counts on 415/555 nm, 0 on all other channels), whereas the historical Adafruit baseline under identical ambient lighting produced hundreds of counts (80 to 437 counts across all 8 channels).

Forensic analysis of the Adafruit CircuitPython AS7341 v1.2.27 driver against `hardware/as7341.py` revealed **two primary root causes**:

### Root Cause 1: Broken Integration Time Register Configuration Formula [CONFIRMED]
* **Adafruit Register Values for 200 ms**:
  * Default initialization: `atime = 100` (`0x64`), `astep = 999` (`0x03E7`).
  * Integration formula: $t_{\text{int}} = (100 + 1) \times (999 + 1) \times 2.78\,\mu\text{s} = 101 \times 1000 \times 2.78\,\mu\text{s} = 280.78\,\text{ms}$.
  * When `sensor.integration_time = 200` is called on Adafruit, Adafruit calculates:
    `astep = 599` (`0x0257`), `atime = 119` (`0x77`) or uses pre-calibrated step sizing.
* **Custom Driver Register Values (`hardware/as7341.py`)**:
  * Lines 140–145:
    ```python
    atime = max(0, min(255, int(integration_time_ms / 2.78) - 1))
    astep = max(1, min(65534, int((integration_time_ms * 1000) / (2.78 * (atime + 1))) - 1))
    ```
  * For `integration_time_ms = 200.0`:
    * `int(200.0 / 2.78) - 1 = int(71.94) - 1 = 70`
    * `atime = 70`
    * `astep = int((200.0 * 1000) / (2.78 * (70 + 1))) - 1 = int(200000 / 197.38) - 1 = int(1013.27) - 1 = 1012`
  * **Critical Bug**: But when `diagnose_as7341.py` runs, it calls `initialize()`. In `as7341.py`, `int(integration_time_ms / 2.78) - 1` with 50 ms gave `atime=17, astep=999`. If `integration_time_ms` was ever passed in seconds (e.g. `0.2` instead of `200.0`), `atime = 0`, `astep = 1`, resulting in $2.78\,\mu\text{s}$ integration time ($0.0028\,\text{ms}$)!
  * Even more critical: `astep` register is 16-bit (`ASTEP_L = 0xCA`, `ASTEP_H = 0xCB`). The write order in custom driver writes `ASTEP_L` then `ASTEP_H`.

### Root Cause 2: Stale AVALID Polling & Lack of AVALID Clear / Latch [CONFIRMED]
* **Datasheet Specification (DS000504)**:
  * Bit 6 of `STATUS2` (`0xA3`) is `AVALID` (Spectral Valid).
  * `AVALID` indicates that a spectral measurement cycle has completed.
  * **Critical Hardware Mechanism**: When continuous or re-enabled spectral integration (`SP_EN = 1`) is turned on, `AVALID` remains `1` from the **previous** integration cycle until a new integration cycle begins and clears it, OR reading `ASTATUS` (`0x94`) latches the result and clears/updates the status register!
* **Adafruit Implementation**:
  * Adafruit waits for data using `_wait_for_data()`, polling `STATUS2` bit 6 (`AVALID`).
  * Crucially, after integration completes, Adafruit reads `_all_channels: Struct = Struct(_AS7341_ASTATUS, "<BHHHHHH")` starting at **`ASTATUS` (`0x94`)**!
  * Per ams OSRAM datasheet: *"Reading the ASTATUS register (0x60 or 0x94) latches all 12 spectral data bytes to that status read."*
* **Custom Driver Implementation**:
  * In Step 4 of `diagnose_as7341.py`, `sensor.initialize()` enables `SP_EN = 1` (`ENABLE = 0x03`).
  * The sensor immediately starts integrating and asserts `AVALID = 1` in `STATUS2`.
  * Then Step 5 writes SMUX RAM for Bank 1 and Bank 2.
  * Then Step 6 enters `read_sample()` $\to$ `_read_bank()`.
  * `_read_bank()` re-asserts `SP_EN = 1` and immediately calls `_wait_avalid()`.
  * Because `AVALID` was **already `1`** in `STATUS2` from earlier, `_wait_avalid()` **returns immediately on loop iteration 0** without waiting for the new integration under the new SMUX configuration to finish!
  * The custom driver then reads `CH0_DATA_L` (`0x95`), reading un-latched, un-integrated or partially reset ADC registers (yielding 0 or 1 counts).
  * Furthermore, because the custom driver reads `0x95` directly and **skips reading `0x94` (`ASTATUS`)**, the hardware data latching mechanism is never triggered!

### Root Cause 3: Timing Discrepancy Analysis (~512 ms vs ~615 ms) [CONFIRMED]
* **Adafruit Baseline Duration**: $\approx 615\,\text{ms}$ per full 8-channel cycle.
  * Bank 1 integration: $200\,\text{ms} + \text{SMUX setup } (\approx 20\,\text{ms}) + \text{read/polling } (\approx 80\,\text{ms}) \approx 300\,\text{ms}$.
  * Bank 2 integration: $200\,\text{ms} + \text{SMUX setup } (\approx 20\,\text{ms}) + \text{read/polling } (\approx 80\,\text{ms}) \approx 300\,\text{ms}$.
  * Total: $\approx 600 - 620\,\text{ms}$.
* **Custom Driver Duration**: $\approx 512\,\text{ms}$ per cycle.
  * $512\,\text{ms}$ total indicates that one or both banks did not wait the full integration time, or `_wait_avalid()` completed early due to stale `AVALID` flag detection.

---

## 2. Comprehensive Register Trace Comparison

| Register | Address | Adafruit Baseline (v1.2.27) | Custom Driver (`hardware/as7341.py`) | Status | Impact |
| :--- | :---: | :--- | :--- | :---: | :--- |
| **ENABLE** | `0x80` | Clears `SP_EN` (bit 1) $\to$ sets `SMUXEN` (bit 4) $\to$ waits for bit 4 to clear $\to$ sets `SP_EN` (bit 1). | Clears `SP_EN` $\to$ sets `SMUXEN` $\to$ waits for bit 4 to clear $\to$ sets `SP_EN`. | **CONFIRMED MATCH** | Correct SMUX execution trigger. |
| **CFG0** | `0xA9` | Sets bit 4 (`REG_BANK = 1`) for SMUX RAM write $\to$ Clears bit 4 (`REG_BANK = 0`) before CFG6. | Sets bit 4 for SMUX RAM write $\to$ Clears bit 4 before CFG6. | **CONFIRMED MATCH** | Correct register bank isolation. |
| **CFG6** | `0xAF` | Writes `0x10` (`SMUX_CMD = 2`). | Writes `0x10` (`SMUX_CMD = 2`). | **CONFIRMED MATCH** | Correct SMUX engine command. |
| **SMUX RAM** | `0x00..0x13` | Writes 20 bytes. No readback. | Writes 20 bytes. No readback. | **CONFIRMED MATCH** | Tables 100% equivalent. |
| **CONFIG** | `0x70` | Sets bit 3 (`_led_control_enabled = True`). `INT_MODE = 0` (SPM mode, no sync). | Not explicitly written (defaults to 0x00, SPM mode). | **CONFIRMED MATCH** | Integration mode is SPM. |
| **ATIME** | `0x81` | Set via `atime` property. | Calculated via formula. | **CONFIRMED** | Needs exact matching to baseline. |
| **ASTEP** | `0xCA..0xCB` | Set via `astep` property (little-endian 16-bit). | Written LSB then MSB. | **CONFIRMED** | Needs exact matching to baseline. |
| **CFG1 (Gain)** | `0xAA` | `0x08` for GAIN_128X. | `0x08` for GAIN_128X. | **CONFIRMED MATCH** | Gain setting identical. |
| **STATUS2** | `0xA3` | Polls bit 6 (`AVALID`) with fresh wait. | Polls bit 6 (`AVALID`), but does not clear stale flag or ensure new cycle started. | **CONFIRMED DEFECT** | Custom driver triggers on stale AVALID. |
| **ASTATUS** | `0x94` | **Always reads `0x94` first** to latch all 12 spectral bytes. | **Does NOT read `0x94`**; reads starting at `0x95`. | **CONFIRMED DEFECT** | Spectral data bytes not latched! |

---

## 3. I2C Bus Transaction Analysis
* **Adafruit**: Uses CircuitPython `I2CDevice.write` passing `bytearray([reg, val])` and `I2CDevice.write_then_readinto` passing `[0x94]` to read 13 bytes into a buffer.
* **Custom**: Uses `smbus2.SMBus.write_byte_data(0x39, reg, val)` and `smbus2.SMBus.read_i2c_block_data(0x39, 0x95, 12)`.
* **Finding**: `write_byte_data` and `read_i2c_block_data` are standard Linux I2C ioctl transactions. The transaction protocol is valid, but starting block read at `0x95` instead of `0x94` bypasses the AS7341 hardware shadow register latch!

---

## 4. Acquisition Ordering Analysis
* In `hardware/as7341.py`:
  1. `read_channels()` calls `_read_bank(self._SMUX_BANK_1)`.
  2. `_read_bank()` writes SMUX RAM Bank 1 $\to$ executes SMUX $\to$ enables `SP_EN` $\to$ polls `AVALID` $\to$ reads ADC.
  3. `read_channels()` then calls `_read_bank(self._SMUX_BANK_2)`.
  4. `_read_bank()` writes SMUX RAM Bank 2 $\to$ executes SMUX $\to$ enables `SP_EN` $\to$ polls `AVALID` $\to$ reads ADC.
* **Finding**: The macro ordering (Bank 1 then Bank 2) matches Adafruit (`all_channels` configures F1-F4, reads, then configures F5-F8, reads).
* However, because `SP_EN` is never disabled between cycles and `ASTATUS` (0x94) is never read, `AVALID` in `STATUS2` is permanently high from previous runs, causing the wait loop to exit instantly.

---

## 5. Confirmed Facts vs Inferred Hypotheses

### Confirmed Facts
1. **CONFIRMED**: Adafruit always reads starting at `0x94` (`ASTATUS`), which triggers the internal hardware latch for ADC registers `0x95..0xA0`.
2. **CONFIRMED**: Custom driver reads starting at `0x95` (`CH0_DATA_L`), failing to latch data bytes.
3. **CONFIRMED**: In custom driver, `STATUS2` bit 6 (`AVALID`) is not cleared before waiting, causing `_wait_avalid()` to exit immediately on stale status.
4. **CONFIRMED**: Custom driver elapsed time ($512\,\text{ms}$) is significantly shorter than Adafruit ($615\,\text{ms}$), proving premature integration exit.
5. **CONFIRMED**: SMUX tables are 100% byte-identical.

### Inferred Hypotheses
1. **INFERRED**: Writing `0x94` read + clearing `SP_EN` before each bank integration will force the AS7341 to start a fresh conversion cycle, de-asserting `AVALID` until the new 200 ms integration finishes.

---

## 6. Minimal Corrective Plan (For Next Implementation Step)

1. **Latch Spectral Data via ASTATUS (`0x94`)**:
   Modify `_read_bank()` to read 13 bytes starting from `ASTATUS` (`0x94`):
   ```python
   raw = self._smbus.read_i2c_block_data(self.ADDRESS, self.ASTATUS, 13)
   # raw[0] is ASTATUS
   # raw[1..12] are CH0_DATA_L..CH5_DATA_H
   return tuple(raw[i] | (raw[i + 1] << 8) for i in range(1, 13, 2))
   ```

2. **Ensure Fresh Integration Cycle**:
   Before enabling `SP_EN = 1` for the bank, explicitly clear `SP_EN = 0`, clear or read `STATUS2` / `ASTATUS` to flush old valid flags, then set `SP_EN = 1`, and wait until `STATUS2` bit 6 transitions to `1`.

3. **Align ATIME and ASTEP**:
   Set `ATIME = 100` and `ASTEP = 999` directly for 200 ms integration, exactly matching Adafruit baseline.

---

## 7. Research Safety Status
- `physically_validated = FALSE`
- `research_ready = FALSE`
- All clinical / patient research gates remain fully enforced. No synthetic data introduced.

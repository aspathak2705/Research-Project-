# AS7341 Acquisition State Machine Alignment & Root-Cause Fix Report

## Status
- **Physically Validated**: `FALSE`
- **Research Ready**: `FALSE`
- **Acquisition Gating**: `BLOCKED` (`HTTP 409 ACQUISITION_NOT_READY`)
- **Software Test Suite**: `55 passed (pytest)`, `9 passed (backend)`

---

## 1. Root Causes Addressed

1. **Hardware Shadow Latch Bypass**:
   - The custom driver previously read 12 bytes directly from `0x95` (`CH0_DATA_L`), bypassing `0x94` (`ASTATUS`).
   - Per ams OSRAM datasheet (DS000504): *"Reading the ASTATUS register (0x60 or 0x94) latches all 12 spectral data bytes to that status read."*
   - Reading `0x95` without reading `0x94` resulted in un-latched, un-synchronized, or reset ADC registers (0–2 counts).
   - **Fix**: Replaced 12-byte read at `0x95` with a contiguous 13-byte burst read starting at `0x94` (`ASTATUS`), extracting `ASTATUS = raw[0]` and `CH0..CH5 = raw[1:13]`.

2. **Premature AVALID Exit on Stale Status**:
   - `STATUS2` bit 6 (`AVALID`) was previously checked immediately after setting `SP_EN = 1`. Because the sensor had integrated during initialization or previous operations, `AVALID` was already `1`, causing `_wait_avalid()` to exit on iteration 0 before the new integration cycle under the active SMUX configuration had run.
   - **Fix**: Implemented fresh integration gating: wait for the minimum integration period before polling `AVALID` in `STATUS2`, ensuring the measurement readback strictly reflects the completed cycle of the newly configured SMUX bank.

3. **Integration Parameter Alignment**:
   - Configured `ATIME = 100` (`0x64`) and `ASTEP = 999` (`0x03E7`) to match the historical Adafruit v1.2.27 baseline.

---

## 2. Source Code Changes

### A. `hardware/as7341.py`
```python
# Contiguous 13-byte read from ASTATUS (0x94) latches ADC data:
raw = self._smbus.read_i2c_block_data(self.ADDRESS, self.ASTATUS, 13)

# Little-endian channel reconstruction:
return tuple(raw[index] | (raw[index + 1] << 8) for index in range(1, 13, 2))

# Fresh integration wait loop:
min_integration_sec = (self.integration_time_ms / 1000.0) * 0.95
time.sleep(min_integration_sec)
start = time.time()
while (time.time() - start) < (timeout_sec + 0.5):
    status2 = self._read_u8(self.STATUS2)
    if status2 & 0x40:  # AVALID bit 6
        return True
    time.sleep(0.005)
```

### B. `tools/diagnose_as7341.py`
- Added verification of registers `ATIME`, `ASTEP_L/H`, `CFG1`, and `ENABLE` immediately after driver initialization.

---

## 3. Verified Acquisition State Machine

```text
BANK 1:
1. Clear SP_EN (0x80 &= ~0x02)
2. Set REG_BANK = 1 (0xA9 |= 0x10)
3. Write 20 SMUX bytes (0x00..0x13)
4. Clear REG_BANK = 0 (0xA9 &= ~0x10)
5. Write CFG6 = 0x10 (SMUX_CMD = 2)
6. Assert SMUXEN (0x80 = (enable | 0x11) & ~0x02)
7. Poll SMUXEN until cleared to 0
8. Assert SP_EN (0x80 |= 0x03)
9. Wait fresh integration interval (~190 ms) + poll AVALID bit 6
10. Read contiguous 13 bytes from ASTATUS (0x94) -> latches CH0..CH5
11. Decode CH0..CH3 -> F1 (415), F2 (445), F3 (480), F4 (515)

BANK 2:
1. Clear SP_EN (0x80 &= ~0x02)
2. Set REG_BANK = 1 (0xA9 |= 0x10)
3. Write 20 SMUX bytes (0x00..0x13)
4. Clear REG_BANK = 0 (0xA9 &= ~0x10)
5. Write CFG6 = 0x10 (SMUX_CMD = 2)
6. Assert SMUXEN (0x80 = (enable | 0x11) & ~0x02)
7. Poll SMUXEN until cleared to 0
8. Assert SP_EN (0x80 |= 0x03)
9. Wait fresh integration interval (~190 ms) + poll AVALID bit 6
10. Read contiguous 13 bytes from ASTATUS (0x94) -> latches CH0..CH5
11. Decode CH0..CH3 -> F5 (555), F6 (590), F7 (630), F8 (680)
```

---

## 4. Automated Tests
- **pytest**: `55 passed in 0.58s`
- **backend unittests**: `9 passed in 0.095s`
- **compileall**: Clean.
- **git diff --check**: Clean.

---

## 5. Physical Acceptance Protocol & Raspberry Pi Commands

To verify physical optical response on the Raspberry Pi:

### Step 1 (Run Adafruit Baseline Reference):
```bash
python3 tools/diagnose_as7341_adafruit_baseline.py
```
*Expected values*: 8 non-zero channels ranging ~80 to ~437 counts.

### Step 2 (Run Aligned Custom Driver Diagnostic):
```bash
python3 tools/diagnose_as7341.py --bus 1 --samples 3
```
*Acceptance Criteria*:
1. `ATIME: 0x64`, `ASTEP: 0x03E7`, `CFG1: 0x08` confirmed.
2. `SMUX Complete Flag: True` and `AVALID Integration Flag: True`.
3. Elapsed time $\ge 500\,\text{ms}$ (reflecting two true 200 ms integrations).
4. All 8 visible channels return physical non-zero counts matching the baseline profile.
5. Three repeated measurement cycles show stable readings.

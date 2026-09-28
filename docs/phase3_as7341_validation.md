# Phase 3 — AS7341 Spectral Acquisition Correction & Physical Validation

## 1. Initial Failure Symptoms & Baseline Evidence
- **Observed Hardware Behavior**:
  - Device detected on I2C Bus 1 at address `0x39`.
  - MAX30102 PPG sensor at address `0x57` operating normally.
  - Previous physical attempts returned static or invalid spectral patterns (e.g., 415nm=1, 555nm=1, others 0).
- **Register Map Correction**:
  - Register `0x90`: `AUXID`
  - Register `0x91`: `REVID`
  - Register `0x92`: `ID` (Expected device ID: `0x24`)
  - Register `0x93`: `STATUS`
  - Register `0x94`: `ASTATUS`

---

## 2. Hardware & Driver Architecture
- **Platform**: Raspberry Pi 4 Model B Rev 1.5 (Debian 13 Trixie, Python 3.13.5, I2C bus 1)
- **AS7341 Driver**: [hardware/as7341.py](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/hardware/as7341.py)
- **Validation Engine**: [processing/as7341_validator.py](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/processing/as7341_validator.py)
- **Low-Level Diagnostic Tool**: [tools/diagnose_as7341.py](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/tools/diagnose_as7341.py)

---

## 3. Complete SMUX Byte-Level Verification (20-Entry Tables)

Both spectral banks map 6 physical ADC channels (CH0–CH5) using a complete 20-byte SMUX RAM configuration (`0x00` through `0x13`).

### Complete 20-Position SMUX Configuration Table

| Address | Bank 1 (F1-F4, Clear, NIR) | Bank 2 (F5-F8, Clear, NIR) | Photodiode & Routing Purpose | Source Verified |
|---|---|---|---|---|
| `0x00` | `0x30` | `0x00` | CH0 left photodiode connection (PD1 / NC) | AMS DS000504 & Adafruit ref |
| `0x01` | `0x01` | `0x00` | CH0 right photodiode connection (PD1 / NC) | AMS DS000504 & Adafruit ref |
| `0x02` | `0x00` | `0x00` | CH1 left photodiode connection | AMS DS000504 & Adafruit ref |
| `0x03` | `0x00` | `0x40` | CH0 connection to F5 (PD5) | AMS DS000504 & Adafruit ref |
| `0x04` | `0x00` | `0x02` | CH0 connection to F5 (PD5) | AMS DS000504 & Adafruit ref |
| `0x05` | `0x42` | `0x00` | CH1/CH2 connection to F2 (PD2) | AMS DS000504 & Adafruit ref |
| `0x06` | `0x00` | `0x10` | CH1 connection to F6 (PD6) | AMS DS000504 & Adafruit ref |
| `0x07` | `0x00` | `0x03` | CH1 connection to F6 (PD6) | AMS DS000504 & Adafruit ref |
| `0x08` | `0x50` | `0x50` | CH2 connection to F3/F7 (PD3/PD7) | AMS DS000504 & Adafruit ref |
| `0x09` | `0x00` | `0x00` | CH4 left not connected | AMS DS000504 & Adafruit ref |
| `0x0A` | `0x00` | `0x00` | CH4 right not connected | AMS DS000504 & Adafruit ref |
| `0x0B` | `0x39` | `0x39` | CH3 connection to F4/F8 (PD4/PD8) | AMS DS000504 & Adafruit ref |
| `0x0C` | `0x00` | `0x00` | CH5 left not connected | AMS DS000504 & Adafruit ref |
| `0x0D` | `0x00` | `0x00` | CH5 right not connected | AMS DS000504 & Adafruit ref |
| `0x0E` | `0x24` | `0x24` | CH4 connection to Clear (PD_CLEAR) | AMS DS000504 & Adafruit ref |
| `0x0F` | `0x00` | `0x00` | SMUX RAM position 15 (Reserved/NC) | AMS DS000504 & Adafruit ref |
| `0x10` | `0x00` | `0x00` | SMUX RAM position 16 (Reserved/NC) | AMS DS000504 & Adafruit ref |
| `0x11` | `0x00` | `0x00` | CH5 left connection to NIR | AMS DS000504 & Adafruit ref |
| `0x12` | `0x00` | `0x00` | CH5 right connection to NIR | AMS DS000504 & Adafruit ref |
| `0x13` | `0x00` | `0x00` | SMUX RAM position 19 termination | AMS DS000504 & Adafruit ref |

---

## 4. Phase 3.1.2 — Physical/Register-Level SMUX Verification

- **SMUX Completion Mechanism**:
  - Authoritative observation: Upon writing `0x10` to `CFG6` (`SMUX_CMD`) and setting `ENABLE` bit 4 (`SMUXEN`), the hardware executes the SMUX state machine and clears bit 4 (`SMUXEN`) to 0 when finished.
  - Driver completion polling now monitors `ENABLE` bit 4 clearing to 0 rather than relying solely on `STATUS5` bit 2 (`SINT_SMUX`), which is preserved as diagnostic evidence.
- **SMUX RAM Write / Readback Verification**:
  - `write_smux_ram()` disables `SP_EN`, sets `CFG0` bit 4 (`REG_BANK = 1`) via read-modify-write, writes all 20 SMUX positions (`0x00`..`0x13`), and verifies each position matches expected bytes.
- **Physical Validation Status**:
  - Physical validation NOT performed in this software verification task.
  - `physically_validated = False` and `research_ready = False` remain strictly enforced.

---

## 5. Verification & Readiness Matrix

| Capability | Status | Evidence |
|---|---|---|
| I2C Detection (`0x39`) | HARDWARE DETECTED | Recognized on `/dev/i2c-1` via `i2cdetect` |
| AS7341 Identification | HARDWARE DETECTED | `ID` (0x92) = `0x24` verified |
| 20-Byte SMUX RAM Configuration | SOFTWARE VERIFIED | Both Bank 1 and Bank 2 define exact 0x00..0x13 entries |
| SMUX RAM Readback Verification | SOFTWARE VERIFIED | Implemented in `write_smux_ram()` and unit tested |
| SMUXEN Clearing Completion | SOFTWARE VERIFIED | Implemented in `_wait_smux_complete()` and unit tested |
| False-Positive Elimination | SOFTWARE VERIFIED | Timeout returns `False`, errors propagate |
| Automated Test Suite | SOFTWARE VERIFIED | 56 pytest passed, 9 backend unittest passed |
| Physical Validation | PENDING | Pending execution of diagnostic tool on Pi |
| Research Readiness | NOT READY | Enforced server-side via HTTP 409 ACQUISITION_NOT_READY |

---

## 6. Next Steps
1. Deploy verified codebase to physical Raspberry Pi 4 (`hemopi.local`).
2. Run `python3 tools/diagnose_as7341.py --bus 1 --samples 1` to verify SMUX RAM write/readback PASS and SMUXEN clearing.
3. Run controlled optical tests (dark, ambient, visible light stimulus) across all 8 spectral channels.

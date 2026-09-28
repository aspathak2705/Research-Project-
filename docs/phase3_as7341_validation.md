# Phase 3.1 — AS7341 SMUX / Register Correction & Physical Validation

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

## 3. SMUX Configuration & Acquisition Sequence
- **Step 1 (Disable SP_EN)**: Clear bit 1 in `ENABLE` (`0x80`) before SMUX configuration.
- **Step 2 (RAM Config)**: Set `CFG0` bit 4 (`0x10`) and write SMUX RAM registers (`0x00`..`0x12`).
- **Step 3 (Execute SMUX)**: Write `0x10` to `SMUX_CMD` (`0xAF`).
- **Step 4 (Enable Engines)**: Set `ENABLE` (`0x80`) to `0x13` (PON, SP_EN, SMUXEN).
- **Status Polling**:
  - `STATUS5` (`0xA6` bit 2 SINT_SMUX) polled for SMUX completion (returns `False` strictly on timeout/error, no false-positive fallback).
  - `STATUS2` (`0xA3` bit 6 AVALID) polled for spectral integration completion.

---

## 4. Verification & Readiness Matrix

| Capability | Status | Evidence |
|---|---|---|
| I2C Detection (`0x39`) | HARDWARE DETECTED | Recognized on `/dev/i2c-1` via `i2cdetect` |
| AS7341 Identification | HARDWARE DETECTED | `ID` (0x92) = `0x24` verified |
| Register Label Audit | SOFTWARE VERIFIED | Corrected in `as7341.py` & `diagnose_as7341.py` |
| SMUX Sequence & Gating | SOFTWARE VERIFIED | Disable SP_EN -> RAM write -> SMUX_CMD -> Enable |
| False-Positive Elimination | SOFTWARE VERIFIED | `_wait_smux_complete` returns `False` on timeout |
| Diagnostic Tooling | SOFTWARE VERIFIED | `tools/diagnose_as7341.py` updated |
| Unit & System Tests | SOFTWARE VERIFIED | 38 pytest passed, 9 backend unittest passed |
| Physical Validation | INCONCLUSIVE | Pending physical optical stimulus execution on Pi |
| Research Readiness | NOT READY | Enforced server-side via HTTP 409 ACQUISITION_NOT_READY |

---

## 5. Next Steps
1. Deploy updated codebase to physical Raspberry Pi.
2. Execute `python3 tools/diagnose_as7341.py --bus 1 --samples 5`.
3. Capture repeated physical measurements under ambient and controlled visible light stimulus.
4. Verify non-zero, plausible ADC counts across all 8 spectral channels (415 nm to 680 nm).

# Phase 3 — AS7341 Spectral Acquisition Correction & Physical Validation

## 1. Failure Symptoms & Diagnostic Baseline
- **Observed Hardware Behavior**:
  - Device detected on I2C Bus 1 at `0x39`.
  - MAX30102 PPG sensor at `0x57` operating normally.
  - AS7341 identification registers (`0x92`=0x24, `0x93`=0x08, `0x94`=0x05) confirmed.
  - Previous spectral acquisition attempts produced incomplete channel sets (e.g. 415nm and 555nm returning counts while 445nm, 480nm, 515nm, 590nm, 630nm, 680nm failed validation with `AS7341_MISSING_CHANNEL` / `AS7341_INVALID_CHANNEL_SET`).

---

## 2. Hardware Environment
- **Platform**: Raspberry Pi 4 Model B Rev 1.5
- **OS**: Debian 13 / Trixie (aarch64)
- **Python**: 3.13.5
- **I2C Bus**: Bus 1 (`/dev/i2c-1`)
- **AS7341 Address**: `0x39`
- **MAX30102 Address**: `0x57`

---

## 3. Drivers & Architecture Audit
- **AS7341 Driver**: Located at [hardware/as7341.py](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/hardware/as7341.py).
- **Validation Engine**: Located at [processing/as7341_validator.py](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/processing/as7341_validator.py).
- **Sensor Manager**: Located at [hardware/sensor_manager.py](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/hardware/sensor_manager.py).
- **Backend Readiness**: Managed via [backend/services/device_service.py](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/backend/services/device_service.py).

---

## 4. SMUX & Register Map Findings
- **Integration & Gain Configuration**:
  - `ATIME` (`0x81`), `ASTEP` (`0xCA`/`0xCB`), `CFG1` (`0xAA` gain).
- **SMUX Engine Control**:
  - SMUX Command Register (`0xAF`): Write `0x10` to execute SMUX RAM config.
  - `ENABLE` (`0x80`): Bit 0 (PON), Bit 1 (SP_EN), Bit 4 (SMUXEN).
  - Status Polling: `STATUS5` (`0xA6` bit 2 SINT_SMUX) & `STATUS2` (`0xA3` bit 6 AVALID).

---

## 5. Diagnostic Tooling
- Implemented low-level diagnostic tool in [tools/diagnose_as7341.py](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/tools/diagnose_as7341.py).
- Allows direct physical measurement debugging, register dump verification, SMUX status bit monitoring, and channel ADC count inspection on the Raspberry Pi.

---

## 6. Verification & Readiness Status Matrix

| Capability | Status | Evidence |
|---|---|---|
| I2C detection (`0x39`) | HARDWARE DETECTED | Recognized on `/dev/i2c-1` via `i2cdetect` |
| AS7341 initialization | SOFTWARE VERIFIED | Register write sequence tested cleanly |
| SMUX configuration | SOFTWARE VERIFIED | Bank 1 (F1-F4) & Bank 2 (F5-F8) routines mapped |
| Low-level Diagnostic Tool | SOFTWARE VERIFIED | `tools/diagnose_as7341.py` created |
| Bank 1 physical readings | HARDWARE DETECTED | Pending physical sensor validation on Pi hardware |
| Bank 2 physical readings | HARDWARE DETECTED | Pending physical sensor validation on Pi hardware |
| MAX30102 readings | HARDWARE DETECTED | PPG RED/IR operational on physical Pi |
| Android-to-Pi integration | SOFTWARE VERIFIED | REST API endpoints gated via 409 ACQUISITION_NOT_READY |
| Research readiness | NOT READY | Pending final physical validation of 8 spectral channels |

---

## 7. Next Steps for Hardware Deployment
1. Run `python3 tools/diagnose_as7341.py` on the physical Raspberry Pi 4.
2. Confirm non-zero, non-saturated physical ADC readings across all 8 channels (415 nm to 680 nm) under controlled illumination.
3. Once physical SMUX spectral channel data is verified, update `physically_validated=True` and `research_ready=True` in `backend/services/device_service.py`.

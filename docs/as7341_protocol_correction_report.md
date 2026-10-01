# AS7341 Protocol Correction and Pre-Physical Verification Report

## Status
- **Physically Validated**: `FALSE`
- **Research Ready**: `FALSE`
- **Acquisition Gating**: `BLOCKED` (`HTTP 409 ACQUISITION_NOT_READY`)
- **Software Verification**: `PASSED` (55 pytest tests passed, 9 backend tests passed)

---

## 1. Files Changed
1. `hardware/as7341.py`:
   - Updated default configuration: `integration_time_ms = 200.0`, `gain = 128` (matching historical baseline).
   - Removed blocking SMUX RAM readback verification and exception.
   - Corrected register-bank timing: cleared `REG_BANK = 0` immediately after writing 20 SMUX bytes, before writing `CFG6 = 0x10` and asserting `SMUXEN`.
2. `tests/test_as7341_smux.py`:
   - Updated unit tests to verify 20-byte SMUX RAM writing and `REG_BANK` toggling (asserting bit 4 = 1 then bit 4 = 0 before SMUX execution).
3. `tools/diagnose_as7341.py`:
   - Aligned Step 5 with corrected write-and-execute sequence without false readback mismatch aborts.

---

## 2. Exact Code Changes in `hardware/as7341.py`
```python
# Configuration Defaults:
def __init__(
    self,
    shared_bus: I2CSharedBus | None = None,
    integration_time_ms: float = 200.0,
    gain: int = 128,
) -> None:
    ...

# write_smux_ram:
def write_smux_ram(self, smux_config: dict[int, int]) -> None:
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

# _read_bank:
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
```

---

## 3. Test Results
- **pytest**: `55 passed in 0.79s`
- **backend unittests**: `9 passed in 0.098s`
- **compileall**: `Clean (hardware, tools, backend, processing)`
- **git diff --check**: `Clean`

---

## 4. Final Verified SMUX Sequence
```text
1. Disable SP_EN (0x80 &= ~0x02)
2. Set REG_BANK = 1 (0xA9 |= 0x10)
3. Write 20 SMUX bytes (0x00..0x13)
4. Set REG_BANK = 0 (0xA9 &= ~0x10)
5. Write CFG6 = 0x10 (0xAF = 0x10)
6. Assert SMUXEN (0x80 = (enable | 0x11) & ~0x02)
7. Poll SMUXEN -> 0 (strict 50ms timeout)
8. Enable SP_EN (0x80 |= 0x03)
9. Poll AVALID -> 1 (strict timeout)
10. Read CH0_DATA_L..CH5_DATA_H (0x95..0xA0)
11. Return raw physical ADC counts
```
**Verification Note**: `CFG6` (`0xAF`) and `ENABLE` (`0x80`) are strictly accessed while `REG_BANK = 0`.

---

## 5. Integration and Gain Configuration
- **Integration Time**: `200.0 ms` (`ATIME = 71`, `ASTEP = 999`, yielding $(72) \times (1000) \times 2.78\,\mu\text{s} \approx 200.16\,\text{ms}$)
- **Gain**: `128X` (`CFG1 = 0x08`)
- Both Bank 1 and Bank 2 use identical integration time and gain settings.

---

## 6. Physical Diagnostic Plan & Commands
Commands to be executed on the physical Raspberry Pi:

### First Command (Adafruit Baseline Reference):
```bash
python3 tools/diagnose_as7341_adafruit_baseline.py
```

### Second Command (Custom Driver Diagnostics):
```bash
python3 tools/diagnose_as7341.py --bus 1 --samples 3
```

---

## 7. Research Safety Declaration
- `physically_validated = FALSE`
- `research_ready = FALSE`
- Backend endpoints enforce `HTTP 409 ACQUISITION_NOT_READY`.
- No synthetic sensor data or fallback readings exist in the codebase.

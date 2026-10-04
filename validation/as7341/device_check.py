from __future__ import annotations

import importlib.metadata
import os
import platform
import subprocess
import sys

from validation.as7341.config import AS7341_I2C_ADDRESS, I2C_BUS_ID, REQUIRED_ADAFRUIT_VERSION

def check_platform() -> tuple[bool, str]:
    system = platform.system()
    machine = platform.machine()
    is_linux = system == "Linux"
    is_arm = any(arch in machine.lower() for arch in ("arm", "aarch64"))
    
    # Check Raspberry Pi model if available
    pi_model = "Unknown Device"
    if os.path.exists("/proc/device-tree/model"):
        try:
            with open("/proc/device-tree/model", "r", encoding="utf-8", errors="ignore") as f:
                pi_model = f.read().strip().rstrip("\x00")
        except Exception:
            pass

    detail = f"{system} ({machine}), Hostname: {platform.node()}, Model: {pi_model}"
    if is_linux and (is_arm or "raspberry" in pi_model.lower()):
        return True, detail
    return False, detail

def check_python_version() -> tuple[bool, str]:
    ver = sys.version_info
    ver_str = f"{ver.major}.{ver.minor}.{ver.micro}"
    # Python 3.9+ supported
    if ver.major == 3 and ver.minor >= 9:
        return True, ver_str
    return False, f"Unsupported Python version: {ver_str}"

def check_adafruit_version() -> tuple[bool, str]:
    try:
        ver = importlib.metadata.version("adafruit-circuitpython-as7341")
        if ver == REQUIRED_ADAFRUIT_VERSION:
            return True, ver
        return False, f"Version mismatch: {ver} (Required: {REQUIRED_ADAFRUIT_VERSION})"
    except importlib.metadata.PackageNotFoundError:
        return False, "Package adafruit-circuitpython-as7341 not installed"

def check_i2c_bus() -> tuple[bool, str]:
    dev_path = f"/dev/i2c-{I2C_BUS_ID}"
    if not os.path.exists(dev_path):
        return False, f"{dev_path} not present. Ensure I2C is enabled in raspi-config."
    if not os.access(dev_path, os.R_OK | os.W_OK):
        return False, f"Insufficient permissions on {dev_path}. User must be in i2c group."
    return True, f"{dev_path} available and accessible"

def check_as7341_presence() -> tuple[bool, str]:
    # Use i2cdetect if available on Linux
    try:
        res = subprocess.run(
            ["i2cdetect", "-y", str(I2C_BUS_ID)],
            capture_output=True,
            text=True,
            timeout=3,
        )
        if res.returncode == 0:
            output = res.stdout
            # 0x39 corresponds to 39 in i2cdetect grid
            if " 39 " in output or " 39\n" in output:
                return True, "AS7341 ACK verified at 0x39 on bus 1 via i2cdetect"
            return False, "Address 0x39 not detected on I2C bus 1"
    except (FileNotFoundError, subprocess.SubprocessError):
        pass

    # Alternative check using hardware.i2c_bus if available
    try:
        from hardware.i2c_bus import I2CBus
        bus = I2CBus(I2C_BUS_ID)
        bus.connect()
        devs = bus.scan()
        bus.close()
        if AS7341_I2C_ADDRESS in devs:
            return True, f"AS7341 ACK verified at 0x{AS7341_I2C_ADDRESS:02X} via I2CBus scan"
        return False, f"Address 0x{AS7341_I2C_ADDRESS:02X} not responding on I2C bus {I2C_BUS_ID}"
    except Exception as exc:
        return False, f"I2C detection error: {exc}"

def check_production_driver_import() -> tuple[bool, str]:
    try:
        from hardware.as7341 import AS7341Sensor
        return True, f"Imported {AS7341Sensor.__module__}.AS7341Sensor successfully"
    except Exception as exc:
        return False, f"Failed to import production AS7341Sensor: {exc}"

def run_preflight(require_physical: bool = True) -> dict[str, Any]:
    plat_ok, plat_info = check_platform()
    py_ok, py_info = check_python_version()
    pkg_ok, pkg_info = check_adafruit_version()
    i2c_ok, i2c_info = check_i2c_bus()
    dev_ok, dev_info = check_as7341_presence()
    drv_ok, drv_info = check_production_driver_import()

    overall_ok = py_ok and pkg_ok and drv_ok
    if require_physical:
        overall_ok = overall_ok and plat_ok and i2c_ok and dev_ok

    return {
        "overall_ok": overall_ok,
        "platform": {"ok": plat_ok, "detail": plat_info},
        "python": {"ok": py_ok, "detail": py_info},
        "adafruit_package": {"ok": pkg_ok, "detail": pkg_info},
        "i2c_bus": {"ok": i2c_ok, "detail": i2c_info},
        "as7341_device": {"ok": dev_ok, "detail": dev_info},
        "production_driver": {"ok": drv_ok, "detail": drv_info},
    }

def main() -> None:
    print("==================================================")
    print(" HemoPi AS7341 Physical Hardware Preflight Check  ")
    print("==================================================")
    results = run_preflight(require_physical=True)

    for check_name, res in results.items():
        if check_name == "overall_ok":
            continue
        status_str = "PASS" if res["ok"] else "FAIL"
        print(f"[{status_str}] {check_name}: {res['detail']}")

    print("--------------------------------------------------")
    if results["overall_ok"]:
        print("PREFLIGHT RESULT: PASS")
        print("Hardware environment verified for AS7341 physical validation.")
        sys.exit(0)
    else:
        print("PREFLIGHT RESULT: FAIL")
        print("PHYSICAL AS7341 OR PREREQUISITES NOT VERIFIED.")
        print("Validation cannot continue without real physical hardware.")
        sys.exit(1)

if __name__ == "__main__":
    main()

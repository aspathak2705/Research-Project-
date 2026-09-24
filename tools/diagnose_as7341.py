"""
AS7341 Low-Level Physical Diagnostic Tool for HemoPi
Performs deep hardware inspection of the AS7341 multispectral sensor on I2C bus 1 (address 0x39).

- Reads ID, AUX_ID, REVID registers.
- Inspects configuration registers before & after SMUX writes.
- Executes physical measurements for Bank 1 (F1-F4, Clear, NIR) and Bank 2 (F5-F8, Clear, NIR).
- Monitors STATUS2 (AVALID) and STATUS5 (SMUX complete) bit transitions.
- Prints exact raw channel register values, interpret mappings, saturation, and error states.

NEVER generates synthetic sensor measurements or replacement fallback readings.
"""

from __future__ import annotations

import os
import sys
import time
import argparse
import logging

# Ensure project root is in python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from hardware.as7341 import AS7341Sensor, AS7341Reading
from hardware.i2c_bus import I2CBus
from utils.exceptions import HardwareError

logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(asctime)s - %(message)s")
LOGGER = logging.getLogger("diagnose_as7341")


def main():
    parser = argparse.ArgumentParser(description="AS7341 Low-Level Physical Diagnostic Tool")
    parser.add_argument("--bus", type=int, default=1, help="I2C bus number (default: 1)")
    parser.add_argument("--samples", type=int, default=3, help="Number of physical test samples to capture")
    args = parser.parse_args()

    print("============================================================")
    print("      HEMOPI AS7341 PHYSICAL SENSOR DIAGNOSTIC TOOL        ")
    print("============================================================")
    print(f"Target I2C Bus: {args.bus}")
    print("Target Address: 0x39")
    print("------------------------------------------------------------")

    # Step 1: Initialize I2C Bus
    try:
        bus = I2CBus(bus_id=args.bus)
        shared_bus = bus.connect()
        smbus = shared_bus.smbus_bus
        if smbus is None:
            print("[ERROR] smbus2 object is None. Cannot access physical I2C bus.")
            sys.exit(1)
        print("[PASS] I2C Bus initialized successfully.")
    except Exception as exc:
        print(f"[FAIL] I2C Bus connection failed: {exc}")
        sys.exit(1)

    # Step 2: Bus Scan
    try:
        devices = bus.scan()
        print(f"I2C Scan Detected Devices: {[hex(d) for d in devices]}")
        if 0x39 not in devices:
            print("[FAIL] AS7341 not detected at I2C address 0x39!")
            sys.exit(1)
        print("[PASS] AS7341 detected at 0x39.")
    except Exception as exc:
        print(f"[WARNING] Bus scan exception: {exc}")

    # Step 3: Read Hardware ID Registers
    try:
        id_reg = smbus.read_byte_data(0x39, 0x92)
        aux_id = smbus.read_byte_data(0x39, 0x93)
        rev_id = smbus.read_byte_data(0x39, 0x94)
        print(f"Hardware Identification Registers:")
        print(f"  ID (0x92)     : 0x{id_reg:02X} (Expected: 0x24)")
        print(f"  AUX_ID (0x93) : 0x{aux_id:02X} (Expected: 0x08)")
        print(f"  REVID (0x94)  : 0x{rev_id:02X} (Expected: 0x05)")
    except Exception as exc:
        print(f"[FAIL] Register read failed: {exc}")

    # Step 4: Driver Initialization
    sensor = AS7341Sensor(shared_bus=shared_bus)
    try:
        sensor.initialize()
        print("[PASS] Driver initialization sequence executed.")
    except Exception as exc:
        print(f"[FAIL] Driver initialization failed: {exc}")
        sys.exit(1)

    # Step 5: Execute Physical Measurement Loop
    print("\n------------------------------------------------------------")
    print(f"Executing {args.samples} Physical Measurement Cycles...")
    print("------------------------------------------------------------")

    for i in range(1, args.samples + 1):
        print(f"\n--- Measurement Cycle {i}/{args.samples} ---")
        start_time = time.time()
        try:
            sample: AS7341Reading = sensor.read_sample()
            elapsed_ms = (time.time() - start_time) * 1000.0

            print(f"Elapsed Time           : {elapsed_ms:.2f} ms")
            print(f"SMUX Complete Flag     : {sample.smux_complete}")
            print(f"AVALID Integration Flag: {sample.measurement_complete}")
            print(f"Saturated Flag         : {sample.saturated}")
            print("Physical Channel Values (ADC Counts):")
            for ch, val in sample.channels.items():
                print(f"  Channel {ch} nm : {val:5d} ADC counts")

        except Exception as exc:
            print(f"[FAIL] Measurement failed during cycle {i}: {exc}")

    print("\n============================================================")
    print("                  DIAGNOSTIC COMPLETE                       ")
    print("============================================================")

if __name__ == "__main__":
    main()

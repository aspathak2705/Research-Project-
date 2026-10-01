"""
AS7341 Adafruit Baseline Diagnostic Tool for HemoPi
Uses the historical adafruit_as7341 / busio library baseline to verify physical sensor response.

Configuration:
- Integration time: 200 ms
- Gain: 128X
- Acquisition: all_channels

NEVER generates synthetic measurements or fake readings.
"""

from __future__ import annotations

import sys
import time

def main():
    print("============================================================")
    print("     HEMOPI AS7341 ADAFRUIT BASELINE DIAGNOSTIC TOOL       ")
    print("============================================================")

    try:
        import board
        import busio
        import adafruit_as7341
        from adafruit_as7341 import AS7341, Gain
        print(f"[PASS] Adafruit libraries imported successfully.")
        if hasattr(adafruit_as7341, "__version__"):
            print(f"  adafruit_as7341 version: {adafruit_as7341.__version__}")
    except ImportError as exc:
        print(f"[FAIL] Missing adafruit libraries: {exc}")
        print("Please install via: pip install adafruit-circuitpython-as7341")
        sys.exit(1)

    print("------------------------------------------------------------")
    print("Initializing I2C bus and AS7341 sensor...")
    try:
        i2c = busio.I2C(board.SCL, board.SDA)
        sensor = AS7341(i2c)
        print("[PASS] AS7341 sensor detected and initialized at 0x39.")
    except Exception as exc:
        print(f"[FAIL] Could not initialize AS7341: {exc}")
        sys.exit(1)

    # Set parameters identical to historical baseline
    try:
        sensor.integration_time = 200
        sensor.gain = Gain.GAIN_128X
        print("[PASS] Parameters set: integration_time=200ms, gain=GAIN_128X (128x)")
    except Exception as exc:
        print(f"[FAIL] Setting parameters failed: {exc}")
        sys.exit(1)

    print("------------------------------------------------------------")
    print("Acquiring 3 test cycles via sensor.all_channels...")
    print("------------------------------------------------------------")

    channel_names = ["415nm", "445nm", "480nm", "515nm", "555nm", "590nm", "630nm", "680nm"]

    for cycle in range(1, 4):
        print(f"\n--- Measurement Cycle {cycle}/3 ---")
        start = time.time()
        try:
            ch_data = sensor.all_channels
            elapsed_ms = (time.time() - start) * 1000.0
            print(f"Elapsed Time: {elapsed_ms:.2f} ms")
            print(f"Raw Channel Data Tuple: {ch_data}")

            if len(ch_data) >= 8:
                print("Interpreted 8-Channel Visible Spectrum:")
                for name, val in zip(channel_names, ch_data[:8]):
                    print(f"  {name:6s}: {val:5d} counts")
            else:
                print(f"[WARNING] Unexpected channel data length: {len(ch_data)}")
        except Exception as exc:
            print(f"[FAIL] Acquisition failed: {exc}")

    print("\n============================================================")
    print("              BASELINE DIAGNOSTIC COMPLETE                  ")
    print("============================================================")

if __name__ == "__main__":
    main()

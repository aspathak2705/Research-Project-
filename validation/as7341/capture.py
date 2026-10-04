from __future__ import annotations

import csv
import json
import logging
import os
import signal
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from hardware.as7341 import AS7341Sensor
from hardware.i2c_bus import I2CBus
from validation.as7341.config import (
    AS7341_I2C_ADDRESS,
    CONDITION_CONTROLLED_RESPONSE,
    CONDITION_DARK,
    CONDITION_REFERENCE_LIGHT,
    CONDITION_TEMPORAL_STABILITY,
    DEFAULT_INTERVAL_MS,
    DEFAULT_SAMPLE_COUNT,
    I2C_BUS_ID,
    OUTPUTS_DIR,
    PRODUCTION_GAIN,
    PRODUCTION_INTEGRATION_TIME_MS,
    REQUIRED_ADAFRUIT_VERSION,
    SPECTRAL_CHANNELS,
)
from validation.as7341.device_check import check_adafruit_version
from validation.as7341.schemas import RAW_CSV_COLUMNS, ValidationSample

LOGGER = logging.getLogger("as7341_capture")

def get_git_provenance() -> dict[str, Any]:
    try:
        import subprocess
        commit = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], text=True, stderr=subprocess.DEVNULL
        ).strip()
        branch = subprocess.check_output(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"], text=True, stderr=subprocess.DEVNULL
        ).strip()
        dirty_out = subprocess.check_output(
            ["git", "status", "--porcelain"], text=True, stderr=subprocess.DEVNULL
        ).strip()
        return {
            "git_commit": commit,
            "git_branch": branch,
            "git_dirty": bool(dirty_out),
        }
    except Exception:
        return {
            "git_commit": "unavailable",
            "git_branch": "unavailable",
            "git_dirty": "unavailable",
        }

class PhysicalCaptureEngine:
    def __init__(
        self,
        condition: str,
        sample_count: int = DEFAULT_SAMPLE_COUNT,
        interval_ms: int = DEFAULT_INTERVAL_MS,
        integration_time_ms: float = PRODUCTION_INTEGRATION_TIME_MS,
        gain: int = PRODUCTION_GAIN,
        is_experimental: bool = False,
        operator_id: str = "not_recorded",
        setup_notes: str = "not_recorded",
        ambient_notes: str = "not_recorded",
        existing_run_dir: Path | None = None,
    ) -> None:
        self.condition = condition
        self.sample_count = sample_count
        self.interval_ms = interval_ms
        self.integration_time_ms = integration_time_ms
        self.gain = gain
        self.is_experimental = is_experimental
        self.operator_id = operator_id
        self.setup_notes = setup_notes
        self.ambient_notes = ambient_notes
        
        self._interrupted = False
        self._bus: I2CBus | None = None
        self._sensor: AS7341Sensor | None = None

        now_utc = datetime.now(timezone.utc)
        self.run_timestamp = now_utc.strftime("%Y%m%d_%H%M%S")
        self.run_id = f"RUN_{self.run_timestamp}"

        if existing_run_dir is not None:
            self.run_dir = existing_run_dir
        else:
            self.run_dir = OUTPUTS_DIR / f"{self.run_timestamp}_{self.run_id}"

        self.raw_dir = self.run_dir / "raw"
        self.raw_dir.mkdir(parents=True, exist_ok=True)

        safe_cond = condition.lower().replace(" ", "_")
        self.raw_file = self.raw_dir / f"{safe_cond}.csv"

    def _setup_signal_handler(self) -> None:
        def handler(sig: int, frame: Any) -> None:
            print("\n[INTERRUPT] Acquisition interrupted by user (SIGINT). Safely flushing and closing...")
            self._interrupted = True

        signal.signal(signal.SIGINT, handler)

    def write_manifest(self, status: str = "IN_PROGRESS") -> Path:
        manifest_path = self.run_dir / "manifest.json"
        
        # Load existing if present to keep all conditions
        data: dict[str, Any] = {}
        if manifest_path.exists():
            try:
                with open(manifest_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except Exception:
                data = {}

        data.update({
            "run_id": self.run_id,
            "physical_hardware": True,
            "sensor_address": hex(AS7341_I2C_ADDRESS),
            "production_driver": "adafruit-circuitpython-as7341",
            "package_version": REQUIRED_ADAFRUIT_VERSION,
            "i2c_bus_id": I2C_BUS_ID,
            "timestamp_start": data.get("timestamp_start", datetime.now(timezone.utc).isoformat()),
            "status": status,
            "configuration_type": "EXPERIMENTAL" if self.is_experimental else "PRODUCTION",
            "operator_id": self.operator_id,
            "setup_notes": self.setup_notes,
            "ambient_notes": self.ambient_notes,
            "integration_time_ms": self.integration_time_ms,
            "gain": self.gain,
            "sampling_interval_ms": self.interval_ms,
            "spectral_channels": list(SPECTRAL_CHANNELS),
            "provenance": get_git_provenance(),
        })

        if status in ("COMPLETED", "INTERRUPTED", "FAILED"):
            data["timestamp_end"] = datetime.now(timezone.utc).isoformat()

        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

        return manifest_path

    def run_capture(self) -> list[ValidationSample]:
        # 1. Verify Adafruit version
        ver_ok, ver_msg = check_adafruit_version()
        if not ver_ok:
            raise RuntimeError(f"ABORT: Required library not met: {ver_msg}")

        self._setup_signal_handler()
        self.write_manifest("IN_PROGRESS")

        print("==================================================")
        print(" HemoPi AS7341 Physical Sensor Capture Engine     ")
        print("==================================================")
        print(f"Condition:        {self.condition}")
        print(f"Samples:          {self.sample_count}")
        print(f"Interval:         {self.interval_ms} ms")
        print(f"Integration Time: {self.integration_time_ms} ms")
        print(f"Gain:             {self.gain}x")
        print(f"Raw Output File:  {self.raw_file}")
        print("--------------------------------------------------")

        samples: list[ValidationSample] = []

        try:
            # 2. Connect physical I2C Bus and production AS7341 sensor
            self._bus = I2CBus(I2C_BUS_ID)
            shared_bus = self._bus.connect()

            self._sensor = AS7341Sensor(
                shared_bus=shared_bus,
                integration_time_ms=self.integration_time_ms,
                gain=self.gain,
            )
            self._sensor.initialize()

            # Open raw CSV file immutably
            with open(self.raw_file, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(RAW_CSV_COLUMNS)

                for idx in range(1, self.sample_count + 1):
                    if self._interrupted:
                        break

                    t_start = time.perf_counter()
                    timestamp_iso = datetime.now(timezone.utc).isoformat()

                    channels: dict[str, int] = {}
                    is_valid = True
                    sensor_status = "OK"

                    try:
                        reading = self._sensor.read_sample()
                        channels = reading.channels
                        if reading.saturated:
                            sensor_status = "SATURATED"
                    except Exception as exc:
                        is_valid = False
                        sensor_status = f"ERROR: {exc}"
                        channels = {ch: 0 for ch in SPECTRAL_CHANNELS}

                    duration_ms = (time.perf_counter() - t_start) * 1000.0

                    sample = ValidationSample(
                        timestamp=timestamp_iso,
                        sample_index=idx,
                        condition=self.condition,
                        channels=channels,
                        acquisition_duration_ms=duration_ms,
                        valid=is_valid,
                        sensor_status=sensor_status,
                        integration_time=self.integration_time_ms,
                        gain=self.gain,
                    )

                    samples.append(sample)
                    writer.writerow(sample.to_csv_row())
                    f.flush()

                    print(
                        f"Sample {idx:02d}/{self.sample_count}: "
                        f"415nm={channels.get('415', 0):5d}, "
                        f"555nm={channels.get('555', 0):5d}, "
                        f"680nm={channels.get('680', 0):5d} | "
                        f"{duration_ms:5.1f}ms [{sensor_status}]"
                    )

                    if idx < self.sample_count and not self._interrupted:
                        time.sleep(self.interval_ms / 1000.0)

            final_status = "INTERRUPTED" if self._interrupted else "COMPLETED"
            self.write_manifest(final_status)
            print("--------------------------------------------------")
            print(f"Acquisition {final_status}. Captured {len(samples)} physical readings.")
            return samples

        except Exception as exc:
            self.write_manifest("FAILED")
            print(f"[FATAL ERROR] Physical acquisition failed: {exc}")
            raise
        finally:
            self.close()

    def close(self) -> None:
        if self._sensor is not None:
            try:
                self._sensor.close()
            except Exception:
                pass
            self._sensor = None

        if self._bus is not None:
            try:
                self._bus.close()
            except Exception:
                pass
            self._bus = None

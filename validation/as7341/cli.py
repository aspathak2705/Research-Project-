from __future__ import annotations

import argparse
import sys
from pathlib import Path

from validation.as7341.capture import PhysicalCaptureEngine
from validation.as7341.config import (
    CONDITION_CONTROLLED_RESPONSE,
    CONDITION_DARK,
    CONDITION_REFERENCE_LIGHT,
    CONDITION_TEMPORAL_STABILITY,
    DEFAULT_INTERVAL_MS,
    DEFAULT_SAMPLE_COUNT,
    OUTPUTS_DIR,
    PRODUCTION_GAIN,
    PRODUCTION_INTEGRATION_TIME_MS,
)
from validation.as7341.device_check import run_preflight
from validation.as7341.report import ValidationReportGenerator

def main() -> None:
    parser = argparse.ArgumentParser(
        description="HemoPi AS7341 Physical Validation CLI Harness",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # Subcommand: check
    check_parser = subparsers.add_parser("check", help="Verify physical hardware & software prerequisites")
    check_parser.add_argument("--require-physical", action="store_true", default=True, help="Enforce physical sensor ACK (default: True)")

    # Subcommand: capture
    cap_parser = subparsers.add_parser("capture", help="Acquire real measurements from physical AS7341")
    cap_parser.add_argument("--condition", required=True, choices=[CONDITION_DARK, CONDITION_REFERENCE_LIGHT, CONDITION_CONTROLLED_RESPONSE, CONDITION_TEMPORAL_STABILITY], help="Physical optical condition")
    cap_parser.add_argument("--samples", type=int, default=DEFAULT_SAMPLE_COUNT, help=f"Number of samples (default: {DEFAULT_SAMPLE_COUNT})")
    cap_parser.add_argument("--duration-seconds", type=float, default=None, help="Continuous capture duration in seconds (overrides --samples if provided)")
    cap_parser.add_argument("--interval-ms", type=int, default=DEFAULT_INTERVAL_MS, help=f"Interval between samples in ms (default: {DEFAULT_INTERVAL_MS})")
    cap_parser.add_argument("--integration-ms", type=float, default=PRODUCTION_INTEGRATION_TIME_MS, help=f"Sensor integration time in ms (Production: {PRODUCTION_INTEGRATION_TIME_MS})")
    cap_parser.add_argument("--gain", type=int, default=PRODUCTION_GAIN, help=f"Sensor gain multiplier (Production: {PRODUCTION_GAIN}x)")
    cap_parser.add_argument("--experimental-config", action="store_true", default=False, help="Explicit flag required if modifying integration time or gain from production standards")
    cap_parser.add_argument("--operator", type=str, default="not_recorded", help="Operator identifier")
    cap_parser.add_argument("--notes", type=str, default="not_recorded", help="Setup and optical geometry notes")
    cap_parser.add_argument("--run-dir", type=str, default=None, help="Append capture to existing validation run directory")

    # Subcommand: analyze
    ana_parser = subparsers.add_parser("analyze", help="Process raw validation captures and build evidence package")
    ana_parser.add_argument("--run-dir", required=True, help="Path to run directory or run directory name under validation/outputs")

    args = parser.parse_args()

    if args.command == "check":
        print("Running preflight hardware check...")
        res = run_preflight(require_physical=args.require_physical)
        if not res["overall_ok"]:
            print("ERROR: Hardware preflight check failed. See diagnostics above.")
            sys.exit(1)
        print("PASS: Preflight hardware environment verified.")
        sys.exit(0)

    elif args.command == "capture":
        # Check configuration lock
        is_experimental = (
            abs(args.integration_ms - PRODUCTION_INTEGRATION_TIME_MS) > 1e-3 or
            args.gain != PRODUCTION_GAIN
        )

        if is_experimental and not args.experimental_config:
            print("ERROR: Non-production configuration detected.")
            print(f"Requested: {args.integration_ms}ms, {args.gain}x | Production: {PRODUCTION_INTEGRATION_TIME_MS}ms, {PRODUCTION_GAIN}x")
            print("Official validation requires production configuration. To run non-production tests, pass --experimental-config.")
            sys.exit(1)

        # Calculate sample count if duration provided
        final_sample_count = args.samples
        if args.duration_seconds is not None and args.duration_seconds > 0:
            final_sample_count = max(1, int(args.duration_seconds * 1000.0 / args.interval_ms))

        existing_path = Path(args.run_dir) if args.run_dir else None
        engine = PhysicalCaptureEngine(
            condition=args.condition,
            sample_count=final_sample_count,
            interval_ms=args.interval_ms,
            integration_time_ms=args.integration_ms,
            gain=args.gain,
            is_experimental=is_experimental,
            operator_id=args.operator,
            setup_notes=args.notes,
            existing_run_dir=existing_path,
        )
        try:
            engine.run_capture()
            print(f"\nCaptured raw condition successfully to: {engine.run_dir}")
        except Exception as exc:
            print(f"\nCAPTURE FAILURE: {exc}")
            sys.exit(1)

    elif args.command == "analyze":
        target_dir = Path(args.run_dir)
        if not target_dir.exists():
            target_dir = OUTPUTS_DIR / args.run_dir
        if not target_dir.exists():
            print(f"ERROR: Run directory not found: {args.run_dir}")
            sys.exit(1)

        generator = ValidationReportGenerator(target_dir)
        try:
            report_file = generator.run_pipeline()
            print(f"\nEvidence package and report generated successfully:\n{report_file}")
        except Exception as exc:
            print(f"\nANALYSIS FAILURE: {exc}")
            sys.exit(1)

if __name__ == "__main__":
    main()

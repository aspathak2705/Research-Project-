# Portable Hemoglobin Analyzer - Milestone 0

Biomedical data acquisition platform for Raspberry Pi 4 using MAX30102 and AS7341.

## Milestone 0 scope

- Acquire synchronized optical sensor data
- Validate signal quality before storage
- Save patient-wise CSV sessions automatically
- Queue and sync session files to Google Drive

No ML, prediction, dashboards, or reporting in this milestone.

## Current implementation

This repo contains a runnable milestone skeleton with:

- device state machine
- mock-friendly hardware layer
- signal quality validator
- patient/session folder manager
- CSV writer
- offline-first Google Drive sync queue

Real Raspberry Pi drivers and Google Drive credentials can be plugged into existing module boundaries without changing workflow code.

## Quick start

```bash
python main.py --patient "Test Patient" --samples 24
```

Mock mode is enabled by default. Output files land under `data/raw/Patient_Data/`.

## Project structure

```text
portable-hemo-ai/
├── main.py
├── config/
├── device/
├── hardware/
├── processing/
├── storage/
├── cloud/
├── utils/
├── data/
└── tests/
```

## Environment variables

- `HEMO_DATA_ROOT` - override local data directory
- `HEMO_UPLOAD_QUEUE` - override upload queue directory
- `HEMO_GOOGLE_DRIVE_ROOT` - drive root folder name
- `HEMO_MOCK_MODE` - `true` or `false`
- `HEMO_LOG_LEVEL` - `DEBUG`, `INFO`, etc.

## Next hardware steps

1. Replace mock read methods in `hardware/max30102.py` and `hardware/as7341.py`.
2. Add real I2C init in `hardware/i2c_bus.py`.
3. Add Google API credential flow in `cloud/google_drive.py`.


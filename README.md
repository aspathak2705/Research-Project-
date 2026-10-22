# HemoPi — Portable Non-Invasive Hemoglobin Research Platform

Integrated biomedical data acquisition system for Raspberry Pi 3 Model B and Raspberry Pi 4 Model B using AMS AS7341 11-channel spectral sensor and Maxim MAX30102 pulse oximetry sensor, connected to a FastAPI backend and Flutter cross-platform companion application.

---

## 1. System Architecture

```text
Physical Hardware (Raspberry Pi 3 Model B / Pi 4 Model B)
├── I2C Bus 1 (/dev/i2c-1)
│   ├── AS7341 (0x39)  <-- adafruit-circuitpython-as7341==1.2.27 (Official Driver)
│   └── MAX30102 (0x57)<-- smbus2 PPG Driver
├── Linux Networking (NetworkManager / nmcli, Avahi mDNS -> hemopi.local)
├── FastAPI Backend Service (Uvicorn / systemd on port 8000)
│   ├── /api/health          (Liveness and safety readiness)
│   ├── /api/device/status   (Hardware diagnostics and presence)
│   ├── /api/network/*       (Wi-Fi scan, connect, disconnect, status)
│   ├── /api/patients        (Subject profile management)
│   └── /api/sessions        (Acquisition safety gate - HTTP 409 when unvalidated)
└── Flutter Mobile App (hemopi_app)
    ├── Multi-Tier Device Discovery (Subnet Scan, mDNS, Direct IP Override, SQLite Pair Cache)
    ├── Hardware Status Dashboard & Pre-Flight Checks
    └── Patient & Research Workflow Management
```

---

## 2. Research Safety & Data Integrity Standards

1. **Zero Synthetic Data**: Real hardware measurements only. Fake spectral data, simulated patient readings, and synthetic sensor streams are prohibited.
2. **Strict Acquisition Gating**: Research sessions are strictly gated until physical calibration and validation are achieved (`physically_validated=false`, `research_ready=false`). Unvalidated sessions return `HTTP 409 ACQUISITION_NOT_READY`.
3. **Separation of Concerns**: API reachability (`api=ok`) is distinct from sensor physical validation. Reachability does not bypass hardware safety checks.
4. **Verified Production Drivers**: Custom AS7341 SMUX driver deprecated in favor of official `adafruit-circuitpython-as7341==1.2.27`.

---

## 3. Quick Start & Verification

### Python Environment
```bash
python -m venv .venv
# Linux / Raspberry Pi:
source .venv/bin/activate
# Windows:
# .venv\Scripts\activate
pip install -r backend/requirements.txt
```

### Run Automated Test Suites
```bash
# Core hardware and validator tests (55 tests)
python -m pytest tests -v

# Backend API endpoint and connectivity tests (14 tests)
python -m pytest backend/tests -v
```

### Run Flutter Client Tests
```bash
cd hemopi_app
flutter analyze
flutter test
```

---

## 4. Full Deployment & Operations
For physical wiring diagrams, clean Raspberry Pi 3 OS imaging instructions, systemd deployment, mobile direct IP pairing, and sensor verification steps, refer to:
[Deployment & Operations Guide](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/docs/deployment_and_operations.md)

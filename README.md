# HemoPi — Portable Non-Invasive Hemoglobin Research Platform

Integrated biomedical data acquisition system for Raspberry Pi 4 Model B using AMS AS7341 11-channel spectral sensor and Maxim MAX30102 pulse oximetry sensor, connected to a FastAPI backend and Flutter cross-platform companion application.

---

## 1. System Architecture

```text
Physical Hardware (Raspberry Pi 4 Model B)
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
    ├── Device Discovery & Wi-Fi Provisioning
    ├── Hardware Status Dashboard
    └── Patient & Research Workflow Management
```

---

## 2. Research Safety & Data Integrity Standards

1. **Zero Synthetic Data**: Real hardware measurements only. Fake spectral data, simulated patient readings, and synthetic sensor streams are prohibited.
2. **Strict Acquisition Gating**: Research sessions are strictly gated until physical calibration and validation are achieved (`physically_validated=false`, `research_ready=false`). Unvalidated sessions return `HTTP 409 ACQUISITION_NOT_READY`.
3. **Verified Production Drivers**: Custom AS7341 SMUX driver deprecated in favor of official `adafruit-circuitpython-as7341==1.2.27`.

---

## 3. Quick Start & Verification

### Python Environment
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Run Automated Test Suites
```bash
# Core hardware and validator tests
python -m unittest discover -s tests

# Backend API endpoint tests
python -m unittest discover -s backend/tests
```

### Run Flutter Client Tests
```bash
cd hemopi_app
flutter analyze
flutter test
```

### Full Deployment & Operations
For physical wiring diagrams, systemd deployment, network manager configuration, and troubleshooting steps, refer to:
[Deployment & Operations Guide](file:///c:/Users/athar/OneDrive/Documents/projects/Research-Project-/docs/deployment_and_operations.md)

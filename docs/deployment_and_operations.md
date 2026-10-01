# HemoPi Deployment and Operations Guide

This guide covers physical hardware setup, networking, backend services, Flutter mobile app configuration, and end-to-end operational procedures for the HemoPi Portable Non-Invasive Hemoglobin Analyzer research system.

---

## 1. Hardware Architecture & Wiring

### Sensors & Addresses
- **AS7341 11-Channel Spectral Sensor**: I2C Address `0x39`
- **MAX30102 High-Sensitivity Pulse Oximeter & PPG Sensor**: I2C Address `0x57`
- **Host Controller**: Raspberry Pi 4 Model B (Rev 1.5, Debian 13/Trixie)

### Pin Connections (Raspberry Pi 40-Pin Header)
| Sensor Pin | Function | Raspberry Pi Header Pin | RPi Physical Pin Number |
|---|---|---|---|
| **VCC (3.3V)** | Power | 3V3 Power | Pin 1 |
| **GND** | Ground | Ground | Pin 6 / Pin 9 |
| **SDA** | I2C Data | GPIO 2 (I2C1 SDA) | Pin 3 |
| **SCL** | I2C Clock | GPIO 3 (I2C1 SCL) | Pin 5 |

*Note: Both AS7341 and MAX30102 share the common I2C bus 1 pins with hardware pull-up resistors on the sensor breakout boards.*

---

## 2. Raspberry Pi OS & I2C Configuration

1. Enable I2C interface via `raspi-config` or `/boot/firmware/config.txt`:
   ```bash
   sudo raspi-config nonint do_i2c 0
   ```
2. Verify `/dev/i2c-1` presence:
   ```bash
   ls -la /dev/i2c-1
   ```
3. Run I2C bus scan:
   ```bash
   sudo i2cdetect -y 1
   ```
   **Expected output**:
   - `0x39` (AS7341) detected
   - `0x57` (MAX30102) detected

---

## 3. Host Network & mDNS Setup (`hemopi.local`)

1. Set the system hostname:
   ```bash
   sudo hostnamectl set-hostname hemopi
   ```
2. Ensure `/etc/hosts` contains:
   ```text
   127.0.0.1       localhost
   127.0.1.1       hemopi hemopi.local
   ```
3. Install and enable Avahi mDNS daemon:
   ```bash
   sudo apt-get update && sudo apt-get install -y avahi-daemon avahi-utils
   sudo systemctl enable avahi-daemon
   sudo systemctl start avahi-daemon
   ```
4. Verify local resolution:
   ```bash
   ping -c 2 hemopi.local
   ```

---

## 4. Production Python Runtime & Dependency Isolation

HemoPi requires Python 3.10+ (Raspberry Pi runs Python 3.13) with official Adafruit CircuitPython AS7341 drivers.

1. Create production virtual environment:
   ```bash
   cd /home/pi/Research-Project-
   python3 -m venv .venv
   source .venv/bin/activate
   ```
2. Install production dependencies:
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   ```
3. Verify production AS7341 library version:
   ```bash
   python -c "import adafruit_as7341; print(adafruit_as7341.__version__)"
   # Output MUST BE: 1.2.27
   ```

---

## 5. Systemd Service Deployment

A dedicated systemd unit manages the backend API service across reboots:

1. Copy service file:
   ```bash
   sudo cp hemopi-backend.service /etc/systemd/system/
   sudo systemctl daemon-reload
   ```
2. Enable and start the service:
   ```bash
   sudo systemctl enable hemopi-backend.service
   sudo systemctl start hemopi-backend.service
   ```
3. Verify status:
   ```bash
   sudo systemctl status hemopi-backend.service
   ```
4. Check journal logs:
   ```bash
   journalctl -u hemopi-backend.service -f
   ```

---

## 6. Network Manager & Wi-Fi Provisioning

The HemoPi backend provides structured APIs for Wi-Fi management using `NetworkManager` (`nmcli`):
- `GET /api/network/status`: Current IP, hostname, connection state.
- `GET /api/network/wifi`: Scans available Wi-Fi access points.
- `POST /api/network/wifi/connect`: Safe, parameterized connection via `nmcli device wifi connect <SSID> password <PASS>`. Passwords are never logged or returned.
- `POST /api/network/wifi/disconnect`: Disconnects `wlan0`.

---

## 7. SSH Remote Administration

- Connect via mDNS:
  ```bash
  ssh pi@hemopi.local
  ```
- Or connect via IP:
  ```bash
  ssh pi@<IP_ADDRESS>
  ```
*Security notice: Do not hardcode SSH passwords or commit private keys to the repository.*

---

## 8. Research Acquisition Gating Architecture

HemoPi strictly separates API availability, hardware presence, and research acquisition readiness:
- **API Status**: Responds `200 OK` on `/api/health` and `/api/device/status`.
- **Sensors**: Reports actual detection (`present=true`) for both `0x39` and `0x57`.
- **Acquisition Safety Gate**:
  - `physically_validated`: `false`
  - `research_ready`: `false`
  - When unvalidated, `POST /api/sessions` rejects acquisition with **HTTP 409** and error `ACQUISITION_NOT_READY`.
  - **NON-NEGOTIABLE**: Synthetic data, fallback mocking, and bypassing this gate are strictly forbidden in research builds.

---

## 9. Flutter Mobile Application

The Flutter client (`hemopi_app`) connects to `http://hemopi.local:8000`:
- **Android Networking**: `AndroidManifest.xml` specifies `android.permission.INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, and `usesCleartextTraffic="true"` for local HTTP communication.
- **Run Smoke Tests**:
  ```bash
  cd hemopi_app
  flutter analyze
  flutter test
  ```
- **Build APK**:
  ```bash
  flutter build apk --debug
  ```

---

## 10. Troubleshooting Guide

| Issue | Potential Cause | Remediation |
|---|---|---|
| `ping hemopi.local` fails | Avahi daemon not running or router blocks mDNS | Run `sudo systemctl restart avahi-daemon`. Connect via direct IP (`hostname -I`). |
| `0x39` missing in `i2cdetect` | Wiring issue or loose I2C connection on AS7341 | Check SDA/SCL jumpers, 3.3V power, and solder joints. |
| `0x57` missing in `i2cdetect` | MAX30102 power or pull-up missing | Check VCC/GND. MAX30102 requires 3.3V. |
| Backend returns HTTP 409 on session start | Physical validation gate active | This is expected behavior. Sensor validation must be completed before acquisition opens. |
| AS7341 returns near-zero in legacy driver | SMUX sequencer mismatch in custom code | Custom driver deprecated; production driver now wraps official `adafruit-circuitpython-as7341==1.2.27`. |

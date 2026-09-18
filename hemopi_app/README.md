# HemoPi — Portable Non-Invasive Hemoglobin Analyzer (Flutter App Foundation)

## Phase 1 App Architecture & Scope

This Flutter application provides the mobile user interface for the **HemoPi** biomedical optical sensor acquisition system.

### Key Architecture Design Principles
1. **Zero Mock / Synthetic Sensor Data Policy**:
   - The application **NEVER** generates, interpolates, or simulates MAX30102 PPG or AS7341 multispectral values.
   - All optical measurements displayed by the app originate strictly from physical I2C sensor hardware connected to the Raspberry Pi acquisition unit.
2. **Local Portability First**:
   - Designed for local network discovery (`hemopi.local`) and Wi-Fi hotspot setup without requiring cloud services or external backends.
3. **Scientific Honesty & Deferred Gating**:
   - Sensor validation states for physical MAX30102 PPG (I2C `0x57`) and AS7341 8-channel spectral data (I2C `0x39`) explicitly state **"Pending Phase 3/4 Physical Validation"**.
   - Hemoglobin (g/dL) concentrations are strictly omitted until clinical calibration models are integrated.

---

## Screen Directory Map

- `DeviceDiscoveryScreen`: Scans and discovers `hemopi.local`.
- `WifiSetupScreen`: Prepares portable Wi-Fi connection parameters.
- `ConnectionValidationScreen`: Multi-layer diagnostic network check.
- `DashboardScreen`: Central Hub displaying system readiness and shortcuts.
- `DeviceStatusScreen`: Detailed status of Pi hardware and physical sensor presence.
- `PatientListScreen`: subject registry management.
- `AddPatientScreen`: Form to register new subjects (ID, age, sex, notes).
- `PatientDetailScreen`: Subject profile and session trigger.
- `MeasurementSetupScreen`: Hardware pre-flight check and acquisition gating.
- `MeasurementProgressScreen`: Real-time streaming status during physical sensor acquisition.
- `SessionResultScreen`: Summary of raw CSV counts and session metadata.
- `SessionHistoryScreen`: Log of all acquisition sessions recorded on hardware.
- `SessionDetailsScreen`: Details of individual research sessions.
- `DiagnosticsScreen`: Rejection log inspection and I2C hardware bus status.

---

## Running Analysis & Tests

```bash
cd hemopi_app
flutter analyze
flutter test
```

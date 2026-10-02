# TASK 8A — HEMOPI DEVICE PROVISIONING, WI-FI SETUP, DISCOVERY & AUTOMATIC RECONNECTION
## Completion & Architectural Walkthrough Report

**Date:** 2026-10-02  
**Scope:** Device Provisioning, Wi-Fi Setup, Discovery & Automatic Reconnection (Task 8A)  
**Status:** COMPLETE & VERIFIED

---

### 1. Executive Summary

Task 8A delivers the complete, resilient networking and provisioning bridge between the HemoPi Raspberry Pi 4 hardware instrument and the Flutter Android application:

1. **First-Time Provisioning**:
   - Zero-config discovery starts on launch (*"Finding your HemoPi..."*).
   - If not yet connected to clinic Wi-Fi, the user taps **"Set Up HemoPi Wi-Fi"**.
   - HemoPi executes an on-device Wi-Fi scan using Linux NetworkManager (`nmcli`), returning SSIDs, sorted signal strengths, and security statuses.
   - User inputs credentials in a clean modal dialog.
   - Credentials are submitted to HemoPi via `/api/network/wifi/connect`.
   - **Credentials are saved directly on the Raspberry Pi** by NetworkManager in a persistent network profile.
   - The Pi joins the clinic network, returning its assigned IP address.
   - The app verifies identity, saves pairing metadata to local SQLite (`paired_devices` table), and enters the dashboard.

2. **Every Future Use (Automatic Reconnection)**:
   - When powered on, the Pi automatically reconnects to the saved Wi-Fi network without requiring re-entry of passwords.
   - The app's background auto-reconnect engine automatically locates the paired instrument across candidates (cached host, `hemopi.local:8000`, setup gateway `192.168.4.1:8000`).
   - The user sees *"Searching"* $\to$ *"Found"* $\to$ *"Connected"* without typing IP addresses, ports, or protocols.

3. **Connection Loss & Recovery**:
   - If Wi-Fi signal drops or the instrument temporarily restarts, the app enters `connectionLost` and automatically begins periodic background reconnection (`reconnecting`) every 4 seconds.
   - A dedicated **"Change Wi-Fi Network"** flow is available in both the discovery screen and instrument settings to reconfigure Wi-Fi without wiping local patient or measurement data.

4. **Safety & Biomedical Research Invariants**:
   - Zero synthetic biomedical data.
   - Sensor acquisition gates remain active (`physically_validated=false`, `research_ready=false`, HTTP 409). Reachability is explicitly separated from research readiness.

---

### 2. Architecture & Connection State Model

```
                    ┌────────────────────────┐
                    │      POWER ON PI       │
                    └───────────┬────────────┘
                                │
               Has saved Wi-Fi? │
                     ┌──────────┴──────────┐
                  NO │                     │ YES
                     ▼                     ▼
          ┌────────────────────┐ ┌────────────────────┐
          │ Setup AP / Gateway │ │ Auto-join Wi-Fi    │
          │ (192.168.4.1:8000) │ │ (NetworkManager)   │
          └──────────┬─────────┘ └─────────┬──────────┘
                     │                     │
                     ▼                     ▼
          ┌────────────────────┐ ┌────────────────────┐
          │ App Scans & Saves  │ │ App Auto-Discovers │
          │ Credentials to Pi  │ │ Paired Device ID   │
          └──────────┬─────────┘ └─────────┬──────────┘
                     │                     │
                     └──────────┬──────────┘
                                │
                                ▼
                   ┌────────────────────────┐
                   │    CONNECTED & PAIRED   │
                   └────────────────────────┘
```

#### Detailed State Lifecycle
- **`notConfigured`**: App has no paired device. Prompts user to "Find Nearby HemoPi" or "Set Up HemoPi Wi-Fi".
- **`searching`**: Active probe across candidate endpoints (`cached IP`, `hemopi.local:8000`, `192.168.4.1:8000`).
- **`found`**: Endpoint responded to `/api/health`.
- **`connecting`**: Querying device metadata and sensor baseline.
- **`connected`**: Valid session established. Persistent pairing saved in SQLite.
- **`connectionLost`**: Device ceased responding to health ping.
- **`reconnecting`**: Periodic automated retry background loop (every 4 seconds).
- **`error`**: NetworkManager error or invalid credentials reported with clear human language.

---

### 3. Backend & Firmware Changes

1. **Device Identity in Schema (`backend/schemas/device.py`)**:
   - Added `device_id: Optional[str] = "HemoPi-001"` and `device_name: Optional[str] = "HemoPi Portable Analyzer"` to `HealthCheckResponse` and `DeviceStatusResponse`.
   - Allows client pairing by immutable hardware ID rather than volatile IP address.

2. **Backend Service Layer (`backend/services/device_service.py`)**:
   - Updated `get_device_status()` and `get_health_check()` to serve stable `device_id` and `device_name`.
   - Retained strict research gating (`reason: AS7341_PHYSICAL_VALIDATION_PENDING`, `acquisition_ready: false`).

3. **Backend NetworkManager Integration (`backend/services/network_manager.py`)**:
   - `list_wifi_networks()` uses `nmcli -t -f SSID,SIGNAL,SECURITY device wifi list` to fetch real physical Wi-Fi networks visible to the Pi.
   - `connect_wifi(ssid, password)` invokes `nmcli device wifi connect` which stores connection profiles persistently in `/etc/NetworkManager/system-connections/`.
   - Passwords are never logged, returned in API responses, or stored in app preferences.

---

### 4. Flutter Client Changes

1. **Persistent Device Pairing (`local_database_service.dart`)**:
   - Upgraded SQLite schema to version 2 with `paired_devices` table:
     ```sql
     CREATE TABLE IF NOT EXISTS paired_devices (
       device_id TEXT PRIMARY KEY,
       device_name TEXT NOT NULL,
       last_known_host TEXT NOT NULL,
       paired_at TEXT NOT NULL,
       is_active INTEGER NOT NULL
     );
     ```
   - Added `savePairedDevice()`, `getActivePairedDevice()`, and `unpairAllDevices()` methods.

2. **Multi-Candidate Discovery & Background Auto-Reconnect (`device_service.dart`)**:
   - `HttpDeviceService` checks paired host first, then falls back to mDNS (`hemopi.local:8000`) and AP gateway (`192.168.4.1:8000`).
   - Implemented `startAutoReconnect()` and `stopAutoReconnect()` using a periodic timer that only runs when connection is lost, preserving battery.

3. **Structured Wi-Fi Service (`wifi_service.dart`)**:
   - Added `WifiConnectResult` returning typed statuses and user-friendly error messages (e.g., *"Incorrect Wi-Fi password"*, *"Wi-Fi network was not found"*).
   - Sorted networks by signal strength descending.

4. **Clinician Onboarding Screen (`device_discovery_screen.dart`)**:
   - Dual primary actions: **"Find Nearby HemoPi"** and **"Set Up HemoPi Wi-Fi"**.
   - Distinct visual state cards with semantic badges: Green for Connected, Amber for Searching/Reconnecting, Red for Offline.
   - Displays paired device ID when connected.

5. **Wi-Fi Configuration Screen (`wifi_setup_screen.dart`)**:
   - Clinical UI for scanning, inspecting signal strength (Strong / Medium / Weak), and entering password.
   - On successful connection, immediately triggers device pairing and navigates to Dashboard.

6. **Device Status Screen (`device_status_screen.dart`)**:
   - Added direct **"Change Wi-Fi Network"** button for quick network recovery.

---

### 5. Verification Results

1. **Backend Automated Tests**:
   - Executed: `python -m pytest backend/tests/test_backend.py`
   - Result: **10 passed in 0.66s** (includes health check, device status, identity assertions, network status, Wi-Fi scan, and error handling).

2. **Flutter Static Analysis**:
   - Executed: `dart analyze`
   - Result: **No issues found!** (0 errors, 0 warnings, 0 lints).

3. **Flutter Widget & Smoke Tests**:
   - Executed: `flutter test`
   - Result: **All tests passed!** (1/1 passing with clean teardown of timers).

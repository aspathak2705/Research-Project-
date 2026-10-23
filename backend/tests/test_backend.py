import unittest
import time
from unittest.mock import patch
import subprocess
from fastapi.testclient import TestClient
from backend.app import app

class TestBackendEndpoints(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_root_endpoint(self):
        res = self.client.get("/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["service"], "HemoPi API")

    def test_health_endpoint(self):
        res = self.client.get("/api/health")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["api"], "ok")
        self.assertEqual(data["device_id"], "HemoPi-001")
        self.assertEqual(data["device_name"], "HemoPi Portable Analyzer")
        self.assertFalse(data["acquisition_ready"])
        self.assertEqual(data["reason"], "AS7341_PHYSICAL_VALIDATION_PENDING")
        self.assertTrue(data["sensors"]["max30102"]["present"])
        self.assertFalse(data["sensors"]["as7341"]["research_ready"])

    def test_device_status(self):
        res = self.client.get("/api/device/status")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["device_id"], "HemoPi-001")
        self.assertEqual(data["device_name"], "HemoPi Portable Analyzer")
        self.assertTrue(data["max30102"]["present"])
        self.assertTrue(data["max30102"]["research_ready"])
        self.assertTrue(data["as7341"]["present"])
        self.assertFalse(data["as7341"]["research_ready"])

    def test_wifi_scan_fallback_when_nmcli_absent(self):
        res = self.client.get("/api/network/wifi")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("status", data)
        self.assertIn("code", data)

    @patch("subprocess.run")
    def test_wifi_scan_success(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(
            args=["nmcli"],
            returncode=0,
            stdout="Home_WiFi:85:WPA2\nLab_WiFi:90:WPA2\n"
        )
        res = self.client.get("/api/network/wifi")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["status"], "ok")
        self.assertEqual(len(data["networks"]), 2)
        self.assertEqual(data["networks"][0]["ssid"], "Home_WiFi")

    @patch("subprocess.run")
    def test_wifi_connect_invalid_credentials(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(
            args=["nmcli"],
            returncode=1,
            stdout="",
            stderr="Error: Secrets were required, but not provided (authentication failed)"
        )
        res = self.client.post("/api/network/wifi/connect", json={
            "ssid": "Home_WiFi",
            "password": "wrongpassword"
        })
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["status"], "error")
        self.assertEqual(data["code"], "INVALID_CREDENTIALS")

    def test_patients_crud_and_duplicate(self):
        patient_id = f"TEST_PATIENT_{int(time.time() * 1000)}"
        # Initial creation
        create_res = self.client.post("/api/patients", json={
            "patient_id": patient_id,
            "age": 28,
            "sex": "Female",
            "notes": "Research participant"
        })
        self.assertEqual(create_res.status_code, 200)
        self.assertEqual(create_res.json()["patient_id"], patient_id)

        # Duplicate creation attempt
        dup_res = self.client.post("/api/patients", json={
            "patient_id": patient_id
        })
        self.assertEqual(dup_res.status_code, 409)

        # Retrieval
        get_res = self.client.get(f"/api/patients/{patient_id}")
        self.assertEqual(get_res.status_code, 200)
        self.assertEqual(get_res.json()["patient_id"], patient_id)

    def test_session_gating(self):
        res = self.client.post("/api/sessions", json={"patient_id": "TEST_PATIENT_999"})
        self.assertEqual(res.status_code, 409)
        self.assertIn("ACQUISITION_NOT_READY", res.json()["detail"])

    def test_network_status_endpoint(self):
        res = self.client.get("/api/network/status")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("hostname", data)
        self.assertIn("ip_address", data)
        self.assertIn("connection_state", data)

    def test_wifi_disconnect_fallback(self):
        res = self.client.post("/api/network/wifi/disconnect")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("status", data)
        self.assertIn("code", data)

    @patch("subprocess.run")
    def test_network_connection_state_parsing_exact(self, mock_run):
        # 1. State 'disconnected' must not be misparsed as 'connected'
        mock_run.return_value = subprocess.CompletedProcess(
            args=["nmcli"],
            returncode=0,
            stdout="STATE         CONNECTIVITY  WIFI-HW  WIFI     WWAN-HW  WWAN\ndisconnected  none          enabled  enabled  missing  enabled\n"
        )
        from backend.services.network_manager import NetworkManagerService
        state = NetworkManagerService.get_connection_state()
        self.assertEqual(state, "DISCONNECTED")

        # 2. State 'connected'
        mock_run.return_value = subprocess.CompletedProcess(
            args=["nmcli"],
            returncode=0,
            stdout="STATE      CONNECTIVITY  WIFI-HW  WIFI     WWAN-HW  WWAN\nconnected  full          enabled  enabled  missing  enabled\n"
        )
        self.assertEqual(NetworkManagerService.get_connection_state(), "CONNECTED")

    @patch("subprocess.run")
    def test_wifi_scan_ssid_with_colons_and_escapes(self, mock_run):
        # nmcli with -e yes escapes colons in SSIDs as \:
        mock_run.return_value = subprocess.CompletedProcess(
            args=["nmcli"],
            returncode=0,
            stdout="Clinic\\:Guest:75:WPA2 802.1X\nSimpleWiFi:90:WPA2\n--:40:WPA2\n"
        )
        from backend.services.network_manager import NetworkManagerService
        result = NetworkManagerService.list_wifi_networks()
        self.assertEqual(result["status"], "ok")
        networks = result["networks"]
        self.assertEqual(len(networks), 2)
        self.assertEqual(networks[0]["ssid"], "Clinic:Guest")
        self.assertEqual(networks[0]["signal_strength"], 75)
        self.assertTrue(networks[0]["secured"])
        self.assertEqual(networks[1]["ssid"], "SimpleWiFi")

    @patch("subprocess.run")
    def test_interface_specific_ip_retrieval(self, mock_run):
        # Test interface specific query returns wlan0 IP without loopback
        mock_run.return_value = subprocess.CompletedProcess(
            args=["nmcli"],
            returncode=0,
            stdout="192.168.1.150/24\n"
        )
        from backend.services.network_manager import NetworkManagerService
        ip = NetworkManagerService.get_ip_address(interface="wlan0")
        self.assertEqual(ip, "192.168.1.150")

    @patch("subprocess.run")
    def test_wifi_connect_authorization_pin(self, mock_run):
        import os
        from backend.services.network_manager import NetworkManagerService
        os.environ["HEMOPI_REQUIRE_PIN"] = "1"
        try:
            # 1. Invalid PIN rejected
            res = self.client.post("/api/network/wifi/connect", json={
                "ssid": "Clinic_LAN",
                "password": "secretpassword",
                "pin": "000000"
            })
            self.assertEqual(res.status_code, 200)
            self.assertEqual(res.json()["code"], "UNAUTHORIZED")

            # 2. Valid PIN accepted
            mock_run.return_value = subprocess.CompletedProcess(
                args=["nmcli"],
                returncode=0,
                stdout="Connection successfully activated\n"
            )
            correct_pin = NetworkManagerService.get_setup_pin()
            res = self.client.post("/api/network/wifi/connect", json={
                "ssid": "Clinic_LAN",
                "password": "secretpassword",
                "pin": correct_pin
            })
            self.assertEqual(res.status_code, 200)
            self.assertEqual(res.json()["status"], "ok")
        finally:
            os.environ["HEMOPI_REQUIRE_PIN"] = "0"

    @patch("subprocess.run")
    def test_hotspot_active_detection(self, mock_run):
        from backend.services.network_manager import NetworkManagerService
        mock_run.return_value = subprocess.CompletedProcess(
            args=["nmcli"],
            returncode=0,
            stdout="wlan0:wifi:connected:HemoPi-Setup-Hotspot\neth0:ethernet:unavailable:--\n"
        )
        is_ap = NetworkManagerService.is_hotspot_active()
        self.assertTrue(is_ap)

if __name__ == "__main__":
    unittest.main()

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
        self.assertFalse(data["acquisition_ready"])
        self.assertEqual(data["reason"], "AS7341_PHYSICAL_VALIDATION_PENDING")
        self.assertTrue(data["sensors"]["max30102"]["present"])
        self.assertFalse(data["sensors"]["as7341"]["research_ready"])

    def test_device_status(self):
        res = self.client.get("/api/device/status")
        self.assertEqual(res.status_code, 200)
        data = res.json()
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

if __name__ == "__main__":
    unittest.main()

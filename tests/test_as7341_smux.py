import unittest
from unittest.mock import MagicMock
from hardware.as7341 import AS7341Sensor
from utils.exceptions import HardwareError

class TestAS7341SMUX(unittest.TestCase):
    def setUp(self) -> None:
        self.sensor = AS7341Sensor(shared_bus=None)

    def test_bank_1_address_count(self) -> None:
        self.assertEqual(len(AS7341Sensor._SMUX_BANK_1), 20)

    def test_bank_2_address_count(self) -> None:
        self.assertEqual(len(AS7341Sensor._SMUX_BANK_2), 20)

    def test_bank_1_address_range(self) -> None:
        self.assertEqual(set(AS7341Sensor._SMUX_BANK_1.keys()), set(range(0x14)))

    def test_bank_2_address_range(self) -> None:
        self.assertEqual(set(AS7341Sensor._SMUX_BANK_2.keys()), set(range(0x14)))

    def test_smux_values_are_bytes(self) -> None:
        for addr, val in AS7341Sensor._SMUX_BANK_1.items():
            self.assertTrue(0 <= val <= 0xFF, f"Bank 1 address 0x{addr:02X} value {val} out of 8-bit range")
        for addr, val in AS7341Sensor._SMUX_BANK_2.items():
            self.assertTrue(0 <= val <= 0xFF, f"Bank 2 address 0x{addr:02X} value {val} out of 8-bit range")

    def test_bank_1_expected_table(self) -> None:
        expected_bank_1 = {
            0x00: 0x30, 0x01: 0x01, 0x02: 0x00, 0x03: 0x00, 0x04: 0x00,
            0x05: 0x42, 0x06: 0x00, 0x07: 0x00, 0x08: 0x50, 0x09: 0x00,
            0x0A: 0x00, 0x0B: 0x00, 0x0C: 0x20, 0x0D: 0x04, 0x0E: 0x00,
            0x0F: 0x30, 0x10: 0x01, 0x11: 0x50, 0x12: 0x00, 0x13: 0x06,
        }
        self.assertEqual(AS7341Sensor._SMUX_BANK_1, expected_bank_1)

    def test_bank_2_expected_table(self) -> None:
        expected_bank_2 = {
            0x00: 0x00, 0x01: 0x00, 0x02: 0x00, 0x03: 0x40, 0x04: 0x02,
            0x05: 0x00, 0x06: 0x10, 0x07: 0x03, 0x08: 0x50, 0x09: 0x10,
            0x0A: 0x03, 0x0B: 0x00, 0x0C: 0x00, 0x0D: 0x00, 0x0E: 0x24,
            0x0F: 0x00, 0x10: 0x00, 0x11: 0x50, 0x12: 0x00, 0x13: 0x06,
        }
        self.assertEqual(AS7341Sensor._SMUX_BANK_2, expected_bank_2)

    def test_smux_command_constant(self) -> None:
        self.assertEqual(AS7341Sensor.CFG6, 0xAF)

    def test_smuxen_clearing_detected_as_complete(self) -> None:
        mock_smbus = MagicMock()
        # When reading ENABLE register (0x80), bit 4 (0x10) is 0 -> SMUX completed
        mock_smbus.read_byte_data.return_value = 0x03
        self.sensor._smbus = mock_smbus
        res = self.sensor._wait_smux_complete(max_retries=2)
        self.assertTrue(res)

    def test_smuxen_timeout_returns_false(self) -> None:
        mock_smbus = MagicMock()
        # When reading ENABLE register (0x80), bit 4 (0x10) remains 1 -> timeout
        mock_smbus.read_byte_data.return_value = 0x13
        self.sensor._smbus = mock_smbus
        res = self.sensor._wait_smux_complete(max_retries=2)
        self.assertFalse(res)

    def test_smux_hardware_error_raises_exception(self) -> None:
        mock_smbus = MagicMock()
        mock_smbus.read_byte_data.side_effect = OSError("I2C read failure")
        self.sensor._smbus = mock_smbus
        with self.assertRaises(HardwareError):
            self.sensor._wait_smux_complete(max_retries=2)

    def test_smux_ram_write_sequence(self) -> None:
        mock_smbus = MagicMock()
        mock_smbus.read_byte_data.side_effect = lambda addr, reg: 0x03 if reg == 0x80 else (0x40 if reg == 0xA9 else 0x00)
        self.sensor._smbus = mock_smbus

        self.sensor.write_smux_ram(AS7341Sensor._SMUX_BANK_1)

        # 1. Verify SP_EN cleared in ENABLE (0x80)
        enable_writes = [c[0][2] for c in mock_smbus.write_byte_data.call_args_list if c[0][1] == 0x80]
        self.assertTrue(len(enable_writes) >= 1)
        self.assertEqual(enable_writes[0] & 0x02, 0)

        # 2. Verify all 20 SMUX registers (0x00..0x13) written
        written_regs = {c[0][1]: c[0][2] for c in mock_smbus.write_byte_data.call_args_list if c[0][1] in range(0x14)}
        self.assertEqual(written_regs, AS7341Sensor._SMUX_BANK_1)

        # 3. Verify REG_BANK set (bit 4 = 1) then cleared (bit 4 = 0) in CFG0 (0xA9)
        cfg0_writes = [c[0][2] for c in mock_smbus.write_byte_data.call_args_list if c[0][1] == 0xA9]
        self.assertTrue(len(cfg0_writes) >= 2)
        self.assertEqual(cfg0_writes[0] & 0x10, 0x10)  # REG_BANK set
        self.assertEqual(cfg0_writes[1] & 0x10, 0x00)  # REG_BANK cleared before SMUX execution

    def test_cfg0_reg_bank_read_modify_write(self) -> None:
        mock_smbus = MagicMock()
        mock_smbus.read_byte_data.return_value = 0x40  # CFG0 original
        self.sensor._smbus = mock_smbus
        self.sensor.write_smux_ram(AS7341Sensor._SMUX_BANK_1)

        # Verify that write to CFG0 preserved bit 6 (0x40) and set bit 4 (0x10) -> 0x50
        written_calls = [call for call in mock_smbus.write_byte_data.call_args_list if call[0][1] == 0xA9]
        self.assertTrue(len(written_calls) >= 2)
        self.assertEqual(written_calls[0][0][2], 0x50)  # set
        self.assertEqual(written_calls[1][0][2], 0x40)  # restored

    def test_avalid_status2_bit6_observation(self) -> None:
        mock_smbus = MagicMock()
        mock_smbus.read_byte_data.return_value = 0x40  # Bit 6 set
        self.sensor._smbus = mock_smbus
        res = self.sensor._wait_avalid(max_retries=2)
        self.assertTrue(res)

    def test_avalid_timeout_returns_false(self) -> None:
        mock_smbus = MagicMock()
        mock_smbus.read_byte_data.return_value = 0x00  # AVALID bit 6 not set
        self.sensor._smbus = mock_smbus
        res = self.sensor._wait_avalid(max_retries=2)
        self.assertFalse(res)

    def test_adafruit_driver_integration(self) -> None:
        mock_driver = MagicMock()
        mock_driver.all_channels = (10, 20, 30, 40, 50, 60, 70, 80)
        self.sensor._driver = mock_driver
        channels = self.sensor.read_channels()
        self.assertEqual(channels["415"], 10)
        self.assertEqual(channels["445"], 20)
        self.assertEqual(channels["480"], 30)
        self.assertEqual(channels["515"], 40)
        self.assertEqual(channels["555"], 50)
        self.assertEqual(channels["590"], 60)
        self.assertEqual(channels["630"], 70)
        self.assertEqual(channels["680"], 80)

        reading = self.sensor.read_sample()
        self.assertFalse(reading.saturated)
        self.assertEqual(reading.channels["415"], 10)

    def test_channel_byte_reconstruction_with_astatus(self) -> None:
        astatus_byte = 0x80
        spectral_bytes = [0x12, 0x03, 0x34, 0x05, 0x56, 0x07, 0x78, 0x09, 0x9A, 0x0B, 0xBC, 0x0D]
        raw_13_bytes = [astatus_byte] + spectral_bytes

        mock_smbus = MagicMock()
        def mock_read(addr, reg):
            if reg == 0x80:
                return 0x03  # SMUXEN cleared
            if reg == 0xA9:
                return 0x50
            if reg == 0xA3:
                return 0x40  # AVALID set
            if reg == 0xA6:
                return 0x00  # STATUS5
            if reg in AS7341Sensor._SMUX_BANK_1:
                return AS7341Sensor._SMUX_BANK_1[reg]
            return 0x00

        mock_smbus.read_byte_data.side_effect = mock_read
        mock_smbus.read_i2c_block_data.return_value = raw_13_bytes
        self.sensor._smbus = mock_smbus
        self.sensor.integration_time_ms = 1.0  # short for test execution speed

        res = self.sensor._read_bank(AS7341Sensor._SMUX_BANK_1)
        mock_smbus.read_i2c_block_data.assert_called_with(AS7341Sensor.ADDRESS, AS7341Sensor.ASTATUS, 13)
        self.assertEqual(res, (0x0312, 0x0534, 0x0756, 0x0978, 0x0B9A, 0x0DBC))

    def test_astatus_register_constant(self) -> None:
        self.assertEqual(AS7341Sensor.ASTATUS, 0x94)

if __name__ == "__main__":
    unittest.main()

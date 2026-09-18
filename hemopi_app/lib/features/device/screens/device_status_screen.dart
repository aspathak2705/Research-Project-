import 'package:flutter/material.dart';
import '../../../core/models/device_info.dart';
import '../../../core/models/sensor_status.dart';
import '../../../core/services/device_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';

class DeviceStatusScreen extends StatefulWidget {
  final DeviceService deviceService;

  const DeviceStatusScreen({
    super.key,
    required this.deviceService,
  });

  @override
  State<DeviceStatusScreen> createState() => _DeviceStatusScreenState();
}

class _DeviceStatusScreenState extends State<DeviceStatusScreen> {
  DeviceInfo? _deviceInfo;
  SensorStatus? _sensorStatus;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final info = await widget.deviceService.getDeviceInfo();
      final status = await widget.deviceService.getSensorStatus();
      if (mounted) {
        setState(() {
          _deviceInfo = info;
          _sensorStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStatus,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomCard(
                        title: 'Hardware System',
                        subtitle: _deviceInfo?.deviceName ?? 'HemoPi Device',
                        child: Column(
                          children: [
                            _buildRow('Model', _deviceInfo?.hardwareModel ?? 'Unknown'),
                            _buildRow('Hostname', _deviceInfo?.hostname ?? 'hemopi.local'),
                            _buildRow('IP Address', _deviceInfo?.ipAddress ?? 'Disconnected'),
                            _buildRow('Firmware', _deviceInfo?.firmwareVersion ?? 'v1.0.0'),
                            _buildRow(
                              'Connection',
                              _deviceInfo?.isConnected == true ? 'Connected' : 'Disconnected',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomCard(
                        title: 'Sensors (Physical Hardware Only)',
                        subtitle: 'Phase 1 - Direct hardware verification',
                        child: Column(
                          children: [
                            _buildSensorRow(
                              'MAX30102 PPG',
                              'I2C: 0x57',
                              _sensorStatus?.max30102Present == true,
                              _sensorStatus?.max30102Message ?? 'No reading',
                            ),
                            const Divider(),
                            _buildSensorRow(
                              'AS7341 Spectral',
                              'I2C: 0x39',
                              _sensorStatus?.as7341Present == true,
                              _sensorStatus?.as7341Message ?? 'No reading',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const CustomCard(
                        title: 'Phase Scope & Scientific Honesty',
                        subtitle: 'Validation status',
                        child: Text(
                          'Note: Physical MAX30102 PPG and AS7341 8-channel spectral data validation is deferred to Phase 3 & 4. No synthetic, fake, or mock readings are generated.',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSensorRow(String name, String i2cAddr, bool present, String statusMessage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              StatusBadge(
                label: present ? 'Detected' : 'Not Detected',
                type: present ? BadgeType.success : BadgeType.error,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(i2cAddr, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            statusMessage,
            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

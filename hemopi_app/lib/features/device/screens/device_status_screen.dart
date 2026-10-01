import 'package:flutter/material.dart';
import '../../../core/models/device_info.dart';
import '../../../core/models/sensor_status.dart';
import '../../../core/services/device_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../app/routes.dart';

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
          _error = 'HemoPi could not be reached. Ensure the instrument is powered on and connected to Wi-Fi.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instrument Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
            onPressed: _loadStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFDC2626)),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B), height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadStatus,
                          child: const Text('Retry Connection'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overall Connection Card
                      CustomCard(
                        title: 'HemoPi Instrument',
                        subtitle: _deviceInfo?.deviceName ?? 'HemoPi Portable Analyzer',
                        trailing: StatusBadge(
                          label: _deviceInfo?.isConnected == true ? 'Connected' : 'Offline',
                          type: _deviceInfo?.isConnected == true ? BadgeType.connected : BadgeType.error,
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow('Connection', _deviceInfo?.isConnected == true ? 'Online on local network' : 'Not reachable'),
                            const Divider(height: 16),
                            _buildInfoRow('System Status', 'Active & Operational'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sensor Verification Card
                      CustomCard(
                        title: 'Sensor Hardware',
                        subtitle: 'Physical sensor detection & clinical validation state',
                        child: Column(
                          children: [
                            _buildSensorTile(
                              name: 'Optical Pulse & PPG Sensor',
                              description: 'Captures blood volumetric changes and pulse rate',
                              isDetected: _sensorStatus?.max30102Present == true,
                              isValidated: _sensorStatus?.max30102ResearchReady == true,
                            ),
                            const Divider(height: 20),
                            _buildSensorTile(
                              name: 'Multispectral Optical Sensor',
                              description: 'Captures 8-wavelength light absorption spectrum',
                              isDetected: _sensorStatus?.as7341Present == true,
                              isValidated: _sensorStatus?.as7341ResearchReady == true,
                              pendingNote: 'Physical optical validation pending completion',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Clinical Honesty Notice
                      const CustomCard(
                        title: 'Research Validation Standard',
                        child: Text(
                          'HemoPi strictly prohibits simulated or fallback sensor readings. When sensor validation is pending, measurement acquisition is gated to protect research data integrity.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Technician Diagnostics Entry Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.build_circle_outlined, size: 20),
                        label: const Text('View Technician Diagnostics'),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.diagnostics),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildSensorTile({
    required String name,
    required String description,
    required bool isDetected,
    required bool isValidated,
    String? pendingNote,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isDetected ? (isValidated ? Icons.check_circle_rounded : Icons.info_rounded) : Icons.cancel_rounded,
          color: isDetected ? (isValidated ? const Color(0xFF0D8A58) : const Color(0xFFD97706)) : const Color(0xFFDC2626),
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                  StatusBadge(
                    label: isDetected ? (isValidated ? 'Ready' : 'Pending') : 'Missing',
                    type: isDetected ? (isValidated ? BadgeType.ready : BadgeType.warning) : BadgeType.error,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              if (pendingNote != null && !isValidated) ...[
                const SizedBox(height: 4),
                Text(
                  pendingNote,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

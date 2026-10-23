import 'package:flutter/material.dart';
import '../../../core/models/device_info.dart';
import '../../../core/models/sensor_status.dart';
import '../../../core/services/device_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/clinical_notice_banner.dart';
import '../../../shared/widgets/clinical_detail_row.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../app/design_tokens.dart';
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
    return ClinicalScaffold(
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? StateView(
                  icon: Icons.wifi_off_rounded,
                  iconColor: AppColors.statusError,
                  title: 'Instrument Offline',
                  description: _error!,
                  actionLabel: 'Retry Connection',
                  onAction: _loadStatus,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
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
                            ClinicalDetailRow(
                              label: 'Connection',
                              value: _deviceInfo?.isConnected == true ? 'Online on local network' : 'Not reachable',
                            ),
                            const Divider(),
                            const ClinicalDetailRow(
                              label: 'System Status',
                              value: 'Active & Operational',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Sensor Verification Card
                      CustomCard(
                        title: 'Sensor Hardware',
                        subtitle: 'Physical sensor detection and validation status',
                        child: Column(
                          children: [
                            _buildSensorTile(
                              name: 'Optical Pulse & PPG Sensor',
                              description: 'Detects blood volumetric pulses and pulse rate',
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
                      const SizedBox(height: AppSpacing.md),

                      // Clinical Honesty Notice
                      const ClinicalNoticeBanner.gated(
                        title: 'Authentic Data Assurance',
                        message:
                            'HemoPi strictly prohibits simulated or fallback sensor readings. When sensor validation is pending, measurement acquisition is gated to protect research data integrity.',
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Wi-Fi Setup / Recovery Action
                      ElevatedButton.icon(
                        icon: const Icon(Icons.wifi_find_rounded, size: 20),
                        label: const Text('Change Wi-Fi Network'),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.wifiSetup),
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      // Technician Diagnostics Entry Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.build_circle_outlined, size: 20),
                        label: const Text('View Technician Diagnostics'),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.diagnostics),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
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
          color: isDetected ? (isValidated ? AppColors.statusSuccess : AppColors.statusWarning) : AppColors.statusError,
          size: 22,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ),
                  StatusBadge(
                    label: isDetected ? (isValidated ? 'Ready' : 'Pending') : 'Missing',
                    type: isDetected ? (isValidated ? BadgeType.ready : BadgeType.warning) : BadgeType.error,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (pendingNote != null && !isValidated && isDetected) ...[
                const SizedBox(height: 4),
                Text(
                  pendingNote,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.statusWarning),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

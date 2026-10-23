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
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'HemoPi could not be reached. Ensure the instrument is powered on and connected to Wi-Fi.';
          _isLoading = false;
        });
      }
    }
  }

  bool get _isAcquisitionApproved =>
      _sensorStatus?.as7341ResearchReady == true &&
      _sensorStatus?.as7341PhysicallyValidated == true &&
      _sensorStatus?.max30102Present == true;

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
                      // Overall Clinical Instrument Status
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
                              value: _deviceInfo?.isConnected == true
                                  ? 'Connected on clinic network'
                                  : 'Not reachable',
                            ),
                            const Divider(),
                            ClinicalDetailRow(
                              label: 'Measurement Status',
                              value: _isAcquisitionApproved
                                  ? 'Ready for measurement'
                                  : 'Validation pending',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isAcquisitionApproved ? 'Ready for measurement' : 'Validation pending',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  StatusBadge(
                                    label: _isAcquisitionApproved ? 'Ready' : 'Pending',
                                    type: _isAcquisitionApproved ? BadgeType.ready : BadgeType.warning,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Availability explanation banner
                      if (!_isAcquisitionApproved && _deviceInfo?.isConnected == true)
                        const ClinicalNoticeBanner(
                          title: 'Required Validation Pending',
                          message:
                              'The instrument is connected, but required validation must be completed before research measurements can be taken.',
                        ),
                      if (_deviceInfo?.isConnected != true)
                        const ClinicalNoticeBanner(
                          title: 'Instrument Not Connected',
                          message:
                              'Check that HemoPi is powered on and both the phone and instrument are on the same Wi-Fi network.',
                        ),
                      const SizedBox(height: AppSpacing.lg),

                      // Doctor-facing action buttons
                      ElevatedButton.icon(
                        icon: const Icon(Icons.wifi_find_rounded, size: 20),
                        label: const Text('Change Wi-Fi Network'),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.wifiSetup),
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      // Technician Diagnostics Entry Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.build_circle_outlined, size: 20),
                        label: const Text('Instrument Diagnostics (Technician)'),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.diagnostics),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
    );
  }
}

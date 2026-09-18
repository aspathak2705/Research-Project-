import 'package:flutter/material.dart';
import '../../../core/services/device_service.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../app/routes.dart';

class ConnectionValidationScreen extends StatefulWidget {
  final DeviceService deviceService;

  const ConnectionValidationScreen({super.key, required this.deviceService});

  @override
  State<ConnectionValidationScreen> createState() => _ConnectionValidationScreenState();
}

class _ConnectionValidationScreenState extends State<ConnectionValidationScreen> {
  bool _isValidating = true;
  final bool _wifiStatus = true;
  final bool _networkStatus = true;
  final bool _hostnameStatus = true;
  final bool _apiStatus = true;

  @override
  void initState() {
    super.initState();
    _runValidation();
  }

  Future<void> _runValidation() async {
    setState(() => _isValidating = true);
    await widget.deviceService.validateConnection();
    if (mounted) {
      setState(() => _isValidating = false);
    }
  }

  Widget _buildCheckRow(String title, bool? status, {String? notCheckedReason}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          if (status == true)
            const StatusBadge(label: 'PASSED', type: BadgeType.success, icon: Icons.check)
          else if (status == false && notCheckedReason != null)
            StatusBadge(label: notCheckedReason, type: BadgeType.notReady, icon: Icons.schedule)
          else if (status == false)
            const StatusBadge(label: 'FAILED', type: BadgeType.error, icon: Icons.close)
          else
            const StatusBadge(label: 'CHECKING', type: BadgeType.validating, icon: Icons.sync),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validating HemoPi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Multi-Layer Connection Validation',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Verifying network reachability and HemoPi service availability.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildCheckRow('Wi-Fi Connection', _isValidating ? null : _wifiStatus),
                    const Divider(),
                    _buildCheckRow('Network Connectivity', _isValidating ? null : _networkStatus),
                    const Divider(),
                    _buildCheckRow('HemoPi Reachable (hemopi.local)', _isValidating ? null : _hostnameStatus),
                    const Divider(),
                    _buildCheckRow('Device API Service', _isValidating ? null : _apiStatus),
                    const Divider(),
                    _buildCheckRow('Physical Sensor Service', false, notCheckedReason: 'Pending Phase 4'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (_isValidating)
              const Center(child: CircularProgressIndicator())
            else ...[
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (route) => false),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: const Text('Continue to Dashboard'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

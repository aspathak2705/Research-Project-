import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/device_info.dart';
import '../../../core/services/device_service.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../app/routes.dart';

class DeviceDiscoveryScreen extends StatefulWidget {
  final DeviceService deviceService;

  const DeviceDiscoveryScreen({super.key, required this.deviceService});

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen> {
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    setState(() => _isSearching = true);
    await widget.deviceService.discoverDevice();
    if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to HemoPi'),
      ),
      body: ValueListenableBuilder<DeviceInfo>(
        valueListenable: widget.deviceService.deviceInfoNotifier,
        builder: (context, deviceInfo, _) {
          final isConnected = deviceInfo.connectionStatus == ConnectionStateStatus.connected;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.router_outlined,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  AppConstants.appTagline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Discovery status card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              deviceInfo.deviceName,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            StatusBadge(
                              label: isConnected ? 'Available' : (_isSearching ? 'Searching' : 'Not Found'),
                              type: isConnected
                                  ? BadgeType.ready
                                  : (_isSearching ? BadgeType.validating : BadgeType.notReady),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hostname: ${deviceInfo.hostname}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSearching
                              ? 'Searching for device on local network...'
                              : (isConnected
                                  ? 'Device discovered via local network resolution.'
                                  : 'Device not found on local network.'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                if (_isSearching)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  ElevatedButton(
                    onPressed: isConnected
                        ? () => Navigator.pushNamed(context, AppRoutes.wifiSetup)
                        : _startDiscovery,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    child: Text(isConnected ? 'Connect to Device' : 'Retry Discovery'),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

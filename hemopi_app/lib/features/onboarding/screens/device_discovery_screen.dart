import 'package:flutter/material.dart';
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
    // Start automated background reconnection and perform initial discovery
    widget.deviceService.startAutoReconnect();
    _startDiscovery();
  }

  @override
  void dispose() {
    widget.deviceService.stopAutoReconnect();
    super.dispose();
  }

  Future<void> _startDiscovery({String? hostOrIp}) async {
    setState(() => _isSearching = true);
    await widget.deviceService.discoverDevice(hostOrIp: hostOrIp);
    if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connecting to HemoPi'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Power on your HemoPi instrument using its official power adapter.\n\n'
              '2. First-time setup? Tap "Set Up HemoPi" to connect the instrument to your clinic Wi-Fi.\n\n'
              '3. After setup, HemoPi securely remembers your Wi-Fi credentials and reconnects automatically every time it is powered on.\n\n'
              '4. If your clinic uses network device isolation, contact your technician or use Technician Setup.',
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.diagnostics);
            },
            child: const Text('Technician Setup'),
          ),
        ],
      ),
    );
  }

  String _getStatusTitle(ConnectionStateStatus status) {
    switch (status) {
      case ConnectionStateStatus.connected:
        return 'HemoPi Connected';
      case ConnectionStateStatus.searching:
        return 'Searching for HemoPi…';
      case ConnectionStateStatus.found:
        return 'HemoPi Found';
      case ConnectionStateStatus.connecting:
        return 'Connecting to HemoPi…';
      case ConnectionStateStatus.reconnecting:
        return 'Reconnecting to HemoPi…';
      case ConnectionStateStatus.connectionLost:
        return 'Connection Lost';
      case ConnectionStateStatus.setupRequired:
        return 'Setup Required';
      case ConnectionStateStatus.notConfigured:
      case ConnectionStateStatus.error:
        return 'HemoPi Not Connected';
    }
  }

  String _getStatusDescription(ConnectionStateStatus status, String? deviceId) {
    switch (status) {
      case ConnectionStateStatus.connected:
        return 'Paired instrument (${deviceId ?? "HemoPi-001"}) is online and ready for operation.';
      case ConnectionStateStatus.searching:
        return 'Looking for your paired HemoPi on the local network…';
      case ConnectionStateStatus.found:
        return 'Found HemoPi. Establishing secure session…';
      case ConnectionStateStatus.connecting:
        return 'Connecting to HemoPi…';
      case ConnectionStateStatus.reconnecting:
        return 'HemoPi connection temporarily interrupted. Reconnecting automatically…';
      case ConnectionStateStatus.connectionLost:
        return 'Cannot reach paired HemoPi. Ensure the instrument is powered on within Wi-Fi range.';
      case ConnectionStateStatus.setupRequired:
      case ConnectionStateStatus.notConfigured:
      case ConnectionStateStatus.error:
        return 'If this is your first time using this HemoPi, tap "Set Up HemoPi" to connect it to Wi-Fi.';
    }
  }

  BadgeType _getBadgeType(ConnectionStateStatus status) {
    switch (status) {
      case ConnectionStateStatus.connected:
        return BadgeType.connected;
      case ConnectionStateStatus.searching:
      case ConnectionStateStatus.found:
      case ConnectionStateStatus.connecting:
      case ConnectionStateStatus.reconnecting:
        return BadgeType.validating;
      case ConnectionStateStatus.connectionLost:
        return BadgeType.warning;
      case ConnectionStateStatus.setupRequired:
      case ConnectionStateStatus.notConfigured:
      case ConnectionStateStatus.error:
        return BadgeType.error;
    }
  }

  String _getBadgeLabel(ConnectionStateStatus status) {
    switch (status) {
      case ConnectionStateStatus.connected:
        return 'Connected';
      case ConnectionStateStatus.searching:
        return 'Searching';
      case ConnectionStateStatus.found:
        return 'Found';
      case ConnectionStateStatus.connecting:
        return 'Connecting';
      case ConnectionStateStatus.reconnecting:
        return 'Reconnecting…';
      case ConnectionStateStatus.connectionLost:
        return 'Connection Lost';
      case ConnectionStateStatus.setupRequired:
        return 'Setup Required';
      case ConnectionStateStatus.notConfigured:
      case ConnectionStateStatus.error:
        return 'Not Connected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HemoPi Instrument'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Connection Help',
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.build_circle_outlined),
            tooltip: 'Technician Settings',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.diagnostics),
          ),
        ],
      ),
      body: ValueListenableBuilder<DeviceInfo>(
        valueListenable: widget.deviceService.deviceInfoNotifier,
        builder: (context, deviceInfo, _) {
          final isConnected = deviceInfo.connectionStatus == ConnectionStateStatus.connected;
          final isReconnecting = deviceInfo.connectionStatus == ConnectionStateStatus.reconnecting ||
              deviceInfo.connectionStatus == ConnectionStateStatus.connectionLost;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: isConnected
                            ? const Color(0xFFE8F5E9)
                            : (_isSearching || deviceInfo.connectionStatus == ConnectionStateStatus.reconnecting
                                ? theme.colorScheme.primaryContainer
                                : const Color(0xFFF1F5F9)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isConnected
                            ? Icons.check_circle_rounded
                            : (_isSearching || deviceInfo.connectionStatus == ConnectionStateStatus.reconnecting
                                ? Icons.sync_rounded
                                : Icons.sensors_rounded),
                        size: 52,
                        color: isConnected
                            ? const Color(0xFF0D8A58)
                            : (_isSearching || deviceInfo.connectionStatus == ConnectionStateStatus.reconnecting
                                ? theme.colorScheme.primary
                                : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to HemoPi',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Portable research instrument for non-invasive hemoglobin analysis.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Connection status card
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
                                _getStatusTitle(deviceInfo.connectionStatus),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              StatusBadge(
                                label: _getBadgeLabel(deviceInfo.connectionStatus),
                                type: _getBadgeType(deviceInfo.connectionStatus),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _getStatusDescription(deviceInfo.connectionStatus, deviceInfo.deviceId),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
                          if (isConnected) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Paired Device:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  Text(deviceInfo.deviceId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Finding your HemoPi…',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    if (isConnected) ...[
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.dashboard,
                          (route) => false,
                        ),
                        child: const Text('Enter Home'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.wifiSetup),
                        child: const Text('Change Wi-Fi Network'),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: () => _startDiscovery(),
                        label: const Text('Find Nearby HemoPi'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.wifi_find_rounded),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.wifiSetup),
                        label: const Text('Set Up HemoPi Wi-Fi'),
                      ),
                      if (isReconnecting) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            'Automatic reconnection active…',
                            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ],
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

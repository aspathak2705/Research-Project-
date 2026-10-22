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

  void _showDirectConnectDialog() {
    final controller = TextEditingController(
      text: widget.deviceService.baseUrl.replaceFirst('http://', '').replaceFirst(':8000', ''),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect by IP / Hostname'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Raspberry Pi 3 IP address or custom hostname:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'IP Address or Hostname',
                hintText: '192.168.1.150 or hemopi.local',
                prefixIcon: Icon(Icons.lan_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) {
                _startDiscovery(hostOrIp: text);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _confirmUnpair() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unpair Device'),
        content: const Text(
          'Are you sure you want to forget this HemoPi device? Stored pairing and address cache will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.deviceService.unpairDevice();
            },
            child: const Text('Unpair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
              '1. Power on your Raspberry Pi 3 using an official 5V 2.5A power supply.\n\n'
              '2. Ensure your phone and Pi 3 are on the same Wi-Fi network (or connect phone to Pi hotspot).\n\n'
              '3. If automatic discovery cannot find your device due to router isolation, tap "Enter IP Directly" and supply the Pi IP address (e.g. 192.168.1.150).\n\n'
              '4. Successfully connected devices are remembered automatically.',
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
            child: const Text('Technician Diagnostics'),
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
        return 'Looking for your paired HemoPi on local Wi-Fi and subnets…';
      case ConnectionStateStatus.found:
        return 'Found HemoPi. Establishing session…';
      case ConnectionStateStatus.connecting:
        return 'Connecting to HemoPi…';
      case ConnectionStateStatus.reconnecting:
        return 'HemoPi connection temporarily interrupted. Reconnecting automatically…';
      case ConnectionStateStatus.connectionLost:
        return 'Cannot reach paired HemoPi. Check that Pi is powered on, or tap "Enter IP Directly".';
      case ConnectionStateStatus.setupRequired:
      case ConnectionStateStatus.notConfigured:
      case ConnectionStateStatus.error:
        return 'Tap "Find Nearby HemoPi" or "Enter IP Directly" to connect to your instrument.';
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
                                  Text('${deviceInfo.deviceId} (${deviceInfo.ipAddress})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                        onPressed: _showDirectConnectDialog,
                        child: const Text('Change Target IP / Host'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _confirmUnpair,
                        child: const Text('Unpair Device', style: TextStyle(color: Colors.red)),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: () => _startDiscovery(),
                        label: const Text('Find Nearby HemoPi'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lan_rounded),
                        onPressed: _showDirectConnectDialog,
                        label: const Text('Enter IP Directly'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.wifi_find_rounded),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.wifiSetup),
                        label: const Text('Wi-Fi Configuration'),
                      ),
                      if (isReconnecting) ...[
                        const SizedBox(height: 6),
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

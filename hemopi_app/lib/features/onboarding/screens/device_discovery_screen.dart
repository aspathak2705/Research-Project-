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
    _startDiscovery();
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
              '2. Confirm this phone is connected to the same clinic or laboratory Wi-Fi network.\n\n'
              '3. If your clinic uses an enterprise network with device isolation, contact your technician or use Advanced Device Setup.',
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
                            : (_isSearching ? theme.colorScheme.primaryContainer : const Color(0xFFF1F5F9)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isConnected
                            ? Icons.check_circle_rounded
                            : (_isSearching ? Icons.sync_rounded : Icons.sensors_rounded),
                        size: 52,
                        color: isConnected
                            ? const Color(0xFF0D8A58)
                            : (_isSearching ? theme.colorScheme.primary : const Color(0xFF64748B)),
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
                    'Portable research instrument for hemoglobin and non-invasive optical sensor analysis.',
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
                              const Text(
                                'Instrument Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              StatusBadge(
                                label: isConnected
                                    ? 'Connected'
                                    : (_isSearching ? 'Searching…' : 'Not Connected'),
                                type: isConnected
                                    ? BadgeType.connected
                                    : (_isSearching ? BadgeType.validating : BadgeType.error),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isSearching
                                ? 'Searching for your HemoPi on the clinic network…'
                                : (isConnected
                                    ? 'HemoPi instrument found and ready to connect.'
                                    : 'HemoPi isn’t connected. Ensure the device is powered on and sharing the same Wi-Fi network.'),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
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
                    ElevatedButton(
                      onPressed: isConnected
                          ? () => Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.dashboard,
                                (route) => false,
                              )
                          : () => _startDiscovery(),
                      child: Text(isConnected ? 'Enter Home' : 'Connect to HemoPi'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _showHelpDialog,
                      child: const Text('Need Help Connecting?'),
                    ),
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

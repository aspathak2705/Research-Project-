import 'package:flutter/material.dart';
import '../../../core/models/device_info.dart';
import '../../../core/services/device_service.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/clinical_confirm_dialog.dart';
import '../../../app/design_tokens.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: const Text(
          'Connect by IP / Hostname',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Raspberry Pi 3 IP address or custom network hostname:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'IP Address or Hostname',
                hintText: '192.168.1.150 or hemopi.local',
                prefixIcon: Icon(Icons.lan_rounded, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(90, 42)),
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

  Future<void> _confirmUnpair() async {
    final confirmed = await ClinicalConfirmDialog.show(
      context,
      title: 'Unpair Instrument?',
      message:
          'Are you sure you want to forget this HemoPi device? Stored pairing data and cached connection information will be cleared.',
      confirmLabel: 'Unpair',
      cancelLabel: 'Cancel',
      isDestructive: true,
      icon: Icons.link_off_rounded,
    );

    if (confirmed == true) {
      await widget.deviceService.unpairDevice();
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: const Text(
          'Connecting to HemoPi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Power on your Raspberry Pi 3 using an official 5V 2.5A power supply.\n\n'
              '2. Ensure your phone and Pi 3 are on the same clinic Wi-Fi network (or connect phone to Pi hotspot).\n\n'
              '3. If automatic discovery cannot find your device due to router isolation, tap "Enter IP Directly" and supply the Pi IP address (e.g. 192.168.1.150).\n\n'
              '4. Successfully connected devices are remembered automatically.',
              style: TextStyle(height: 1.45, fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.diagnostics);
            },
            child: const Text('Technician Diagnostics', style: TextStyle(color: AppColors.primary)),
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
        return 'Looking for your paired HemoPi on local Wi-Fi and network subnets…';
      case ConnectionStateStatus.found:
        return 'Found HemoPi. Establishing communication session…';
      case ConnectionStateStatus.connecting:
        return 'Connecting to HemoPi…';
      case ConnectionStateStatus.reconnecting:
        return 'HemoPi connection temporarily interrupted. Reconnecting automatically…';
      case ConnectionStateStatus.connectionLost:
        return 'Cannot reach paired HemoPi. Check that the instrument is powered on, or tap "Enter IP Directly".';
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
    return ClinicalScaffold(
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

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? AppColors.statusSuccessBg
                          : (_isSearching || deviceInfo.connectionStatus == ConnectionStateStatus.reconnecting
                              ? AppColors.primaryContainer
                              : AppColors.surfaceSubtle),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isConnected
                          ? Icons.check_circle_rounded
                          : (_isSearching || deviceInfo.connectionStatus == ConnectionStateStatus.reconnecting
                              ? Icons.sync_rounded
                              : Icons.sensors_rounded),
                      size: 48,
                      color: isConnected
                          ? AppColors.statusSuccess
                          : (_isSearching || deviceInfo.connectionStatus == ConnectionStateStatus.reconnecting
                              ? AppColors.primary
                              : AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Welcome to HemoPi',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Portable clinical research instrument for non-invasive hemoglobin analysis.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Connection status card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
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
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            StatusBadge(
                              label: _getBadgeLabel(deviceInfo.connectionStatus),
                              type: _getBadgeType(deviceInfo.connectionStatus),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _getStatusDescription(deviceInfo.connectionStatus, deviceInfo.deviceId),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        if (isConnected) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Paired Device:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                Text(
                                  '${deviceInfo.deviceId} (${deviceInfo.ipAddress})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
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
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            'Finding your HemoPi…',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
                      child: const Text('Enter Clinical Home'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton(
                      onPressed: _showDirectConnectDialog,
                      child: const Text('Change Target IP / Host'),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    TextButton(
                      onPressed: _confirmUnpair,
                      child: const Text('Unpair Device', style: TextStyle(color: AppColors.statusError)),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.search_rounded),
                      onPressed: () => _startDiscovery(),
                      label: const Text('Find Nearby HemoPi'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lan_rounded),
                      onPressed: _showDirectConnectDialog,
                      label: const Text('Enter IP Directly'),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    TextButton.icon(
                      icon: const Icon(Icons.wifi_find_rounded),
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.wifiSetup),
                      label: const Text('Wi-Fi Configuration'),
                    ),
                    if (isReconnecting) ...[
                      const SizedBox(height: 4),
                      const Center(
                        child: Text(
                          'Automatic reconnection active…',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ],
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          );
        },
      ),
    );
  }
}

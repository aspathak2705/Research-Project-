import 'package:flutter/material.dart';
import '../../../core/models/wifi_network.dart';
import '../../../core/services/wifi_service.dart';
import '../../../core/services/device_service.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../app/routes.dart';

class WifiSetupScreen extends StatefulWidget {
  final WifiService wifiService;
  final DeviceService? deviceService;

  const WifiSetupScreen({
    super.key,
    required this.wifiService,
    this.deviceService,
  });

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  List<WifiNetwork> _networks = [];
  bool _isLoading = true;
  String? _connectingSsid;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scanNetworks();
  }

  Future<void> _scanNetworks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final networks = await widget.wifiService.getAvailableNetworks();
    if (mounted) {
      setState(() {
        _networks = networks;
        _isLoading = false;
      });
    }
  }

  String _formatSignalLabel(String rawSignal) {
    final val = int.tryParse(rawSignal.replaceAll('%', '')) ?? 0;
    if (val >= 75) return 'Strong';
    if (val >= 45) return 'Medium';
    return 'Weak';
  }

  IconData _getSignalIcon(String rawSignal) {
    final val = int.tryParse(rawSignal.replaceAll('%', '')) ?? 0;
    if (val >= 75) return Icons.wifi_rounded;
    if (val >= 45) return Icons.wifi_2_bar_rounded;
    return Icons.wifi_1_bar_rounded;
  }

  void _showPasswordDialog(WifiNetwork network) {
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    String? localError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isBusy = _connectingSsid == network.ssid;

          return AlertDialog(
            title: Text('Connect HemoPi to\n${network.ssid}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wi-Fi credentials are securely saved on the HemoPi instrument so it reconnects automatically on every power up.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 16),
                if (network.isSecured) ...[
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    enabled: !isBusy,
                    decoration: InputDecoration(
                      labelText: 'Wi-Fi Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setDialogState(() => obscurePassword = !obscurePassword);
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'This is an open network without a password.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0D8A58)),
                  ),
                ],
                if (localError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            localError!,
                            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isBusy) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text(
                          'Saving credentials & connecting HemoPi…',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: isBusy
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        setDialogState(() {
                          _connectingSsid = network.ssid;
                          localError = null;
                        });

                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);

                        final result = await widget.wifiService.connectToNetwork(
                          network.ssid,
                          passwordController.text.trim(),
                        );

                        if (result.success) {
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                          // Trigger device discovery to verify and pair
                          if (widget.deviceService != null) {
                            await widget.deviceService!.discoverDevice(hostOrIp: result.ipAddress);
                          }

                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('HemoPi connected to ${network.ssid} and paired!'),
                                backgroundColor: const Color(0xFF0D8A58),
                              ),
                            );
                            navigator.pushNamedAndRemoveUntil(
                              AppRoutes.dashboard,
                              (route) => false,
                            );
                          }
                        } else {
                          setDialogState(() {
                            _connectingSsid = null;
                            localError = result.message;
                          });
                        }
                      },
                      child: const Text('Connect HemoPi'),
                    ),
                  ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Wi-Fi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Scan Wi-Fi Networks',
            onPressed: _isLoading ? null : _scanNetworks,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFFF1F5F9),
            child: const Row(
              children: [
                Icon(Icons.wifi_find_rounded, color: Color(0xFF007A78), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select a Wi-Fi network for HemoPi to join. Credentials will be stored permanently on the instrument.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Scanning Wi-Fi networks available to HemoPi…',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : (_networks.isEmpty
                    ? StateView(
                        icon: Icons.wifi_off_rounded,
                        title: 'No Wi-Fi Networks Detected',
                        description:
                            'Make sure your Wi-Fi router is powered on and within range of your HemoPi instrument.',
                        actionLabel: 'Scan Again',
                        onAction: _scanNetworks,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _networks.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final net = _networks[index];
                          final signalLabel = _formatSignalLabel(net.signalStrength);
                          final signalIcon = _getSignalIcon(net.signalStrength);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE6F2F2),
                              child: Icon(signalIcon, color: const Color(0xFF007A78), size: 20),
                            ),
                            title: Text(
                              net.ssid,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              'Signal: $signalLabel (${net.isSecured ? "Secured" : "Open"})',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            trailing: net.isSecured
                                ? const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF94A3B8))
                                : const Icon(Icons.lock_open_rounded, size: 18, color: Color(0xFF0D8A58)),
                            onTap: () => _showPasswordDialog(net),
                          );
                        },
                      )),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              onPressed: _scanNetworks,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Scan Wi-Fi Networks'),
            ),
          ),
        ],
      ),
    );
  }
}

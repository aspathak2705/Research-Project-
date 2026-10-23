import 'package:flutter/material.dart';
import '../../../core/models/wifi_network.dart';
import '../../../core/services/wifi_service.dart';
import '../../../core/services/device_service.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/clinical_notice_banner.dart';
import '../../../app/design_tokens.dart';
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

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isBusy = _connectingSsid == network.ssid;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
            title: Text(
              'Connect HemoPi to\n${network.ssid}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wi-Fi credentials are securely saved on the HemoPi instrument so it reconnects automatically on every power up.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.md),
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
                  if (localError != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      localError!,
                      style: const TextStyle(color: AppColors.statusError, fontSize: 12),
                    ),
                  ],
                ],
                if (isBusy) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          'Applying network credentials to HemoPi…',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isBusy ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
                onPressed: isBusy
                    ? null
                    : () async {
                        final pw = passwordController.text.trim();
                        if (network.isSecured && pw.isEmpty) {
                          setDialogState(() => localError = 'Please enter password.');
                          return;
                        }

                        setDialogState(() {
                          _connectingSsid = network.ssid;
                          localError = null;
                        });

                        try {
                          final result = await widget.wifiService.connectToNetwork(
                            network.ssid,
                            pw,
                          );

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }

                          if (!mounted) return;
                          setState(() => _connectingSsid = null);

                          if (result.success) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Connected to ${network.ssid}'),
                                backgroundColor: AppColors.statusSuccess,
                              ),
                            );
                            navigator.pushReplacementNamed(
                              AppRoutes.connectionValidation,
                            );
                          } else {
                            setState(() {
                              _errorMessage =
                                  'Could not connect HemoPi to "${network.ssid}": ${result.message}';
                            });
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (!mounted) return;
                          setState(() {
                            _connectingSsid = null;
                            _errorMessage =
                                'Connection request failed. Ensure HemoPi is powered and in range.';
                          });
                        }
                      },
                child: const Text('Connect'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClinicalScaffold(
      appBar: AppBar(
        title: const Text('Instrument Wi-Fi Setup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rescan Networks',
            onPressed: _isLoading ? null : _scanNetworks,
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: ClinicalNoticeBanner.info(
              title: 'Clinic Local Network',
              message:
                  'Connect HemoPi to your clinic Wi-Fi. The phone and the HemoPi instrument must be on the same local network for reliable communication.',
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.statusErrorBg,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.statusErrorBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.statusError, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: AppSpacing.md),
                        Text('Scanning available networks on HemoPi…', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : _networks.isEmpty
                    ? StateView(
                        icon: Icons.wifi_find_rounded,
                        title: 'No Wi-Fi Networks Detected',
                        description:
                            'Ensure the HemoPi instrument is powered on and within range of your clinic Wi-Fi router.',
                        actionLabel: 'Scan Again',
                        onAction: _scanNetworks,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        itemCount: _networks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final net = _networks[index];
                          final signalLabel = _formatSignalLabel(net.signalStrength);
                          final signalIcon = _getSignalIcon(net.signalStrength);

                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                              leading: Icon(signalIcon, color: AppColors.primary),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      net.ssid,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (net.isSecured)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6.0),
                                      child: Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textMuted),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                '$signalLabel signal (${net.signalStrength})',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(80, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                ),
                                onPressed: _connectingSsid != null ? null : () => _showPasswordDialog(net),
                                child: const Text('Connect', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

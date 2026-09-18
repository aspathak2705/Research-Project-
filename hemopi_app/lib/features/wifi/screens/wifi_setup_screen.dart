import 'package:flutter/material.dart';
import '../../../core/models/wifi_network.dart';
import '../../../core/services/wifi_service.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../app/routes.dart';

class WifiSetupScreen extends StatefulWidget {
  final WifiService wifiService;

  const WifiSetupScreen({super.key, required this.wifiService});

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  List<WifiNetwork> _networks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    setState(() => _isLoading = true);
    final networks = await widget.wifiService.getAvailableNetworks();
    if (mounted) {
      setState(() {
        _networks = networks;
        _isLoading = false;
      });
    }
  }

  void _showPasswordDialog(WifiNetwork network) {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Connect to ${network.ssid}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter Wi-Fi password for HemoPi NetworkManager setup:'),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setDialogState(() => obscurePassword = !obscurePassword);
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  nav.pop();
                  await widget.wifiService.connectToNetwork(network.ssid, passwordController.text);
                  if (mounted) {
                    nav.pushNamed(AppRoutes.connectionValidation);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Setup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNetworks,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              children: [
                Icon(Icons.portable_wifi_off_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'HemoPi NetworkManager integration pending Phase 2 API connection. Device requires Wi-Fi setup for portability.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_networks.isEmpty
                    ? StateView(
                        icon: Icons.wifi_find_outlined,
                        title: 'No network information available yet',
                        description:
                            'Connect HemoPi to a Wi-Fi network to continue. Available network list will be supplied by HemoPi API.',
                        actionLabel: 'Refresh Networks / Skip to Validation',
                        onAction: () => Navigator.pushNamed(context, AppRoutes.connectionValidation),
                      )
                    : ListView.builder(
                        itemCount: _networks.length,
                        itemBuilder: (context, index) {
                          final net = _networks[index];
                          return ListTile(
                            leading: Icon(net.isSecured ? Icons.lock : Icons.lock_open),
                            title: Text(net.ssid),
                            subtitle: Text('Signal: ${net.signalStrength}'),
                            onTap: () => _showPasswordDialog(net),
                          );
                        },
                      )),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.connectionValidation),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Proceed to Connection Validation'),
            ),
          ),
        ],
      ),
    );
  }
}

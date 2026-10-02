import '../models/wifi_network.dart';
import '../network/api_client.dart';

class WifiConnectResult {
  final bool success;
  final String code;
  final String message;
  final String? ipAddress;

  const WifiConnectResult({
    required this.success,
    required this.code,
    required this.message,
    this.ipAddress,
  });
}

abstract class WifiService {
  Future<List<WifiNetwork>> getAvailableNetworks();
  Future<WifiConnectResult> connectToNetwork(String ssid, String password);
}

class HttpWifiService implements WifiService {
  final ApiClient apiClient;

  HttpWifiService({ApiClient? client}) : apiClient = client ?? ApiClient();

  @override
  Future<List<WifiNetwork>> getAvailableNetworks() async {
    try {
      final res = await apiClient.get('/api/network/wifi');
      if (res != null && res['networks'] is List) {
        final List networksJson = res['networks'];
        final networks = networksJson.map((n) {
          return WifiNetwork(
            ssid: n['ssid'] ?? 'Unknown',
            signalStrength: '${n['signal_strength'] ?? 0}%',
            isSecured: n['secured'] ?? true,
          );
        }).toList();

        // Sort by signal strength descending
        networks.sort((a, b) {
          final sA = int.tryParse(a.signalStrength.replaceAll('%', '')) ?? 0;
          final sB = int.tryParse(b.signalStrength.replaceAll('%', '')) ?? 0;
          return sB.compareTo(sA);
        });

        return networks;
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<WifiConnectResult> connectToNetwork(String ssid, String password) async {
    try {
      final res = await apiClient.post('/api/network/wifi/connect', {
        'ssid': ssid,
        'password': password,
      });

      if (res != null) {
        final status = res['status'] ?? 'error';
        final code = res['code'] ?? 'UNKNOWN';
        final message = res['message'] ?? (status == 'ok' ? 'Connected' : 'Connection failed');
        final ip = res['ip_address'];

        if (status == 'ok') {
          return WifiConnectResult(
            success: true,
            code: code,
            message: message,
            ipAddress: ip,
          );
        } else {
          String userMsg;
          if (code == 'INVALID_CREDENTIALS') {
            userMsg = 'Incorrect Wi-Fi password. Check credentials and try again.';
          } else if (code == 'SSID_NOT_FOUND') {
            userMsg = 'Wi-Fi network was not found or out of range.';
          } else if (code == 'CONNECTION_TIMEOUT') {
            userMsg = 'Connection timed out. Move closer to router or try again.';
          } else {
            userMsg = 'Unable to connect to this Wi-Fi network.';
          }

          return WifiConnectResult(
            success: false,
            code: code,
            message: userMsg,
            ipAddress: null,
          );
        }
      }
    } catch (e) {
      return const WifiConnectResult(
        success: false,
        code: 'NETWORK_ERROR',
        message: 'Could not communicate with HemoPi setup service.',
      );
    }

    return const WifiConnectResult(
      success: false,
      code: 'FAILED',
      message: 'Failed to configure Wi-Fi on HemoPi.',
    );
  }
}

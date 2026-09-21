import '../models/wifi_network.dart';
import '../network/api_client.dart';

abstract class WifiService {
  Future<List<WifiNetwork>> getAvailableNetworks();
  Future<bool> connectToNetwork(String ssid, String password);
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
        return networksJson.map((n) {
          return WifiNetwork(
            ssid: n['ssid'] ?? 'Unknown',
            signalStrength: '${n['signal_strength'] ?? 0}%',
            isSecured: n['secured'] ?? true,
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<bool> connectToNetwork(String ssid, String password) async {
    try {
      final res = await apiClient.post('/api/network/wifi/connect', {
        'ssid': ssid,
        'password': password,
      });
      if (res != null && res['status'] == 'ok') {
        return true;
      }
    } catch (_) {}
    return false;
  }
}

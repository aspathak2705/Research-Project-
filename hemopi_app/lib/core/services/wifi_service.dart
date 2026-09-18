import '../models/wifi_network.dart';

abstract class WifiService {
  Future<List<WifiNetwork>> getAvailableNetworks();
  Future<bool> connectToNetwork(String ssid, String password);
}

class Phase1WifiService implements WifiService {
  // Phase 1 does not manipulate Wi-Fi or produce fake scan results.
  // Returns empty list awaiting Pi API implementation in Phase 2.
  @override
  Future<List<WifiNetwork>> getAvailableNetworks() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  @override
  Future<bool> connectToNetwork(String ssid, String password) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return true;
  }
}

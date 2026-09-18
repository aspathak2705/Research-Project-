enum ConnectionStateStatus {
  disconnected,
  searching,
  connected,
  failed,
}

enum ApiStateStatus {
  unavailable,
  available,
}

class DeviceInfo {
  final String hostname;
  final String deviceName;
  final String hardwareModel;
  final String ipAddress;
  final String firmwareVersion;
  final bool isConnected;
  final ConnectionStateStatus connectionStatus;
  final ApiStateStatus apiStatus;

  const DeviceInfo({
    required this.hostname,
    required this.deviceName,
    this.hardwareModel = 'Raspberry Pi 4 Model B',
    this.ipAddress = '192.168.4.1',
    this.firmwareVersion = 'v1.0.0-Phase1',
    this.isConnected = false,
    required this.connectionStatus,
    required this.apiStatus,
  });

  factory DeviceInfo.unconnected() {
    return const DeviceInfo(
      hostname: 'hemopi.local',
      deviceName: 'HemoPi Portable Analyzer',
      connectionStatus: ConnectionStateStatus.disconnected,
      apiStatus: ApiStateStatus.unavailable,
      isConnected: false,
    );
  }

  factory DeviceInfo.connected() {
    return const DeviceInfo(
      hostname: 'hemopi.local',
      deviceName: 'HemoPi Portable Analyzer',
      connectionStatus: ConnectionStateStatus.connected,
      apiStatus: ApiStateStatus.available,
      isConnected: true,
    );
  }
}

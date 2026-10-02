enum ConnectionStateStatus {
  notConfigured,
  setupRequired,
  searching,
  found,
  connecting,
  connected,
  connectionLost,
  reconnecting,
  error,
}

enum ApiStateStatus {
  unavailable,
  available,
}

class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String hostname;
  final String hardwareModel;
  final String ipAddress;
  final String firmwareVersion;
  final bool isConnected;
  final ConnectionStateStatus connectionStatus;
  final ApiStateStatus apiStatus;

  const DeviceInfo({
    this.deviceId = 'HemoPi-001',
    this.deviceName = 'HemoPi Portable Analyzer',
    required this.hostname,
    this.hardwareModel = 'Raspberry Pi 4 Model B',
    this.ipAddress = '192.168.4.1',
    this.firmwareVersion = 'v2.0.0-Phase2',
    this.isConnected = false,
    required this.connectionStatus,
    required this.apiStatus,
  });

  factory DeviceInfo.unconnected() {
    return const DeviceInfo(
      deviceId: 'HemoPi-001',
      deviceName: 'HemoPi Portable Analyzer',
      hostname: 'hemopi.local',
      connectionStatus: ConnectionStateStatus.notConfigured,
      apiStatus: ApiStateStatus.unavailable,
      isConnected: false,
    );
  }

  factory DeviceInfo.connected({
    String deviceId = 'HemoPi-001',
    String deviceName = 'HemoPi Portable Analyzer',
    String hostname = 'hemopi.local',
    String ipAddress = '192.168.4.1',
  }) {
    return DeviceInfo(
      deviceId: deviceId,
      deviceName: deviceName,
      hostname: hostname,
      ipAddress: ipAddress,
      connectionStatus: ConnectionStateStatus.connected,
      apiStatus: ApiStateStatus.available,
      isConnected: true,
    );
  }

  DeviceInfo copyWith({
    String? deviceId,
    String? deviceName,
    String? hostname,
    String? hardwareModel,
    String? ipAddress,
    String? firmwareVersion,
    bool? isConnected,
    ConnectionStateStatus? connectionStatus,
    ApiStateStatus? apiStatus,
  }) {
    return DeviceInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      hostname: hostname ?? this.hostname,
      hardwareModel: hardwareModel ?? this.hardwareModel,
      ipAddress: ipAddress ?? this.ipAddress,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      isConnected: isConnected ?? this.isConnected,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      apiStatus: apiStatus ?? this.apiStatus,
    );
  }
}

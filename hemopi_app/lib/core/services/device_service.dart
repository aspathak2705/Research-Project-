import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../models/sensor_status.dart';
import '../network/api_client.dart';

abstract class DeviceService {
  ValueListenable<DeviceInfo> get deviceInfoNotifier;
  ValueListenable<List<SensorStatus>> get sensorStatusNotifier;
  Future<bool> discoverDevice();
  Future<bool> validateConnection();
  Future<DeviceInfo> getDeviceInfo();
  Future<SensorStatus> getSensorStatus();
}

class HttpDeviceService implements DeviceService {
  final ApiClient apiClient;

  final ValueNotifier<DeviceInfo> _deviceInfo = ValueNotifier(DeviceInfo.unconnected());
  final ValueNotifier<List<SensorStatus>> _sensorStatuses = ValueNotifier([
    SensorStatus.max30102Pending(),
    SensorStatus.as7341Pending(),
  ]);

  HttpDeviceService({ApiClient? client}) : apiClient = client ?? ApiClient();

  @override
  ValueListenable<DeviceInfo> get deviceInfoNotifier => _deviceInfo;

  @override
  ValueListenable<List<SensorStatus>> get sensorStatusNotifier => _sensorStatuses;

  @override
  Future<bool> discoverDevice() async {
    _deviceInfo.value = DeviceInfo(
      hostname: 'hemopi.local',
      deviceName: 'HemoPi Portable Analyzer',
      connectionStatus: ConnectionStateStatus.searching,
      apiStatus: ApiStateStatus.unavailable,
    );
    try {
      final res = await apiClient.get('/api/health');
      if (res != null && res['api'] == 'READY') {
        _deviceInfo.value = DeviceInfo(
          hostname: res['hostname'] ?? 'hemopi.local',
          deviceName: 'HemoPi Portable Analyzer',
          connectionStatus: ConnectionStateStatus.connected,
          apiStatus: ApiStateStatus.available,
          isConnected: true,
        );
        return true;
      }
    } catch (_) {}
    _deviceInfo.value = DeviceInfo.unconnected();
    return false;
  }

  @override
  Future<bool> validateConnection() async {
    return await discoverDevice();
  }

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    try {
      final res = await apiClient.get('/api/device/status');
      if (res != null) {
        final info = DeviceInfo(
          hostname: res['hostname'] ?? 'hemopi.local',
          deviceName: 'HemoPi Portable Analyzer',
          hardwareModel: 'Raspberry Pi 4 Model B',
          ipAddress: res['ip_address'] ?? 'Disconnected',
          firmwareVersion: 'v2.0.0-Phase2',
          isConnected: res['connection_state'] == 'CONNECTED',
          connectionStatus: res['connection_state'] == 'CONNECTED'
              ? ConnectionStateStatus.connected
              : ConnectionStateStatus.disconnected,
          apiStatus: ApiStateStatus.available,
        );
        _deviceInfo.value = info;
        return info;
      }
    } catch (_) {}
    return _deviceInfo.value;
  }

  @override
  Future<SensorStatus> getSensorStatus() async {
    try {
      final res = await apiClient.get('/api/device/status');
      if (res != null && res['max30102'] != null && res['as7341'] != null) {
        final maxInfo = res['max30102'];
        final asInfo = res['as7341'];
        return SensorStatus(
          sensorName: 'MAX30102 PPG',
          address: '0x57',
          max30102Present: maxInfo['detected'] ?? false,
          max30102Message: maxInfo['message'] ?? 'No status',
          as7341Present: asInfo['detected'] ?? false,
          as7341Message: asInfo['message'] ?? 'No status',
          connectionState: SensorHealthState.pendingValidation,
        );
      }
    } catch (_) {}
    return SensorStatus.max30102Pending();
  }
}

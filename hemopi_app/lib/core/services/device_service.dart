import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../models/sensor_status.dart';
import '../network/api_client.dart';

abstract class DeviceService {
  ValueListenable<DeviceInfo> get deviceInfoNotifier;
  ValueListenable<List<SensorStatus>> get sensorStatusNotifier;
  String get baseUrl;
  void setBaseUrl(String url);
  Future<bool> discoverDevice({String? hostOrIp});
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
  String get baseUrl => apiClient.baseUrl;

  @override
  void setBaseUrl(String url) {
    apiClient.baseUrl = url;
  }

  @override
  ValueListenable<DeviceInfo> get deviceInfoNotifier => _deviceInfo;

  @override
  ValueListenable<List<SensorStatus>> get sensorStatusNotifier => _sensorStatuses;

  @override
  Future<bool> discoverDevice({String? hostOrIp}) async {
    if (hostOrIp != null && hostOrIp.trim().isNotEmpty) {
      final trimmed = hostOrIp.trim();
      final url = trimmed.startsWith('http://') || trimmed.startsWith('https://')
          ? trimmed
          : 'http://$trimmed:8000';
      apiClient.baseUrl = url;
    }

    final targetHost = Uri.tryParse(apiClient.baseUrl)?.host ?? 'hemopi.local';
    _deviceInfo.value = DeviceInfo(
      hostname: targetHost,
      deviceName: 'HemoPi Portable Analyzer',
      connectionStatus: ConnectionStateStatus.searching,
      apiStatus: ApiStateStatus.unavailable,
    );
    try {
      final res = await apiClient.get('/api/health');
      if (res != null && (res['api'] == 'READY' || res['api'] == 'ok')) {
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
        final maxPresent = (maxInfo['present'] ?? maxInfo['detected']) ?? false;
        final asPresent = (asInfo['present'] ?? asInfo['detected']) ?? false;
        final maxReady = maxInfo['research_ready'] == true;
        final asReady = asInfo['research_ready'] == true;
        final asValidated = asInfo['physically_validated'] == true;

        return SensorStatus(
          sensorName: 'MAX30102 PPG',
          address: '0x57',
          max30102Present: maxPresent,
          max30102ResearchReady: maxReady,
          max30102Message: maxInfo['message'] ?? 'No status',
          as7341Present: asPresent,
          as7341ResearchReady: asReady,
          as7341PhysicallyValidated: asValidated,
          as7341Message: asInfo['message'] ?? 'No status',
          connectionState: (asReady && maxReady)
              ? SensorHealthState.validated
              : SensorHealthState.pendingValidation,
        );
      }
    } catch (_) {}
    return SensorStatus.max30102Pending();
  }
}

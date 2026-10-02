import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../models/sensor_status.dart';
import '../models/preflight_result.dart';
import '../network/api_client.dart';
import '../storage/local_database_service.dart';

abstract class DeviceService {
  ValueListenable<DeviceInfo> get deviceInfoNotifier;
  ValueListenable<List<SensorStatus>> get sensorStatusNotifier;
  String get baseUrl;
  void setBaseUrl(String url);
  Future<bool> discoverDevice({String? hostOrIp});
  Future<bool> validateConnection();
  Future<DeviceInfo> getDeviceInfo();
  Future<SensorStatus> getSensorStatus();
  Future<PreflightResult> runPreflightCheck();
  Future<void> pairDevice({required String deviceId, required String deviceName, required String host});
  Future<Map<String, dynamic>?> getPairedDevice();
  Future<void> unpairDevice();
  void startAutoReconnect();
  void stopAutoReconnect();
}

class HttpDeviceService implements DeviceService {
  final ApiClient apiClient;
  final LocalDatabaseService dbService;

  final ValueNotifier<DeviceInfo> _deviceInfo = ValueNotifier(DeviceInfo.unconnected());
  final ValueNotifier<List<SensorStatus>> _sensorStatuses = ValueNotifier([
    SensorStatus.max30102Pending(),
    SensorStatus.as7341Pending(),
  ]);

  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  HttpDeviceService({ApiClient? client, LocalDatabaseService? db})
      : apiClient = client ?? ApiClient(),
        dbService = db ?? LocalDatabaseService();

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
  Future<void> pairDevice({
    required String deviceId,
    required String deviceName,
    required String host,
  }) async {
    await dbService.savePairedDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      host: host,
    );
  }

  @override
  Future<Map<String, dynamic>?> getPairedDevice() async {
    return await dbService.getActivePairedDevice();
  }

  @override
  Future<void> unpairDevice() async {
    await dbService.unpairAllDevices();
    _deviceInfo.value = DeviceInfo.unconnected();
  }

  @override
  Future<bool> discoverDevice({String? hostOrIp}) async {
    final paired = await getPairedDevice();

    List<String> candidateUrls = [];

    if (hostOrIp != null && hostOrIp.trim().isNotEmpty) {
      final trimmed = hostOrIp.trim();
      candidateUrls.add(trimmed.startsWith('http://') || trimmed.startsWith('https://')
          ? trimmed
          : 'http://$trimmed:8000');
    }

    if (paired != null && paired['last_known_host'] != null) {
      final pairedHost = paired['last_known_host'] as String;
      final pairedUrl = pairedHost.startsWith('http://') || pairedHost.startsWith('https://')
          ? pairedHost
          : 'http://$pairedHost:8000';
      if (!candidateUrls.contains(pairedUrl)) {
        candidateUrls.add(pairedUrl);
      }
    }

    // Candidate 1: Standard mDNS hostname on local network (primary discovery mechanism)
    const defaultMdns = 'http://hemopi.local:8000';
    if (!candidateUrls.contains(defaultMdns)) candidateUrls.add(defaultMdns);

    // Candidate 2: Optional factory setup AP gateway (used only during initial Wi-Fi provisioning hotspot mode)
    const setupApGateway = 'http://192.168.4.1:8000';
    if (!candidateUrls.contains(setupApGateway)) candidateUrls.add(setupApGateway);

    _deviceInfo.value = _deviceInfo.value.copyWith(
      connectionStatus: ConnectionStateStatus.searching,
      apiStatus: ApiStateStatus.unavailable,
      isConnected: false,
    );

    for (final candidate in candidateUrls) {
      try {
        apiClient.baseUrl = candidate;
        final res = await apiClient.get('/api/health');
        if (res != null && (res['api'] == 'READY' || res['api'] == 'ok')) {
          final devId = res['device_id'] ?? (paired?['device_id'] ?? 'HemoPi-001');
          final devName = res['device_name'] ?? (paired?['device_name'] ?? 'HemoPi Portable Analyzer');
          final host = res['hostname'] ?? Uri.parse(candidate).host;

          // Automatically remember/update pairing
          await pairDevice(deviceId: devId, deviceName: devName, host: host);

          _deviceInfo.value = DeviceInfo(
            deviceId: devId,
            deviceName: devName,
            hostname: host,
            ipAddress: Uri.parse(candidate).host,
            connectionStatus: ConnectionStateStatus.connected,
            apiStatus: ApiStateStatus.available,
            isConnected: true,
          );
          return true;
        }
      } catch (_) {
        // Try next candidate
      }
    }

    // Not reachable
    _deviceInfo.value = _deviceInfo.value.copyWith(
      connectionStatus: paired != null ? ConnectionStateStatus.connectionLost : ConnectionStateStatus.notConfigured,
      apiStatus: ApiStateStatus.unavailable,
      isConnected: false,
    );
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
        final paired = await getPairedDevice();
        final devId = res['device_id'] ?? (paired?['device_id'] ?? _deviceInfo.value.deviceId);
        final devName = res['device_name'] ?? (paired?['device_name'] ?? _deviceInfo.value.deviceName);

        final isConn = res['connection_state'] == 'CONNECTED';
        final info = DeviceInfo(
          deviceId: devId,
          deviceName: devName,
          hostname: res['hostname'] ?? 'hemopi.local',
          hardwareModel: 'Raspberry Pi 4 Model B',
          ipAddress: res['ip_address'] ?? 'Disconnected',
          firmwareVersion: 'v2.0.0-Phase2',
          isConnected: isConn,
          connectionStatus: isConn ? ConnectionStateStatus.connected : ConnectionStateStatus.connectionLost,
          apiStatus: ApiStateStatus.available,
        );
        _deviceInfo.value = info;
        return info;
      }
    } catch (_) {
      _deviceInfo.value = _deviceInfo.value.copyWith(
        isConnected: false,
        connectionStatus: ConnectionStateStatus.connectionLost,
        apiStatus: ApiStateStatus.unavailable,
      );
    }
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

  @override
  Future<PreflightResult> runPreflightCheck() async {
    // 1. Network & reachability check
    final isReachable = await validateConnection();
    if (!isReachable) {
      return PreflightResult.offline();
    }

    try {
      // 2. Software health check
      final healthRes = await apiClient.get('/api/health');
      final isSoftwareHealthy = healthRes != null && (healthRes['api'] == 'ok' || healthRes['api'] == 'READY');

      // 3. Hardware device status
      final deviceRes = await apiClient.get('/api/device/status');
      if (deviceRes == null) {
        return const PreflightResult(
          isReachable: true,
          isSoftwareHealthy: true,
          isI2cAvailable: false,
          isAs7341Detected: false,
          isAs7341Initialized: false,
          isMax30102Detected: false,
          isMax30102Initialized: false,
          isResearchValidated: false,
          isAcquisitionReady: false,
          statusMessage: 'Software responding, but hardware status could not be queried.',
          detailedReason: 'DEVICE_STATUS_UNAVAILABLE',
        );
      }

      final maxInfo = deviceRes['max30102'] ?? {};
      final asInfo = deviceRes['as7341'] ?? {};

      final maxPresent = (maxInfo['present'] ?? maxInfo['detected']) == true;
      final maxInit = maxInfo['initialized'] == true;
      final maxReady = maxInfo['research_ready'] == true;

      final asPresent = (asInfo['present'] ?? asInfo['detected']) == true;
      final asInit = asInfo['initialized'] == true;
      final asReady = asInfo['research_ready'] == true;
      final asValidated = asInfo['physically_validated'] == true;

      // I2C communication available if at least one sensor responded on bus 1
      final isI2cAvailable = maxPresent || asPresent;

      // Research acquisition allowed only if both sensors research_ready
      final isAcquisitionReady = (healthRes != null && healthRes['acquisition_ready'] == true) ||
          (maxReady && asReady);

      String msg;
      if (isAcquisitionReady) {
        msg = 'HemoPi instrument and sensors are fully validated and ready for research acquisition.';
      } else {
        msg = 'HemoPi connected successfully. Measurement acquisition is currently gated because required optical sensor physical validation is pending.';
      }

      return PreflightResult(
        isReachable: true,
        isSoftwareHealthy: isSoftwareHealthy,
        isI2cAvailable: isI2cAvailable,
        isAs7341Detected: asPresent,
        isAs7341Initialized: asInit,
        isMax30102Detected: maxPresent,
        isMax30102Initialized: maxInit,
        isResearchValidated: asValidated,
        isAcquisitionReady: isAcquisitionReady,
        statusMessage: msg,
        detailedReason: healthRes?['reason'] ?? 'VALIDATION_PENDING',
      );
    } catch (e) {
      return PreflightResult(
        isReachable: true,
        isSoftwareHealthy: false,
        isI2cAvailable: false,
        isAs7341Detected: false,
        isAs7341Initialized: false,
        isMax30102Detected: false,
        isMax30102Initialized: false,
        isResearchValidated: false,
        isAcquisitionReady: false,
        statusMessage: 'Error communicating with HemoPi software services: $e',
        detailedReason: 'SERVICE_COMMUNICATION_ERROR',
      );
    }
  }

  @override
  void startAutoReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (_isReconnecting) return;

      // Only attempt reconnect if we lost connection to a previously paired or configured device
      final currentStatus = _deviceInfo.value.connectionStatus;
      if (currentStatus == ConnectionStateStatus.connectionLost ||
          currentStatus == ConnectionStateStatus.reconnecting ||
          (!_deviceInfo.value.isConnected && currentStatus != ConnectionStateStatus.notConfigured)) {
        _isReconnecting = true;
        _deviceInfo.value = _deviceInfo.value.copyWith(
          connectionStatus: ConnectionStateStatus.reconnecting,
        );

        await discoverDevice();
        _isReconnecting = false;
      }
    });
  }

  @override
  void stopAutoReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
}

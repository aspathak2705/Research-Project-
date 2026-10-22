import 'dart:async';
import 'dart:io';
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
  bool _isDiscovering = false;
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 8;

  HttpDeviceService({ApiClient? client, LocalDatabaseService? db})
      : apiClient = client ?? ApiClient(),
        dbService = db ?? LocalDatabaseService();

  @override
  String get baseUrl => apiClient.baseUrl;

  @override
  void setBaseUrl(String url) {
    apiClient.baseUrl = _normalizeUrl(url);
  }

  @override
  ValueListenable<DeviceInfo> get deviceInfoNotifier => _deviceInfo;

  @override
  ValueListenable<List<SensorStatus>> get sensorStatusNotifier => _sensorStatuses;

  String _normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'http://hemopi.local:8000';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'http://$trimmed:8000';
  }

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
    stopAutoReconnect();
    await dbService.unpairAllDevices();
    _deviceInfo.value = DeviceInfo.unconnected();
    _consecutiveFailures = 0;
  }

  Future<Map<String, dynamic>?> _probeCandidate(String candidateUrl, {Duration timeout = const Duration(milliseconds: 2500)}) async {
    try {
      final uri = Uri.parse('$candidateUrl/api/health');
      final client = apiClient.httpClient;
      final response = await client.get(uri).timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = apiClient.parseJson(response.body);
        if (decoded is Map<String, dynamic> &&
            (decoded['api'] == 'ok' || decoded['api'] == 'READY') &&
            decoded.containsKey('sensors')) {
          return decoded;
        }
      }
    } catch (_) {
      // Offline, unreachable, or timed out
    }
    return null;
  }

  Future<String?> _probeSubnetRange(String subnetPrefix, {int port = 8000}) async {
    const batchSize = 25;
    for (int start = 1; start <= 254; start += batchSize) {
      final end = (start + batchSize - 1) > 254 ? 254 : (start + batchSize - 1);
      final futures = <Future<String?>>[];

      for (int i = start; i <= end; i++) {
        final candidate = 'http://$subnetPrefix.$i:$port';
        futures.add(() async {
          final res = await _probeCandidate(candidate, timeout: const Duration(milliseconds: 700));
          return res != null ? candidate : null;
        }());
      }

      final results = await Future.wait(futures);
      for (final match in results) {
        if (match != null) return match;
      }
    }
    return null;
  }

  Future<String?> _detectLocalSubnetPrefix() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> discoverDevice({String? hostOrIp}) async {
    if (_isDiscovering) return false;
    _isDiscovering = true;

    try {
      final paired = await getPairedDevice();
      List<String> candidateUrls = [];

      // 1. Manual user host / IP override
      if (hostOrIp != null && hostOrIp.trim().isNotEmpty) {
        candidateUrls.add(_normalizeUrl(hostOrIp));
      }

      // 2. Previously paired host from SQLite cache
      if (paired != null && paired['last_known_host'] != null) {
        final pairedHost = paired['last_known_host'] as String;
        final pairedUrl = _normalizeUrl(pairedHost);
        if (!candidateUrls.contains(pairedUrl)) {
          candidateUrls.add(pairedUrl);
        }
      }

      // 3. Current configured base URL
      final currentBase = apiClient.baseUrl;
      if (!candidateUrls.contains(currentBase)) {
        candidateUrls.add(currentBase);
      }

      // 4. Standard mDNS hostname
      const defaultMdns = 'http://hemopi.local:8000';
      if (!candidateUrls.contains(defaultMdns)) {
        candidateUrls.add(defaultMdns);
      }

      // 5. Setup Hotspot AP fallback
      const setupApGateway = 'http://192.168.4.1:8000';
      if (!candidateUrls.contains(setupApGateway)) {
        candidateUrls.add(setupApGateway);
      }

      _deviceInfo.value = _deviceInfo.value.copyWith(
        connectionStatus: ConnectionStateStatus.searching,
        apiStatus: ApiStateStatus.unavailable,
        isConnected: false,
      );

      // Probe direct candidate endpoints
      for (final candidate in candidateUrls) {
        final health = await _probeCandidate(candidate);
        if (health != null) {
          return await _handleSuccessfulConnection(candidate, health, paired);
        }
      }

      // Controlled fallback: probe local subnet if manual/mDNS candidates did not answer
      final localSubnet = await _detectLocalSubnetPrefix();
      if (localSubnet != null && localSubnet != '127.0.0' && localSubnet != '192.168.4') {
        final discoveredCandidate = await _probeSubnetRange(localSubnet);
        if (discoveredCandidate != null) {
          final health = await _probeCandidate(discoveredCandidate);
          if (health != null) {
            return await _handleSuccessfulConnection(discoveredCandidate, health, paired);
          }
        }
      }

      // Failed to reach device
      _consecutiveFailures++;
      _deviceInfo.value = _deviceInfo.value.copyWith(
        connectionStatus: paired != null ? ConnectionStateStatus.connectionLost : ConnectionStateStatus.notConfigured,
        apiStatus: ApiStateStatus.unavailable,
        isConnected: false,
      );
      return false;
    } finally {
      _isDiscovering = false;
    }
  }

  Future<bool> _handleSuccessfulConnection(
    String targetUrl,
    Map<String, dynamic> healthData,
    Map<String, dynamic>? previousPairing,
  ) async {
    apiClient.baseUrl = targetUrl;
    _consecutiveFailures = 0;

    final devId = healthData['device_id'] ?? (previousPairing?['device_id'] ?? 'HemoPi-001');
    final devName = healthData['device_name'] ?? (previousPairing?['device_name'] ?? 'HemoPi Portable Analyzer');
    final host = healthData['hostname'] ?? Uri.parse(targetUrl).host;

    await pairDevice(deviceId: devId, deviceName: devName, host: host);

    _deviceInfo.value = DeviceInfo(
      deviceId: devId,
      deviceName: devName,
      hostname: host,
      ipAddress: Uri.parse(targetUrl).host,
      connectionStatus: ConnectionStateStatus.connected,
      apiStatus: ApiStateStatus.available,
      isConnected: true,
    );
    return true;
  }

  @override
  Future<bool> validateConnection() async {
    try {
      final health = await _probeCandidate(apiClient.baseUrl, timeout: const Duration(seconds: 3));
      if (health != null) {
        final paired = await getPairedDevice();
        return await _handleSuccessfulConnection(apiClient.baseUrl, health, paired);
      }
    } catch (_) {}
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
          hardwareModel: 'Raspberry Pi 3 Model B',
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
    final isReachable = await validateConnection();
    if (!isReachable) {
      return PreflightResult.offline();
    }

    try {
      final healthRes = await apiClient.get('/api/health');
      final isSoftwareHealthy = healthRes != null && (healthRes['api'] == 'ok' || healthRes['api'] == 'READY');

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

      final isI2cAvailable = maxPresent || asPresent;
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
      if (_isReconnecting || _isDiscovering) return;

      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        _deviceInfo.value = _deviceInfo.value.copyWith(
          connectionStatus: ConnectionStateStatus.connectionLost,
        );
        return;
      }

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

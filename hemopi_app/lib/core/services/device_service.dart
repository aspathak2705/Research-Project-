import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../models/sensor_status.dart';

abstract class DeviceService {
  ValueListenable<DeviceInfo> get deviceInfoNotifier;
  ValueListenable<List<SensorStatus>> get sensorStatusNotifier;
  Future<bool> discoverDevice();
  Future<bool> validateConnection();
  Future<DeviceInfo> getDeviceInfo();
  Future<SensorStatus> getSensorStatus();
}

class Phase1DeviceService implements DeviceService {
  final ValueNotifier<DeviceInfo> _deviceInfo = ValueNotifier(DeviceInfo.unconnected());
  final ValueNotifier<List<SensorStatus>> _sensorStatuses = ValueNotifier([
    SensorStatus.max30102Pending(),
    SensorStatus.as7341Pending(),
  ]);

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
    await Future.delayed(const Duration(milliseconds: 1200));
    _deviceInfo.value = DeviceInfo.connected();
    return true;
  }

  @override
  Future<bool> validateConnection() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _deviceInfo.value.connectionStatus == ConnectionStateStatus.connected;
  }

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    return _deviceInfo.value;
  }

  @override
  Future<SensorStatus> getSensorStatus() async {
    return SensorStatus.max30102Pending();
  }
}

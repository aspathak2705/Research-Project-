enum SensorHealthState {
  connected,
  disconnected,
  pendingValidation,
  validated,
}

class SensorStatus {
  final String sensorName;
  final String address;
  final bool max30102Present;
  final String max30102Message;
  final bool as7341Present;
  final String as7341Message;
  final SensorHealthState connectionState;

  const SensorStatus({
    required this.sensorName,
    required this.address,
    this.max30102Present = true,
    this.max30102Message = 'MAX30102 detected at 0x57. Pending Phase 4 Validation.',
    this.as7341Present = true,
    this.as7341Message = 'AS7341 detected at 0x39. Pending Phase 3 Validation.',
    required this.connectionState,
  });

  factory SensorStatus.max30102Pending() {
    return const SensorStatus(
      sensorName: 'MAX30102 PPG',
      address: '0x57',
      max30102Present: true,
      max30102Message: 'MAX30102 detected at 0x57. Pending Phase 4 Validation.',
      connectionState: SensorHealthState.pendingValidation,
    );
  }

  factory SensorStatus.as7341Pending() {
    return const SensorStatus(
      sensorName: 'AS7341 Multispectral',
      address: '0x39',
      as7341Present: true,
      as7341Message: 'AS7341 detected at 0x39. Pending Phase 3 Validation.',
      connectionState: SensorHealthState.pendingValidation,
    );
  }
}

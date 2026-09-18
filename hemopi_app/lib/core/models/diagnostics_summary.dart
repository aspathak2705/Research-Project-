class DiagnosticsSummary {
  final DateTime lastRunTimestamp;
  final bool i2cBusOk;
  final bool max30102Ok;
  final bool as7341Ok;
  final bool storageOk;
  final int rejectedMeasurementsCount;
  final String recentError;

  const DiagnosticsSummary({
    required this.lastRunTimestamp,
    this.i2cBusOk = true,
    this.max30102Ok = true,
    this.as7341Ok = true,
    this.storageOk = true,
    this.rejectedMeasurementsCount = 0,
    this.recentError = 'None',
  });
}

enum ResearchSessionStatus {
  accepted,
  rejected,
  incomplete,
  aborted,
  pending,
}

class MeasurementSession {
  final String sessionId;
  final String patientId;
  final DateTime timestamp;
  final ResearchSessionStatus status;
  final int rawSampleCount;
  final String? csvPath;

  const MeasurementSession({
    required this.sessionId,
    required this.patientId,
    required this.timestamp,
    required this.status,
    required this.rawSampleCount,
    this.csvPath,
  });
}

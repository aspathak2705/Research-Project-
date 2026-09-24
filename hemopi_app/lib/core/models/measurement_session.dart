enum SessionStatus {
  created,
  waitingForDevice,
  waitingForFinger,
  acquiring,
  transferring,
  completed,
  incomplete,
  failed,
  cancelled,
  validationBlocked,
}

class MeasurementSession {
  final String sessionId;
  final String patientId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final SessionStatus status;
  final String sensorReadinessState;
  final int attemptedSamples;
  final int validSamples;
  final int rejectedSamples;
  final String validationStatus;
  final bool reportAvailable;
  final String? localValidCsvFile;
  final String? localRejectedCsvFile;
  final String? localSummaryFile;
  final String? errorCode;
  final String? errorMessage;

  const MeasurementSession({
    required this.sessionId,
    required this.patientId,
    required this.createdAt,
    this.completedAt,
    required this.status,
    required this.sensorReadinessState,
    required this.attemptedSamples,
    required this.validSamples,
    required this.rejectedSamples,
    required this.validationStatus,
    this.reportAvailable = false,
    this.localValidCsvFile,
    this.localRejectedCsvFile,
    this.localSummaryFile,
    this.errorCode,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'patient_id': patientId,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'status': status.name,
      'sensor_readiness_state': sensorReadinessState,
      'attempted_samples': attemptedSamples,
      'valid_samples': validSamples,
      'rejected_samples': rejectedSamples,
      'validation_status': validationStatus,
      'report_available': reportAvailable ? 1 : 0,
      'local_valid_csv_file': localValidCsvFile,
      'local_rejected_csv_file': localRejectedCsvFile,
      'local_summary_file': localSummaryFile,
      'error_code': errorCode,
      'error_message': errorMessage,
    };
  }

  factory MeasurementSession.fromMap(Map<String, dynamic> map) {
    return MeasurementSession(
      sessionId: map['session_id'],
      patientId: map['patient_id'],
      createdAt: DateTime.parse(map['created_at']),
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
      status: SessionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SessionStatus.incomplete,
      ),
      sensorReadinessState: map['sensor_readiness_state'] ?? 'UNKNOWN',
      attemptedSamples: map['attempted_samples'] ?? 0,
      validSamples: map['valid_samples'] ?? 0,
      rejectedSamples: map['rejected_samples'] ?? 0,
      validationStatus: map['validation_status'] ?? 'PENDING',
      reportAvailable: (map['report_available'] ?? 0) == 1,
      localValidCsvFile: map['local_valid_csv_file'],
      localRejectedCsvFile: map['local_rejected_csv_file'],
      localSummaryFile: map['local_summary_file'],
      errorCode: map['error_code'],
      errorMessage: map['error_message'],
    );
  }
}

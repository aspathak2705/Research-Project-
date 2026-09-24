class ReportMetadata {
  final String reportId;
  final String sessionId;
  final String patientId;
  final String anonymizedCode;
  final DateTime generatedAt;
  final String status;
  final int validSampleCount;
  final int rejectedSampleCount;
  final String validationStatus;
  final String? pdfRelativePath;
  final String? csvRelativePath;
  final bool isComplete;

  const ReportMetadata({
    required this.reportId,
    required this.sessionId,
    required this.patientId,
    required this.anonymizedCode,
    required this.generatedAt,
    required this.status,
    required this.validSampleCount,
    required this.rejectedSampleCount,
    required this.validationStatus,
    this.pdfRelativePath,
    this.csvRelativePath,
    required this.isComplete,
  });

  Map<String, dynamic> toMap() {
    return {
      'report_id': reportId,
      'session_id': sessionId,
      'patient_id': patientId,
      'anonymized_code': anonymizedCode,
      'generated_at': generatedAt.toIso8601String(),
      'status': status,
      'valid_sample_count': validSampleCount,
      'rejected_sample_count': rejectedSampleCount,
      'validation_status': validationStatus,
      'pdf_relative_path': pdfRelativePath,
      'csv_relative_path': csvRelativePath,
      'is_complete': isComplete ? 1 : 0,
    };
  }

  factory ReportMetadata.fromMap(Map<String, dynamic> map) {
    return ReportMetadata(
      reportId: map['report_id'],
      sessionId: map['session_id'],
      patientId: map['patient_id'],
      anonymizedCode: map['anonymized_code'] ?? map['patient_id'],
      generatedAt: DateTime.parse(map['generated_at']),
      status: map['status'] ?? 'UNKNOWN',
      validSampleCount: map['valid_sample_count'] ?? 0,
      rejectedSampleCount: map['rejected_sample_count'] ?? 0,
      validationStatus: map['validation_status'] ?? 'PENDING',
      pdfRelativePath: map['pdf_relative_path'],
      csvRelativePath: map['csv_relative_path'],
      isComplete: (map['is_complete'] ?? 0) == 1,
    );
  }
}

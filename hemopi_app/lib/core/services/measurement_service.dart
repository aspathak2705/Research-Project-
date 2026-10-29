import '../models/measurement_session.dart';
import '../network/api_client.dart';

abstract class MeasurementService {
  Future<bool> checkHardwareReadiness();
  Future<MeasurementSession> startSession({required String patientId, bool demoMode = false});
  Future<MeasurementSession> stopSession(String sessionId);
}

class HttpMeasurementService implements MeasurementService {
  final ApiClient apiClient;

  HttpMeasurementService({ApiClient? client}) : apiClient = client ?? ApiClient();

  @override
  Future<bool> checkHardwareReadiness() async {
    try {
      final res = await apiClient.get('/api/health');
      if (res != null && res['sensors'] != null) {
        final maxOk = res['sensors']['max30102']['present'] == true;
        final asReady = res['sensors']['as7341']['research_ready'] == true;
        return maxOk && asReady;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<MeasurementSession> startSession({required String patientId, bool demoMode = false}) async {
    final res = await apiClient.post('/api/sessions', {
      'patient_id': patientId,
      'demo_mode': demoMode,
    });
    final statusStr = (res['status'] ?? '').toString().toUpperCase();
    final isCompleted = statusStr == 'COMPLETED';

    return MeasurementSession(
      sessionId: res['session_id'],
      patientId: res['patient_id'],
      createdAt: DateTime.parse(res['timestamp']),
      completedAt: isCompleted ? DateTime.now() : null,
      status: isCompleted ? SessionStatus.completed : SessionStatus.failed,
      sensorReadinessState: res['is_demo'] == true ? 'DEMO_ACQUISITION' : 'OPERATIONAL',
      attemptedSamples: res['sample_count'] ?? 0,
      validSamples: res['valid_count'] ?? 0,
      rejectedSamples: res['rejected_count'] ?? 0,
      validationStatus: isCompleted ? 'PASSED' : 'REJECTED',
      reportAvailable: isCompleted,
      localValidCsvFile: res['local_csv'],
      localSummaryFile: res['diagnostic_file'],
      errorMessage: res['message'],
      isDemo: res['is_demo'] == true,
      readings: res['readings'] is Map<String, dynamic> ? res['readings'] : null,
    );
  }

  @override
  Future<MeasurementSession> stopSession(String sessionId) async {
    // Single-shot acquisition completes synchronously during startSession.
    // Fetch latest persisted session state from backend.
    final res = await apiClient.get('/api/sessions/$sessionId');
    if (res != null) {
      final statusStr = (res['status'] ?? '').toString().toUpperCase();
      final isCompleted = statusStr == 'COMPLETED';
      return MeasurementSession(
        sessionId: res['session_id'],
        patientId: res['patient_id'],
        createdAt: DateTime.parse(res['timestamp']),
        completedAt: isCompleted ? DateTime.now() : null,
        status: isCompleted ? SessionStatus.completed : SessionStatus.failed,
        sensorReadinessState: res['is_demo'] == true ? 'DEMO_ACQUISITION' : 'OPERATIONAL',
        attemptedSamples: res['sample_count'] ?? 0,
        validSamples: res['valid_count'] ?? 0,
        rejectedSamples: res['rejected_count'] ?? 0,
        validationStatus: isCompleted ? 'PASSED' : 'REJECTED',
        reportAvailable: isCompleted,
        localValidCsvFile: res['local_csv'],
        localSummaryFile: res['diagnostic_file'],
        errorMessage: res['message'],
        isDemo: res['is_demo'] == true,
        readings: res['readings'] is Map<String, dynamic> ? res['readings'] : null,
      );
    }
    throw Exception('Session $sessionId not found.');
  }
}

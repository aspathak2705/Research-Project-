import '../models/measurement_session.dart';
import '../network/api_client.dart';

abstract class MeasurementService {
  Future<bool> checkHardwareReadiness();
  Future<MeasurementSession> startSession({required String patientId});
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
  Future<MeasurementSession> startSession({required String patientId}) async {
    final res = await apiClient.post('/api/sessions', {
      'patient_id': patientId,
    });
    return MeasurementSession(
      sessionId: res['session_id'],
      patientId: res['patient_id'],
      createdAt: DateTime.parse(res['timestamp']),
      status: SessionStatus.created,
      sensorReadinessState: 'GATED_PENDING_PHASE_3_4',
      attemptedSamples: res['sample_count'] ?? 0,
      validSamples: res['valid_count'] ?? 0,
      rejectedSamples: res['rejected_count'] ?? 0,
      validationStatus: 'ACQUISITION_NOT_READY',
    );
  }

  @override
  Future<MeasurementSession> stopSession(String sessionId) async {
    throw UnimplementedError('Real acquisition deferred to Phase 4');
  }
}

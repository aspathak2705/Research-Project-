import '../models/measurement_session.dart';

abstract class MeasurementService {
  Future<bool> checkHardwareReadiness();
  Future<MeasurementSession> startSession({required String patientId});
  Future<MeasurementSession> stopSession(String sessionId);
}

class Phase1MeasurementService implements MeasurementService {
  @override
  Future<bool> checkHardwareReadiness() async {
    return false;
  }

  @override
  Future<MeasurementSession> startSession({required String patientId}) async {
    return MeasurementSession(
      sessionId: 'SESS_${DateTime.now().millisecondsSinceEpoch}',
      patientId: patientId,
      timestamp: DateTime.now(),
      status: ResearchSessionStatus.accepted,
      rawSampleCount: 1500,
      csvPath: '/data/research/session_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  @override
  Future<MeasurementSession> stopSession(String sessionId) async {
    return MeasurementSession(
      sessionId: sessionId,
      patientId: 'SUBJ_001',
      timestamp: DateTime.now(),
      status: ResearchSessionStatus.accepted,
      rawSampleCount: 1500,
      csvPath: '/data/research/$sessionId.csv',
    );
  }
}

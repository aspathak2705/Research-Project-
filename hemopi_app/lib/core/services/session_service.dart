import 'package:flutter/foundation.dart';
import '../models/measurement_session.dart';
import '../network/api_client.dart';

abstract class SessionService {
  ValueListenable<List<MeasurementSession>> get sessionsNotifier;
  Future<List<MeasurementSession>> getSessions();
}

class HttpSessionService implements SessionService {
  final ApiClient apiClient;
  final ValueNotifier<List<MeasurementSession>> _sessions = ValueNotifier([]);

  HttpSessionService({ApiClient? client}) : apiClient = client ?? ApiClient();

  @override
  ValueListenable<List<MeasurementSession>> get sessionsNotifier => _sessions;

  @override
  Future<List<MeasurementSession>> getSessions() async {
    try {
      final res = await apiClient.get('/api/sessions');
      if (res != null && res['sessions'] is List) {
        final List list = res['sessions'];
        final parsed = list.map((s) {
          return MeasurementSession(
            sessionId: s['session_id'],
            patientId: s['patient_id'],
            timestamp: DateTime.parse(s['timestamp']),
            status: ResearchSessionStatus.accepted,
            rawSampleCount: s['sample_count'] ?? 0,
            csvPath: null,
          );
        }).toList();
        _sessions.value = parsed;
        return parsed;
      }
    } catch (_) {}
    return _sessions.value;
  }
}

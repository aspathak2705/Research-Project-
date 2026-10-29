import 'package:flutter/foundation.dart';
import '../models/measurement_session.dart';
import '../storage/local_database_service.dart';
import '../network/api_client.dart';

abstract class SessionService {
  ValueListenable<List<MeasurementSession>> get sessionsNotifier;
  Future<List<MeasurementSession>> getSessions({String? patientId});
  Future<MeasurementSession?> getSession(String sessionId);
  Future<void> saveSession(MeasurementSession session);
}

class AndroidLocalSessionService implements SessionService {
  final LocalDatabaseService dbService;
  final ApiClient? apiClient;
  final ValueNotifier<List<MeasurementSession>> _sessions = ValueNotifier([]);

  AndroidLocalSessionService({LocalDatabaseService? db, this.apiClient})
      : dbService = db ?? LocalDatabaseService();

  @override
  ValueListenable<List<MeasurementSession>> get sessionsNotifier => _sessions;

  @override
  Future<List<MeasurementSession>> getSessions({String? patientId}) async {
    // 1. Fetch remote sessions from Raspberry Pi backend if available
    if (apiClient != null) {
      try {
        final res = await apiClient!.get('/api/sessions');
        if (res != null && res['sessions'] is List) {
          final List remoteSessions = res['sessions'];
          for (final item in remoteSessions) {
            try {
              final statusStr = (item['status'] ?? '').toString().toUpperCase();
              final isCompleted = statusStr == 'COMPLETED';
              final session = MeasurementSession(
                sessionId: item['session_id'],
                patientId: item['patient_id'],
                createdAt: DateTime.parse(item['timestamp']),
                completedAt: isCompleted ? DateTime.parse(item['timestamp']) : null,
                status: isCompleted ? SessionStatus.completed : SessionStatus.failed,
                sensorReadinessState: item['is_demo'] == true ? 'DEMO_ACQUISITION' : 'OPERATIONAL',
                attemptedSamples: item['sample_count'] ?? 0,
                validSamples: item['valid_count'] ?? 0,
                rejectedSamples: item['rejected_count'] ?? 0,
                validationStatus: isCompleted ? 'PASSED' : 'REJECTED',
                reportAvailable: isCompleted,
                localValidCsvFile: item['local_csv'],
                localSummaryFile: item['diagnostic_file'],
                errorMessage: item['message'],
                isDemo: item['is_demo'] == true,
                readings: item['readings'] is Map<String, dynamic> ? item['readings'] : null,
              );
              await dbService.insertSession(session);
            } catch (_) {}
          }
        }
      } catch (_) {
        // Backend offline or unreachable: fall back gracefully to local SQLite
      }
    }

    final list = await dbService.getSessions(patientId: patientId);
    _sessions.value = list;
    return list;
  }

  @override
  Future<MeasurementSession?> getSession(String sessionId) async {
    final local = await dbService.getSession(sessionId);
    if (local != null) return local;

    if (apiClient != null) {
      try {
        final item = await apiClient!.get('/api/sessions/$sessionId');
        if (item != null) {
          final statusStr = (item['status'] ?? '').toString().toUpperCase();
          final isCompleted = statusStr == 'COMPLETED';
          final session = MeasurementSession(
            sessionId: item['session_id'],
            patientId: item['patient_id'],
            createdAt: DateTime.parse(item['timestamp']),
            completedAt: isCompleted ? DateTime.parse(item['timestamp']) : null,
            status: isCompleted ? SessionStatus.completed : SessionStatus.failed,
            sensorReadinessState: item['is_demo'] == true ? 'DEMO_ACQUISITION' : 'OPERATIONAL',
            attemptedSamples: item['sample_count'] ?? 0,
            validSamples: item['valid_count'] ?? 0,
            rejectedSamples: item['rejected_count'] ?? 0,
            validationStatus: isCompleted ? 'PASSED' : 'REJECTED',
            reportAvailable: isCompleted,
            localValidCsvFile: item['local_csv'],
            localSummaryFile: item['diagnostic_file'],
            errorMessage: item['message'],
            isDemo: item['is_demo'] == true,
            readings: item['readings'] is Map<String, dynamic> ? item['readings'] : null,
          );
          await dbService.insertSession(session);
          return session;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<void> saveSession(MeasurementSession session) async {
    await dbService.insertSession(session);
    await getSessions();
  }
}

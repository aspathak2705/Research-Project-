import 'package:flutter/foundation.dart';
import '../models/measurement_session.dart';
import '../storage/local_database_service.dart';

abstract class SessionService {
  ValueListenable<List<MeasurementSession>> get sessionsNotifier;
  Future<List<MeasurementSession>> getSessions({String? patientId});
  Future<MeasurementSession?> getSession(String sessionId);
  Future<void> saveSession(MeasurementSession session);
}

class AndroidLocalSessionService implements SessionService {
  final LocalDatabaseService dbService;
  final ValueNotifier<List<MeasurementSession>> _sessions = ValueNotifier([]);

  AndroidLocalSessionService({LocalDatabaseService? db})
      : dbService = db ?? LocalDatabaseService();

  @override
  ValueListenable<List<MeasurementSession>> get sessionsNotifier => _sessions;

  @override
  Future<List<MeasurementSession>> getSessions({String? patientId}) async {
    final list = await dbService.getSessions(patientId: patientId);
    _sessions.value = list;
    return list;
  }

  @override
  Future<MeasurementSession?> getSession(String sessionId) async {
    return await dbService.getSession(sessionId);
  }

  @override
  Future<void> saveSession(MeasurementSession session) async {
    await dbService.insertSession(session);
    await getSessions();
  }
}

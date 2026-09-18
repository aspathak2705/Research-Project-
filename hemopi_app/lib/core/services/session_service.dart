import 'package:flutter/foundation.dart';
import '../models/measurement_session.dart';

abstract class SessionService {
  ValueListenable<List<MeasurementSession>> get sessionsNotifier;
  Future<List<MeasurementSession>> getSessions();
}

class Phase1SessionService implements SessionService {
  final ValueNotifier<List<MeasurementSession>> _sessions = ValueNotifier([]);

  @override
  ValueListenable<List<MeasurementSession>> get sessionsNotifier => _sessions;

  @override
  Future<List<MeasurementSession>> getSessions() async {
    return _sessions.value;
  }
}

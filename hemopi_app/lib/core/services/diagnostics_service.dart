import 'package:flutter/foundation.dart';
import '../models/diagnostics_summary.dart';

abstract class DiagnosticsService {
  ValueListenable<List<DiagnosticsSummary>> get diagnosticsNotifier;
  Future<DiagnosticsSummary> getDiagnostics();
}

class Phase1DiagnosticsService implements DiagnosticsService {
  final ValueNotifier<List<DiagnosticsSummary>> _diagnostics = ValueNotifier([]);

  @override
  ValueListenable<List<DiagnosticsSummary>> get diagnosticsNotifier => _diagnostics;

  @override
  Future<DiagnosticsSummary> getDiagnostics() async {
    return DiagnosticsSummary(
      lastRunTimestamp: DateTime.now(),
      i2cBusOk: true,
      max30102Ok: true,
      as7341Ok: true,
      storageOk: true,
      rejectedMeasurementsCount: 0,
      recentError: 'None',
    );
  }
}

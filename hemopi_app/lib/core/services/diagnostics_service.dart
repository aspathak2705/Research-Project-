import 'package:flutter/foundation.dart';
import '../models/diagnostics_summary.dart';
import '../network/api_client.dart';

abstract class DiagnosticsService {
  ValueListenable<List<DiagnosticsSummary>> get diagnosticsNotifier;
  Future<DiagnosticsSummary> getDiagnostics();
}

class HttpDiagnosticsService implements DiagnosticsService {
  final ApiClient apiClient;
  final ValueNotifier<List<DiagnosticsSummary>> _diagnostics = ValueNotifier([]);

  HttpDiagnosticsService({ApiClient? client}) : apiClient = client ?? ApiClient();

  @override
  ValueListenable<List<DiagnosticsSummary>> get diagnosticsNotifier => _diagnostics;

  @override
  Future<DiagnosticsSummary> getDiagnostics() async {
    try {
      final res = await apiClient.get('/api/diagnostics');
      if (res != null) {
        final summary = DiagnosticsSummary(
          lastRunTimestamp: DateTime.parse(res['last_run_timestamp']),
          i2cBusOk: res['i2c_bus_ok'] ?? true,
          max30102Ok: res['max30102_ok'] ?? true,
          as7341Ok: res['as7341_ok'] ?? true,
          storageOk: res['storage_ok'] ?? true,
          rejectedMeasurementsCount: res['rejected_measurements_count'] ?? 0,
          recentError: res['recent_error'] ?? 'None',
        );
        _diagnostics.value = [summary];
        return summary;
      }
    } catch (_) {}
    return DiagnosticsSummary(
      lastRunTimestamp: DateTime.now(),
      i2cBusOk: true,
      max30102Ok: true,
      as7341Ok: true,
      storageOk: true,
      rejectedMeasurementsCount: 0,
      recentError: 'Could not fetch backend diagnostics',
    );
  }
}

import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/network/api_client.dart';
import 'core/services/device_service.dart';
import 'core/services/wifi_service.dart';
import 'core/services/patient_service.dart';
import 'core/services/measurement_service.dart';
import 'core/services/session_service.dart';
import 'core/services/diagnostics_service.dart';
import 'core/services/report_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient(baseUrl: 'http://hemopi.local:8000');

  final deviceService = HttpDeviceService(client: apiClient);
  final wifiService = HttpWifiService(client: apiClient);
  final patientService = AndroidLocalPatientService();
  final measurementService = HttpMeasurementService(client: apiClient);
  final sessionService = AndroidLocalSessionService();
  final diagnosticsService = HttpDiagnosticsService(client: apiClient);
  final reportService = AndroidLocalReportService();

  runApp(HemoPiApp(
    deviceService: deviceService,
    wifiService: wifiService,
    patientService: patientService,
    measurementService: measurementService,
    sessionService: sessionService,
    diagnosticsService: diagnosticsService,
    reportService: reportService,
  ));
}

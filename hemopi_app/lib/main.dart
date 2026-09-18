import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/device_service.dart';
import 'core/services/wifi_service.dart';
import 'core/services/patient_service.dart';
import 'core/services/measurement_service.dart';
import 'core/services/session_service.dart';
import 'core/services/diagnostics_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final deviceService = Phase1DeviceService();
  final wifiService = Phase1WifiService();
  final patientService = Phase1PatientService();
  final measurementService = Phase1MeasurementService();
  final sessionService = Phase1SessionService();
  final diagnosticsService = Phase1DiagnosticsService();

  runApp(HemoPiApp(
    deviceService: deviceService,
    wifiService: wifiService,
    patientService: patientService,
    measurementService: measurementService,
    sessionService: sessionService,
    diagnosticsService: diagnosticsService,
  ));
}

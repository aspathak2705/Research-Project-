import 'package:flutter/material.dart';
import 'theme.dart';
import 'routes.dart';
import '../core/services/device_service.dart';
import '../core/services/wifi_service.dart';
import '../core/services/patient_service.dart';
import '../core/services/measurement_service.dart';
import '../core/services/session_service.dart';
import '../core/services/diagnostics_service.dart';
import '../core/services/report_service.dart';
import '../core/models/patient.dart';
import '../core/models/measurement_session.dart';
import '../core/models/report_metadata.dart';

import '../features/onboarding/screens/device_discovery_screen.dart';
import '../features/wifi/screens/wifi_setup_screen.dart';
import '../features/device/screens/connection_validation_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/device/screens/device_status_screen.dart';
import '../features/patients/screens/patient_list_screen.dart';
import '../features/patients/screens/add_patient_screen.dart';
import '../features/patients/screens/patient_detail_screen.dart';
import '../features/measurement/screens/measurement_setup_screen.dart';
import '../features/measurement/screens/measurement_progress_screen.dart';
import '../features/sessions/screens/session_result_screen.dart';
import '../features/sessions/screens/session_history_screen.dart';
import '../features/sessions/screens/session_details_screen.dart';
import '../features/diagnostics/screens/diagnostics_screen.dart';
import '../features/reports/screens/recent_reports_screen.dart';
import '../features/reports/screens/report_history_screen.dart';
import '../features/reports/screens/report_details_screen.dart';
import '../features/storage/screens/local_storage_management_screen.dart';

class HemoPiApp extends StatelessWidget {
  final DeviceService deviceService;
  final WifiService wifiService;
  final PatientService patientService;
  final MeasurementService measurementService;
  final SessionService sessionService;
  final DiagnosticsService diagnosticsService;
  final ReportService reportService;

  const HemoPiApp({
    super.key,
    required this.deviceService,
    required this.wifiService,
    required this.patientService,
    required this.measurementService,
    required this.sessionService,
    required this.diagnosticsService,
    required this.reportService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HemoPi',
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.deviceDiscovery,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.deviceDiscovery:
            return MaterialPageRoute(
              builder: (_) => DeviceDiscoveryScreen(deviceService: deviceService),
            );
          case AppRoutes.wifiSetup:
            return MaterialPageRoute(
              builder: (_) => WifiSetupScreen(wifiService: wifiService),
            );
          case AppRoutes.connectionValidation:
            return MaterialPageRoute(
              builder: (_) => ConnectionValidationScreen(deviceService: deviceService),
            );
          case AppRoutes.dashboard:
            return MaterialPageRoute(
              builder: (_) => DashboardScreen(
                deviceService: deviceService,
                patientService: patientService,
                reportService: reportService,
              ),
            );
          case AppRoutes.deviceStatus:
            return MaterialPageRoute(
              builder: (_) => DeviceStatusScreen(deviceService: deviceService),
            );
          case AppRoutes.patientList:
            return MaterialPageRoute(
              builder: (_) => PatientListScreen(patientService: patientService),
            );
          case AppRoutes.addPatient:
            return MaterialPageRoute(
              builder: (_) => AddPatientScreen(patientService: patientService),
            );
          case AppRoutes.patientDetail:
            final patient = settings.arguments as Patient;
            return MaterialPageRoute(
              builder: (_) => PatientDetailScreen(patient: patient),
            );
          case AppRoutes.measurementSetup:
            final patient = settings.arguments as Patient?;
            return MaterialPageRoute(
              builder: (_) => MeasurementSetupScreen(
                patient: patient,
                deviceService: deviceService,
                measurementService: measurementService,
              ),
            );
          case AppRoutes.measurementProgress:
            final args = settings.arguments as Map<String, dynamic>?;
            final patient = args?['patient'] as Patient?;
            return MaterialPageRoute(
              builder: (_) => MeasurementProgressScreen(
                patient: patient,
                measurementService: measurementService,
              ),
            );
          case AppRoutes.sessionResult:
            final session = settings.arguments as MeasurementSession;
            return MaterialPageRoute(
              builder: (_) => SessionResultScreen(session: session),
            );
          case AppRoutes.sessionHistory:
            return MaterialPageRoute(
              builder: (_) => SessionHistoryScreen(sessionService: sessionService),
            );
          case AppRoutes.sessionDetails:
            final session = settings.arguments as MeasurementSession;
            return MaterialPageRoute(
              builder: (_) => SessionDetailsScreen(session: session),
            );
          case AppRoutes.diagnostics:
            return MaterialPageRoute(
              builder: (_) => DiagnosticsScreen(diagnosticsService: diagnosticsService),
            );
          case AppRoutes.recentReports:
            return MaterialPageRoute(
              builder: (_) => RecentReportsScreen(reportService: reportService),
            );
          case AppRoutes.reportHistory:
            return MaterialPageRoute(
              builder: (_) => ReportHistoryScreen(reportService: reportService),
            );
          case AppRoutes.reportDetails:
            final report = settings.arguments as ReportMetadata;
            return MaterialPageRoute(
              builder: (_) => ReportDetailsScreen(report: report, reportService: reportService),
            );
          case AppRoutes.localStorageManagement:
            return MaterialPageRoute(
              builder: (_) => LocalStorageManagementScreen(
                patientService: patientService,
                sessionService: sessionService,
                reportService: reportService,
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => DeviceDiscoveryScreen(deviceService: deviceService),
            );
        }
      },
    );
  }
}

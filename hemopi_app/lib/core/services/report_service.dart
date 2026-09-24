import 'package:flutter/foundation.dart';
import '../models/report_metadata.dart';
import '../models/measurement_session.dart';
import '../models/patient.dart';
import '../storage/local_database_service.dart';
import '../storage/local_file_service.dart';

abstract class ReportService {
  ValueListenable<List<ReportMetadata>> get reportsNotifier;
  Future<List<ReportMetadata>> getReports({String? patientId, int? limit});
  Future<ReportMetadata?> getReport(String reportId);
  Future<ReportMetadata?> generateReportForSession({
    required MeasurementSession session,
    required Patient patient,
    String? validCsvContent,
    String? rejectedCsvContent,
  });
  Future<String?> readReportCsvContent(ReportMetadata report);
  Future<String?> readReportSummaryText(ReportMetadata report);
  Future<void> clearAllData();
}

class AndroidLocalReportService implements ReportService {
  final LocalDatabaseService dbService;
  final LocalFileService fileService;
  final ValueNotifier<List<ReportMetadata>> _reports = ValueNotifier([]);

  AndroidLocalReportService({
    LocalDatabaseService? db,
    LocalFileService? file,
  })  : dbService = db ?? LocalDatabaseService(),
        fileService = file ?? LocalFileService();

  @override
  ValueListenable<List<ReportMetadata>> get reportsNotifier => _reports;

  @override
  Future<List<ReportMetadata>> getReports({String? patientId, int? limit}) async {
    final list = await dbService.getReports(patientId: patientId, limit: limit);
    _reports.value = list;
    return list;
  }

  @override
  Future<ReportMetadata?> getReport(String reportId) async {
    return await dbService.getReport(reportId);
  }

  @override
  Future<ReportMetadata?> generateReportForSession({
    required MeasurementSession session,
    required Patient patient,
    String? validCsvContent,
    String? rejectedCsvContent,
  }) async {
    final now = DateTime.now();
    final reportId = 'REP_${session.sessionId}';
    final isComplete = session.status == SessionStatus.completed && session.validSamples > 0;

    String? validCsvPath;
    if (validCsvContent != null && validCsvContent.isNotEmpty) {
      validCsvPath = await fileService.saveSessionCsv(
        sessionId: session.sessionId,
        fileName: 'valid_samples.csv',
        csvContent: validCsvContent,
      );
    }

    if (rejectedCsvContent != null && rejectedCsvContent.isNotEmpty) {
      await fileService.saveSessionCsv(
        sessionId: session.sessionId,
        fileName: 'rejected_samples.csv',
        csvContent: rejectedCsvContent,
      );
    }

    final summaryText = '''
============================================================
HEMOPI RESEARCH ACQUISITION SESSION SUMMARY
============================================================
Report ID: $reportId
Session ID: ${session.sessionId}
Subject ID: ${patient.patientId}
Subject Code: ${patient.anonymizedCode}
Timestamp: ${now.toIso8601String()}
Status: ${session.status.name.toUpperCase()}

ACQUISITION METRICS:
Attempted Samples: ${session.attemptedSamples}
Valid Samples: ${session.validSamples}
Rejected Samples: ${session.rejectedSamples}
Validation Status: ${session.validationStatus}

RESEARCH NOTICE:
This report was generated from locally stored physical sensor measurements on the Android client.
HemoPi is a non-invasive optical research instrument and is NOT a clinically validated diagnostic device.
============================================================
''';

    await fileService.saveReportText(
      reportId: reportId,
      content: summaryText,
    );

    final report = ReportMetadata(
      reportId: reportId,
      sessionId: session.sessionId,
      patientId: patient.patientId,
      anonymizedCode: patient.anonymizedCode,
      generatedAt: now,
      status: session.status.name.toUpperCase(),
      validSampleCount: session.validSamples,
      rejectedSampleCount: session.rejectedSamples,
      validationStatus: session.validationStatus,
      pdfRelativePath: 'reports/$reportId.txt',
      csvRelativePath: validCsvPath,
      isComplete: isComplete,
    );

    await dbService.insertReport(report);
    await getReports();
    return report;
  }

  @override
  Future<String?> readReportCsvContent(ReportMetadata report) async {
    if (report.csvRelativePath == null) return null;
    return await fileService.readRelativeFile(report.csvRelativePath!);
  }

  @override
  Future<String?> readReportSummaryText(ReportMetadata report) async {
    if (report.pdfRelativePath == null) return null;
    return await fileService.readRelativeFile(report.pdfRelativePath!);
  }

  @override
  Future<void> clearAllData() async {
    await dbService.clearAllLocalData();
    await fileService.deleteAllFiles();
    await getReports();
  }
}

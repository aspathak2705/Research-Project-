import 'package:flutter/material.dart';
import '../../../core/services/patient_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/report_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/clinical_notice_banner.dart';
import '../../../shared/widgets/clinical_detail_row.dart';
import '../../../shared/widgets/clinical_confirm_dialog.dart';
import '../../../app/design_tokens.dart';

class LocalStorageManagementScreen extends StatefulWidget {
  final PatientService patientService;
  final SessionService sessionService;
  final ReportService reportService;

  const LocalStorageManagementScreen({
    super.key,
    required this.patientService,
    required this.sessionService,
    required this.reportService,
  });

  @override
  State<LocalStorageManagementScreen> createState() => _LocalStorageManagementScreenState();
}

class _LocalStorageManagementScreenState extends State<LocalStorageManagementScreen> {
  int _patientCount = 0;
  int _sessionCount = 0;
  int _reportCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    final patients = await widget.patientService.getPatients();
    final sessions = await widget.sessionService.getSessions();
    final reports = await widget.reportService.getReports();
    if (mounted) {
      setState(() {
        _patientCount = patients.length;
        _sessionCount = sessions.length;
        _reportCount = reports.length;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmClearData() async {
    final confirm = await ClinicalConfirmDialog.show(
      context,
      title: 'Clear Local Storage?',
      message:
          'This will permanently delete all locally stored research subjects, session metadata, CSV records, and generated reports from this device. This operation is irreversible.',
      confirmLabel: 'Clear All Data',
      cancelLabel: 'Keep Data',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );

    if (confirm == true) {
      await widget.reportService.clearAllData();
      await _loadMetrics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local data cleared successfully.'),
            backgroundColor: AppColors.statusSuccess,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClinicalScaffold(
      appBar: AppBar(
        title: const Text('Settings & Local Storage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Storage Metrics',
            onPressed: _loadMetrics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomCard(
                    title: 'Local Storage Ownership',
                    subtitle: 'Local SQLite and document directory status',
                    child: Column(
                      children: [
                        ClinicalDetailRow(label: 'Registered Patients', value: '$_patientCount'),
                        const Divider(),
                        ClinicalDetailRow(label: 'Recorded Sessions', value: '$_sessionCount'),
                        const Divider(),
                        ClinicalDetailRow(label: 'Saved Reports', value: '$_reportCount'),
                        const Divider(),
                        const ClinicalDetailRow(label: 'Storage Location', value: 'App Documents Directory'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  const ClinicalNoticeBanner.info(
                    title: 'Local Privacy Policy',
                    message:
                        'All research patient data and measurement recordings remain strictly on this local device. The Raspberry Pi backend serves solely as a hardware sensor interface and does not retain permanent clinical records.',
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusError,
                      side: const BorderSide(color: AppColors.statusErrorBorder),
                    ),
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Clear All Local Data'),
                    onPressed: _confirmClearData,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
    );
  }
}

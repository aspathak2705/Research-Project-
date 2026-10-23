import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/report_metadata.dart';
import '../../../core/services/report_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/clinical_notice_banner.dart';
import '../../../shared/widgets/clinical_detail_row.dart';
import '../../../app/design_tokens.dart';

class ReportDetailsScreen extends StatefulWidget {
  final ReportMetadata report;
  final ReportService reportService;

  const ReportDetailsScreen({
    super.key,
    required this.report,
    required this.reportService,
  });

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  String? _csvContent;
  String? _summaryText;
  bool _isLoadingContent = true;

  @override
  void initState() {
    super.initState();
    _loadReportFiles();
  }

  Future<void> _loadReportFiles() async {
    setState(() => _isLoadingContent = true);
    final csv = await widget.reportService.readReportCsvContent(widget.report);
    final summary = await widget.reportService.readReportSummaryText(widget.report);
    if (mounted) {
      setState(() {
        _csvContent = csv;
        _summaryText = summary;
        _isLoadingContent = false;
      });
    }
  }

  Future<void> _shareReport() async {
    if (_summaryText != null) {
      // ignore: deprecated_member_use
      await Share.share(_summaryText!, subject: 'HemoPi Research Report ${widget.report.reportId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return ClinicalScaffold(
      appBar: AppBar(
        title: Text('Report ${report.reportId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Report',
            onPressed: _summaryText != null ? _shareReport : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomCard(
              title: 'Report Summary',
              subtitle: 'Subject Code: ${report.anonymizedCode}',
              trailing: StatusBadge(
                label: report.isComplete ? 'Complete' : 'Pending',
                type: report.isComplete ? BadgeType.success : BadgeType.warning,
              ),
              child: Column(
                children: [
                  ClinicalDetailRow(label: 'Report ID', value: report.reportId),
                  const Divider(),
                  ClinicalDetailRow(label: 'Session ID', value: report.sessionId),
                  const Divider(),
                  ClinicalDetailRow(
                    label: 'Generated At',
                    value: report.generatedAt.toIso8601String().replaceAll('T', ' ').substring(0, 19),
                  ),
                  const Divider(),
                  ClinicalDetailRow(label: 'Status', value: report.status),
                  const Divider(),
                  ClinicalDetailRow(label: 'Valid Samples', value: '${report.validSampleCount}'),
                  const Divider(),
                  ClinicalDetailRow(label: 'Rejected Samples', value: '${report.rejectedSampleCount}'),
                  const Divider(),
                  ClinicalDetailRow(label: 'Validation Status', value: report.validationStatus),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            const ClinicalNoticeBanner(
              title: 'Investigational Research Artifact',
              message:
                  'This report contains non-invasive observational optical records. It has not been approved for standalone medical diagnosis or therapeutic intervention.',
            ),
            const SizedBox(height: AppSpacing.md),

            // Raw CSV Data Preview Card
            CustomCard(
              title: 'Measurement Records Preview',
              subtitle: 'Authentic physical counts recorded during session',
              child: _isLoadingContent
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  : (_csvContent == null || _csvContent!.isEmpty)
                      ? const Text(
                          'No CSV data file is stored locally for this session.',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              _csvContent!.split('\n').take(12).join('\n'),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

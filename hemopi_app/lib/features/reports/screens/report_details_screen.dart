import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/report_metadata.dart';
import '../../../core/services/report_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text('Report: ${report.reportId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _summaryText != null ? _shareReport : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomCard(
              title: 'Report Metadata',
              subtitle: 'Subject Code: ${report.anonymizedCode}',
              child: Column(
                children: [
                  _buildRow('Report ID', report.reportId),
                  _buildRow('Session ID', report.sessionId),
                  _buildRow('Generated At', report.generatedAt.toIso8601String().replaceAll('T', ' ').substring(0, 19)),
                  _buildRow('Status', report.status),
                  _buildRow('Valid Samples', '${report.validSampleCount}'),
                  _buildRow('Rejected Samples', '${report.rejectedSampleCount}'),
                  _buildRow('Validation Status', report.validationStatus),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              title: 'Report Readiness & Integrity Notice',
              subtitle: 'Research Device Disclosure',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Completion Status', style: TextStyle(fontWeight: FontWeight.bold)),
                      StatusBadge(
                        label: report.isComplete ? 'Complete' : 'Incomplete / Pending',
                        type: report.isComplete ? BadgeType.success : BadgeType.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'NOTICE: HemoPi is a non-invasive optical research instrument. This report contains locally persisted physical sensor readings and does NOT constitute a clinically validated diagnostic hemoglobin measurement.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              title: 'Summary Text Log',
              subtitle: 'Locally generated text report',
              child: _isLoadingContent
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _summaryText ?? 'No summary text available.',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              title: 'CSV Data File',
              subtitle: 'Physical sensor measurements',
              child: _isLoadingContent
                  ? const Center(child: CircularProgressIndicator())
                  : _csvContent == null
                      ? const Text('No CSV file associated or available for this report.')
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _csvContent!.length > 500
                                ? '${_csvContent!.substring(0, 500)}\n...[Truncated]'
                                : _csvContent!,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                          ),
                        ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Export / Share Report Summary'),
                onPressed: _summaryText != null ? _shareReport : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/models/report_metadata.dart';
import '../../../core/services/report_service.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../app/design_tokens.dart';
import '../../../app/routes.dart';

class RecentReportsScreen extends StatefulWidget {
  final ReportService reportService;

  const RecentReportsScreen({
    super.key,
    required this.reportService,
  });

  @override
  State<RecentReportsScreen> createState() => _RecentReportsScreenState();
}

class _RecentReportsScreenState extends State<RecentReportsScreen> {
  List<ReportMetadata> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentReports();
  }

  Future<void> _loadRecentReports() async {
    setState(() => _isLoading = true);
    final reports = await widget.reportService.getReports(limit: 15);
    if (mounted) {
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClinicalScaffold(
      appBar: AppBar(
        title: const Text('Research Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadRecentReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _reports.isEmpty
              ? const StateView(
                  icon: Icons.assignment_outlined,
                  title: 'No Reports Generated Yet',
                  description:
                      'Research reports are created automatically after valid physical acquisition sessions.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  itemCount: _reports.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    final dateStr = report.generatedAt.toIso8601String().replaceAll('T', ' ').substring(0, 16);

                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: report.isComplete ? AppColors.statusSuccessBg : AppColors.statusWarningBg,
                          child: Icon(
                            report.isComplete ? Icons.assignment_turned_in_rounded : Icons.pending_actions_rounded,
                            color: report.isComplete ? AppColors.statusSuccess : AppColors.statusWarning,
                          ),
                        ),
                        title: Text(
                          report.reportId,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            'Subject: ${report.anonymizedCode}  •  $dateStr\nValid Samples: ${report.validSampleCount}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.reportDetails,
                            arguments: report,
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

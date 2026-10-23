import 'package:flutter/material.dart';
import '../../../core/models/report_metadata.dart';
import '../../../core/services/report_service.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../app/design_tokens.dart';
import '../../../app/routes.dart';

class ReportHistoryScreen extends StatefulWidget {
  final ReportService reportService;

  const ReportHistoryScreen({
    super.key,
    required this.reportService,
  });

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<ReportMetadata> _allReports = [];
  List<ReportMetadata> _filteredReports = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllReports() async {
    setState(() => _isLoading = true);
    final list = await widget.reportService.getReports();
    if (mounted) {
      setState(() {
        _allReports = list;
        _filteredReports = list;
        _isLoading = false;
      });
    }
  }

  void _filterReports(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredReports = _allReports;
      } else {
        _filteredReports = _allReports.where((r) {
          return r.reportId.toLowerCase().contains(q) ||
              r.anonymizedCode.toLowerCase().contains(q) ||
              r.sessionId.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClinicalScaffold(
      appBar: AppBar(
        title: const Text('Report History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadAllReports,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              onChanged: _filterReports,
              decoration: InputDecoration(
                hintText: 'Search reports by subject or report ID…',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _filterReports('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: AppSpacing.md),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredReports.isEmpty
                    ? StateView(
                        icon: Icons.history_toggle_off_rounded,
                        title: _allReports.isEmpty ? 'No Reports Found' : 'No Matching Reports',
                        description: _allReports.isEmpty
                            ? 'Complete a measurement session to automatically produce observational reports.'
                            : 'Check your search query or clear the filter.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        itemCount: _filteredReports.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final report = _filteredReports[index];
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
                                  'Subject: ${report.anonymizedCode}  •  $dateStr\nValid: ${report.validSampleCount}  Rejected: ${report.rejectedSampleCount}',
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
          ),
        ],
      ),
    );
  }
}

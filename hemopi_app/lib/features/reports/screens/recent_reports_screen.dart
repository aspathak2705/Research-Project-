import 'package:flutter/material.dart';
import '../../../core/models/report_metadata.dart';
import '../../../core/services/report_service.dart';
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
    return Scaffold(
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
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No Reports Generated Yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Research reports are created automatically after valid physical acquisition sessions.',
                          style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _reports.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    final dateStr = report.generatedAt.toIso8601String().replaceAll('T', ' ').substring(0, 16);

                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: report.isComplete ? const Color(0xFFE8F5E9) : const Color(0xFFFEF3C7),
                          child: Icon(
                            report.isComplete ? Icons.assignment_turned_in_rounded : Icons.pending_actions_rounded,
                            color: report.isComplete ? const Color(0xFF0D8A58) : const Color(0xFFD97706),
                          ),
                        ),
                        title: Text(
                          'Report: ${report.reportId}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Subject: ${report.anonymizedCode}  •  $dateStr\n${report.validSampleCount} valid samples',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
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

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
    final reports = await widget.reportService.getReports(limit: 10);
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
        title: const Text('Recent Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecentReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No reports generated yet.', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text(
                        'Reports are generated locally after physical acquisition sessions.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: report.isComplete ? Colors.teal.shade50 : Colors.amber.shade50,
                          child: Icon(
                            report.isComplete ? Icons.assignment_turned_in : Icons.assignment_late,
                            color: report.isComplete ? Colors.teal.shade800 : Colors.amber.shade900,
                          ),
                        ),
                        title: Text('Report: ${report.reportId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Subject: ${report.anonymizedCode}\nValid: ${report.validSampleCount} | Rejected: ${report.rejectedSampleCount}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
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

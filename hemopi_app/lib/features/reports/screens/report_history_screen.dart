import 'package:flutter/material.dart';
import '../../../core/models/report_metadata.dart';
import '../../../core/services/report_service.dart';
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
    if (query.isEmpty) {
      setState(() => _filteredReports = _allReports);
    } else {
      final q = query.toLowerCase();
      setState(() {
        _filteredReports = _allReports.where((r) {
          return r.reportId.toLowerCase().contains(q) ||
              r.anonymizedCode.toLowerCase().contains(q) ||
              r.sessionId.toLowerCase().contains(q);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Reports / History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllReports,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterReports,
              decoration: const InputDecoration(
                labelText: 'Search Reports',
                hintText: 'Search by Report ID, Subject Code, Session ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                    ? const Center(child: Text('No matching reports found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredReports.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final report = _filteredReports[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: report.isComplete ? Colors.teal.shade50 : Colors.amber.shade50,
                                child: Icon(
                                  report.isComplete ? Icons.assessment : Icons.warning_amber_rounded,
                                  color: report.isComplete ? Colors.teal.shade800 : Colors.amber.shade900,
                                ),
                              ),
                              title: Text('Report: ${report.reportId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Subject: ${report.anonymizedCode} | Status: ${report.status}\nValid: ${report.validSampleCount} | Rejected: ${report.rejectedSampleCount}',
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
          ),
        ],
      ),
    );
  }
}

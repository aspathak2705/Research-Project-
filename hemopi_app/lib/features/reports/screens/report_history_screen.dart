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
    return Scaffold(
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterReports,
              decoration: InputDecoration(
                hintText: 'Search reports by subject or report ID…',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _filterReports('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
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
                                child: const Icon(Icons.find_in_page_outlined, size: 48, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'No Reports Found',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'No reports match your current search query.',
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredReports.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final report = _filteredReports[index];
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
                                  'Subject: ${report.anonymizedCode}  •  $dateStr\nValid Samples: ${report.validSampleCount}',
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
          ),
        ],
      ),
    );
  }
}

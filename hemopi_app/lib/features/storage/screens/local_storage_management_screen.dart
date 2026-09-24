import 'package:flutter/material.dart';
import '../../../core/services/patient_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/report_service.dart';
import '../../../shared/widgets/custom_card.dart';

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Local Android Data?'),
        content: const Text(
          'WARNING: This will permanently delete all locally stored research subjects, session metadata, CSV files, and generated reports from this Android device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.reportService.clearAllData();
      await _loadMetrics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local Android data cleared successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Data & Storage Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CustomCard(
                    title: 'Android Local Storage Ownership',
                    subtitle: 'Local SQLite & Document Directory Status',
                    child: Column(
                      children: [
                        _buildMetricRow('Registered Subjects', '$_patientCount'),
                        _buildMetricRow('Acquisition Sessions', '$_sessionCount'),
                        _buildMetricRow('Generated Reports', '$_reportCount'),
                        _buildMetricRow('Storage Location', 'App Documents Directory'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const CustomCard(
                    title: 'Data Privacy & Ownership Notice',
                    subtitle: 'No Cloud Sync Policy',
                    child: Text(
                      'All research data is strictly stored locally on this Android client. The Raspberry Pi backend serves as a hardware sensor provider and does NOT act as a permanent source of truth for patient records or measurement CSVs.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Clear All Local Android Data'),
                      onPressed: _confirmClearData,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
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

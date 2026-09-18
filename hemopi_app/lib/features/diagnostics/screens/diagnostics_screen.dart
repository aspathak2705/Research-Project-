import 'package:flutter/material.dart';
import '../../../core/models/diagnostics_summary.dart';
import '../../../core/services/diagnostics_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';

class DiagnosticsScreen extends StatefulWidget {
  final DiagnosticsService diagnosticsService;

  const DiagnosticsScreen({
    super.key,
    required this.diagnosticsService,
  });

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  DiagnosticsSummary? _diagnostics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await widget.diagnosticsService.getDiagnostics();
      if (mounted) {
        setState(() {
          _diagnostics = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDiagnostics,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CustomCard(
                        title: 'Acquisition & System Integrity',
                        subtitle: 'Last diagnostic run: ${_diagnostics?.lastRunTimestamp.toIso8601String().substring(0, 19)}',
                        child: Column(
                          children: [
                            _buildDiagRow(
                              'I2C Bus Communication (Bus 1)',
                              _diagnostics?.i2cBusOk == true,
                              _diagnostics?.i2cBusOk == true ? 'OK' : 'Error',
                            ),
                            const Divider(),
                            _buildDiagRow(
                              'MAX30102 Physical Address 0x57',
                              _diagnostics?.max30102Ok == true,
                              _diagnostics?.max30102Ok == true ? 'Detected' : 'Missing',
                            ),
                            const Divider(),
                            _buildDiagRow(
                              'AS7341 Physical Address 0x39',
                              _diagnostics?.as7341Ok == true,
                              _diagnostics?.as7341Ok == true ? 'Detected' : 'Missing',
                            ),
                            const Divider(),
                            _buildDiagRow(
                              'Research CSV Storage Path',
                              _diagnostics?.storageOk == true,
                              _diagnostics?.storageOk == true ? 'Writable' : 'Error',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomCard(
                        title: 'Rejection Log Summary',
                        subtitle: 'Phase 2/3 - Discarded measurements',
                        child: Column(
                          children: [
                            _buildTextRow('Total Out-of-Range Rejections', '${_diagnostics?.rejectedMeasurementsCount ?? 0}'),
                            _buildTextRow('Recent Diagnostic Error', _diagnostics?.recentError ?? 'None reported'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDiagRow(String label, bool isOk, String statusText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          StatusBadge(
            label: statusText,
            type: isOk ? BadgeType.success : BadgeType.error,
          ),
        ],
      ),
    );
  }

  Widget _buildTextRow(String label, String value) {
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

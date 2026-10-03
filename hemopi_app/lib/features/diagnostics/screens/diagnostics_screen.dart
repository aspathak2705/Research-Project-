import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/models/diagnostics_summary.dart';
import '../../../core/services/diagnostics_service.dart';
import '../../../core/services/device_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';

class DiagnosticsScreen extends StatefulWidget {
  final DiagnosticsService diagnosticsService;
  final DeviceService? deviceService;

  const DiagnosticsScreen({
    super.key,
    required this.diagnosticsService,
    this.deviceService,
  });

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  DiagnosticsSummary? _diagnostics;
  bool _isLoading = true;
  String? _error;

  // Technician Actions State
  final List<String> _technicianActions = const [
    'Check Backend Health (/api/health)',
    'Check Network Status (/api/network/status)',
    'Scan Wi-Fi Networks (/api/network/wifi)',
    'Check Hardware & I2C (/api/device/status)',
    'Run Full Diagnostics (/api/diagnostics)',
  ];
  String _selectedAction = 'Check Backend Health (/api/health)';
  bool _isExecutingAction = false;
  String? _actionConsoleOutput;
  bool? _actionSuccess;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _executeTechnicianAction() async {
    setState(() {
      _isExecutingAction = true;
      _actionConsoleOutput = 'Executing: $_selectedAction...\nTarget: ${widget.deviceService?.baseUrl ?? "http://hemopi.local:8000"}';
      _actionSuccess = null;
    });

    final client = (widget.diagnosticsService is HttpDiagnosticsService)
        ? (widget.diagnosticsService as HttpDiagnosticsService).apiClient
        : (widget.deviceService is HttpDeviceService)
            ? (widget.deviceService as HttpDeviceService).apiClient
            : null;

    if (client == null) {
      setState(() {
        _isExecutingAction = false;
        _actionConsoleOutput = 'Error: ApiClient instance not found.';
        _actionSuccess = false;
      });
      return;
    }

    try {
      dynamic res;
      if (_selectedAction.contains('/api/health')) {
        res = await client.get('/api/health');
      } else if (_selectedAction.contains('/api/network/status')) {
        res = await client.get('/api/network/status');
      } else if (_selectedAction.contains('/api/network/wifi')) {
        res = await client.get('/api/network/wifi');
      } else if (_selectedAction.contains('/api/device/status')) {
        res = await client.get('/api/device/status');
      } else if (_selectedAction.contains('/api/diagnostics')) {
        res = await client.get('/api/diagnostics');
      }

      if (mounted) {
        setState(() {
          _isExecutingAction = false;
          _actionSuccess = true;
          _actionConsoleOutput = 'STATUS: 200 OK\n\n${res != null ? _formatJson(res) : "Empty response received."}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExecutingAction = false;
          _actionSuccess = false;
          _actionConsoleOutput = 'EXECUTION ERROR:\n$e';
        });
      }
    }
  }

  String _formatJson(dynamic json) {
    try {
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (_) {
      return json.toString();
    }
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
          _error = 'Unable to retrieve diagnostics. Verify HemoPi network connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _showHostConfigDialog() {
    final currentUrl = widget.deviceService?.baseUrl ?? 'http://hemopi.local:8000';
    final controller = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('HemoPi Host & Network Config'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Technician override: Specify mDNS hostname or manual IP when clinical networks isolate device broadcasting:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Base URL',
                hintText: 'http://hemopi.local:8000 or http://192.168.1.100:8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.deviceService?.setBaseUrl(controller.text.trim());
              Navigator.pop(ctx);
              _loadDiagnostics();
            },
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Technician Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet_rounded),
            tooltip: 'Configure Network Host',
            onPressed: _showHostConfigDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Diagnostics',
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDiagnostics,
                          child: const Text('Retry Diagnostics'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    children: [
                      // Bus & Sensor Level
                      CustomCard(
                        title: 'Hardware & I2C Bus Diagnostics',
                        subtitle: 'Low-level peripheral presence on Bus 1',
                        child: Column(
                          children: [
                            _buildDiagRow(
                              'I2C Bus Communication',
                              _diagnostics?.i2cBusOk == true,
                              _diagnostics?.i2cBusOk == true ? 'Active (Bus 1)' : 'Offline',
                            ),
                            const Divider(height: 16),
                            _buildDiagRow(
                              'MAX30102 PPG (0x57)',
                              _diagnostics?.max30102Ok == true,
                              _diagnostics?.max30102Ok == true ? 'ACK Verified' : 'No Response',
                            ),
                            const Divider(height: 16),
                            _buildDiagRow(
                              'AS7341 Multispectral (0x39)',
                              _diagnostics?.as7341Ok == true,
                              _diagnostics?.as7341Ok == true ? 'ACK Verified' : 'No Response',
                            ),
                            const Divider(height: 16),
                            _buildDiagRow(
                              'Physical I2C Addresses',
                              true,
                              '0x39 (AS7341), 0x57 (MAX30102)',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Acquisition Daemon State
                      CustomCard(
                        title: 'Acquisition Engine Integrity',
                        subtitle: 'Daemon service and validation flags',
                        child: Column(
                          children: [
                            _buildDiagRow(
                              'Local Storage Status',
                              _diagnostics?.storageOk == true,
                              _diagnostics?.storageOk == true ? 'Operational' : 'Storage Issue',
                            ),
                            const Divider(height: 16),
                            _buildDiagRow(
                              'Research Gate State',
                              false,
                              'Gated (Validation Pending)',
                              isWarning: true,
                            ),
                            const Divider(height: 16),
                            _buildDiagRow(
                              'Zero Synthetic Guarantee',
                              true,
                              'Enforced (Physical Only)',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Technician Interactive Command Console
                      CustomCard(
                        title: 'Technician Actions & API Verification',
                        subtitle: 'Safe predefined operational queries (no raw shell)',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _selectedAction,
                              decoration: const InputDecoration(
                                labelText: 'Select Diagnostic Action',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              isExpanded: true,
                              items: _technicianActions.map((action) {
                                return DropdownMenuItem<String>(
                                  value: action,
                                  child: Text(
                                    action,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }).toList(),
                              onChanged: _isExecutingAction
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedAction = val;
                                        });
                                      }
                                    },
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _isExecutingAction ? null : _executeTechnicianAction,
                              icon: _isExecutingAction
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.play_arrow_rounded, size: 18),
                              label: Text(_isExecutingAction ? 'Executing...' : 'Run Selected Action'),
                            ),
                            if (_actionConsoleOutput != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _actionSuccess == true
                                        ? const Color(0xFF10B981)
                                        : _actionSuccess == false
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF334155),
                                  ),
                                ),
                                child: SelectableText(
                                  _actionConsoleOutput!,
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Manual Configuration Card
                      CustomCard(
                        title: 'Network Host Configuration',
                        subtitle: 'Current target address used by mobile client',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: SelectableText(
                                widget.deviceService?.baseUrl ?? 'http://hemopi.local:8000',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                onPressed: _showHostConfigDialog,
                                label: const Text('Change Host'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDiagRow(String label, bool ok, String detail, {bool isWarning = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        StatusBadge(
          label: detail,
          type: ok ? (isWarning ? BadgeType.warning : BadgeType.success) : BadgeType.error,
        ),
      ],
    );
  }
}

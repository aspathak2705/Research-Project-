import 'package:flutter/material.dart';
import '../../../core/models/preflight_result.dart';
import '../../../core/services/device_service.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../app/routes.dart';

class PreflightCheckScreen extends StatefulWidget {
  final DeviceService deviceService;

  const PreflightCheckScreen({super.key, required this.deviceService});

  @override
  State<PreflightCheckScreen> createState() => _PreflightCheckScreenState();
}

class _PreflightCheckScreenState extends State<PreflightCheckScreen> {
  bool _isLoading = true;
  PreflightResult? _result;

  @override
  void initState() {
    super.initState();
    _executeCheck();
  }

  Future<void> _executeCheck() async {
    setState(() => _isLoading = true);
    final res = await widget.deviceService.runPreflightCheck();
    if (mounted) {
      setState(() {
        _result = res;
        _isLoading = false;
      });
    }
  }

  Widget _buildCheckRow({
    required String title,
    required bool? status,
    required String passedText,
    required String failedText,
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  status == null
                      ? 'Checking component…'
                      : (status ? passedText : failedText),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (status == null)
            const StatusBadge(label: 'Checking', type: BadgeType.validating, icon: Icons.sync)
          else if (status)
            const StatusBadge(label: 'Passed', type: BadgeType.success, icon: Icons.check_circle_rounded)
          else if (isWarning)
            const StatusBadge(label: 'Pending', type: BadgeType.warning, icon: Icons.info_rounded)
          else
            const StatusBadge(label: 'Failed', type: BadgeType.error, icon: Icons.cancel_rounded),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final res = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HemoPi Readiness Check'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-run Check',
            onPressed: _isLoading ? null : _executeCheck,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isLoading
                                ? Icons.sync_rounded
                                : (res != null && res.isReachable
                                    ? Icons.verified_rounded
                                    : Icons.warning_amber_rounded),
                            size: 24,
                            color: _isLoading
                                ? theme.colorScheme.primary
                                : (res != null && res.isReachable
                                    ? const Color(0xFF0D8A58)
                                    : const Color(0xFFDC2626)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isLoading
                                  ? 'Checking your instrument…'
                                  : (res != null && res.isReachable
                                      ? 'HemoPi Communication Verified'
                                      : 'Instrument Offline'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isLoading
                          ? 'Running physical baseline checks across communication bus and biomedical sensors…'
                          : (res?.statusMessage ?? 'Check completed.'),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Card(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    children: [
                      _buildCheckRow(
                        title: '1. HemoPi Reachability',
                        status: _isLoading ? null : res?.isReachable,
                        passedText: 'Instrument responding over network',
                        failedText: 'Instrument unreachable',
                      ),
                      const Divider(height: 1),
                      _buildCheckRow(
                        title: '2. Software Service Health',
                        status: _isLoading ? null : res?.isSoftwareHealthy,
                        passedText: 'HemoPi software running normally',
                        failedText: 'Software service not responding',
                      ),
                      const Divider(height: 1),
                      _buildCheckRow(
                        title: '3. Sensor Communication Bus',
                        status: _isLoading ? null : res?.isI2cAvailable,
                        passedText: 'Sensor communication active',
                        failedText: 'Bus offline or no sensor acknowledgment',
                      ),
                      const Divider(height: 1),
                      _buildCheckRow(
                        title: '4. Multispectral Optical Sensor',
                        status: _isLoading ? null : res?.isAs7341Detected,
                        passedText: 'Optical sensor detected & active',
                        failedText: 'Optical sensor not responding',
                      ),
                      const Divider(height: 1),
                      _buildCheckRow(
                        title: '5. Optical Sensor Initialization',
                        status: _isLoading ? null : res?.isAs7341Initialized,
                        passedText: 'Internal registers & channels initialized',
                        failedText: 'Initialization failed',
                      ),
                      const Divider(height: 1),
                      _buildCheckRow(
                        title: '6. Pulse & PPG Sensor',
                        status: _isLoading ? null : res?.isMax30102Detected,
                        passedText: 'Pulse sensor detected & active',
                        failedText: 'Pulse sensor not responding',
                      ),
                      const Divider(height: 1),
                      _buildCheckRow(
                        title: '7. Pulse Sensor Initialization',
                        status: _isLoading ? null : res?.isMax30102Initialized,
                        passedText: 'FIFO buffer & LEDs initialized',
                        failedText: 'Initialization failed',
                      ),
                      const Divider(height: 1),
                      _buildCheckRow(
                        title: '8. Research Acquisition Gate',
                        status: _isLoading ? null : res?.isAcquisitionReady,
                        passedText: 'Acquisition unlocked for research',
                        failedText: 'Physical validation pending (acquisition gated)',
                        isWarning: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.diagnostics),
                      child: const Text('View Technician Details'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

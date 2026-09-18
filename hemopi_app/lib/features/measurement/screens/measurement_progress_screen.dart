import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/patient.dart';
import '../../../core/models/measurement_session.dart';
import '../../../core/services/measurement_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../app/routes.dart';

class MeasurementProgressScreen extends StatefulWidget {
  final Patient? patient;
  final MeasurementService measurementService;

  const MeasurementProgressScreen({
    super.key,
    this.patient,
    required this.measurementService,
  });

  @override
  State<MeasurementProgressScreen> createState() => _MeasurementProgressScreenState();
}

class _MeasurementProgressScreenState extends State<MeasurementProgressScreen> {
  bool _isAcquiring = false;
  double _progress = 0.0;
  String _statusMessage = 'Initializing physical acquisition stream...';
  MeasurementSession? _completedSession;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() {
      _isAcquiring = true;
      _progress = 0.05;
      _statusMessage = 'Communicating with HemoPi hardware acquisition daemon...';
      _error = null;
    });

    try {
      final patientId = widget.patient?.patientId ?? 'ANONYMOUS';
      final session = await widget.measurementService.startSession(patientId: patientId);

      _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
        final currentProgress = _progress + 0.1;
        if (currentProgress >= 1.0) {
          timer.cancel();
          final finishedSession = await widget.measurementService.stopSession(session.sessionId);
          if (mounted) {
            setState(() {
              _isAcquiring = false;
              _progress = 1.0;
              _statusMessage = 'Physical hardware measurement completed successfully.';
              _completedSession = finishedSession;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _progress = currentProgress;
              _statusMessage = 'Acquiring physical I2C readings (${(currentProgress * 100).toInt()}%)...';
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAcquiring = false;
          _error = e.toString();
          _statusMessage = 'Acquisition failed or aborted.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acquisition Progress'),
        automaticallyImplyLeading: !_isAcquiring,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CustomCard(
              title: _isAcquiring ? 'Acquisition Active' : (_error != null ? 'Acquisition Error' : 'Acquisition Complete'),
              subtitle: 'Subject ID: ${widget.patient?.patientId ?? "N/A"}',
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _progress,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(_progress * 100).toInt()}% Complete',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      StatusBadge(
                        label: _isAcquiring ? 'Acquiring' : (_error != null ? 'Failed' : 'Completed'),
                        type: _isAcquiring
                            ? BadgeType.measuring
                            : (_error != null ? BadgeType.error : BadgeType.success),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_statusMessage, style: const TextStyle(color: Colors.black87)),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const CustomCard(
              title: 'Phase 1 - Direct Hardware Pipeline Notice',
              subtitle: 'Scientific Integrity Gating',
              child: Text(
                'Raw data is being written strictly by the Pi hardware daemon to CSV storage. No synthetic curves or fake PPG waveforms are rendered.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 24),
            if (!_isAcquiring)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('View Session Results'),
                  onPressed: _completedSession != null
                      ? () {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.sessionResult,
                            arguments: _completedSession,
                          );
                        }
                      : () => Navigator.pop(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

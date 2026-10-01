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
  String _statusMessage = 'Connecting to HemoPi sensor hardware…';
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
      _statusMessage = 'Starting optical and pulse sensor recording…';
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
              _statusMessage = 'Measurement completed successfully.';
              _completedSession = finishedSession;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _progress = currentProgress;
              _statusMessage = 'Recording physical sensor signals (${(currentProgress * 100).toInt()}%)...';
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        String friendlyError = 'Measurement is not available yet because required sensor validation is still pending.';
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('timeout')) {
          friendlyError = 'HemoPi did not respond in time. Please verify that the instrument is switched on.';
        } else if (errStr.contains('socket') || errStr.contains('unreachable')) {
          friendlyError = 'Cannot reach HemoPi. Check that this phone and HemoPi are on the same Wi-Fi.';
        }

        setState(() {
          _isAcquiring = false;
          _error = friendlyError;
          _statusMessage = 'Acquisition unavailable.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurement in Progress'),
        automaticallyImplyLeading: !_isAcquiring,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomCard(
              title: _isAcquiring
                  ? 'Recording in Progress'
                  : (_error != null ? 'Acquisition Unavailable' : 'Recording Finished'),
              subtitle: 'Subject: ${widget.patient?.patientId ?? "Unspecified"}',
              trailing: StatusBadge(
                label: _isAcquiring ? 'Active' : (_error != null ? 'Gated' : 'Complete'),
                type: _isAcquiring
                    ? BadgeType.measuring
                    : (_error != null ? BadgeType.error : BadgeType.success),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(_progress * 100).toInt()}% Completed',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        _isAcquiring ? 'Keep finger steady' : 'Ready',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_statusMessage, style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_rounded, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const CustomCard(
              title: 'Study Protocol Notice',
              subtitle: 'Zero synthetic measurement guarantee',
              child: Text(
                'HemoPi records strictly authentic optical counts and PPG pulses. Simulated readings or fabricated hemoglobin estimations are never generated.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
            if (!_isAcquiring)
              ElevatedButton.icon(
                icon: Icon(_completedSession != null ? Icons.assessment_rounded : Icons.arrow_back_rounded),
                label: Text(_completedSession != null ? 'View Session Result' : 'Return to Setup'),
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
          ],
        ),
      ),
    );
  }
}

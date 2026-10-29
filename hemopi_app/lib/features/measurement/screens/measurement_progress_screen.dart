import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/patient.dart';
import '../../../core/models/measurement_session.dart';
import '../../../core/services/measurement_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/report_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/clinical_notice_banner.dart';
import '../../../shared/widgets/clinical_confirm_dialog.dart';
import '../../../app/design_tokens.dart';
import '../../../app/routes.dart';

class MeasurementProgressScreen extends StatefulWidget {
  final Patient? patient;
  final bool demoMode;
  final MeasurementService measurementService;
  final SessionService? sessionService;
  final ReportService? reportService;

  const MeasurementProgressScreen({
    super.key,
    this.patient,
    this.demoMode = false,
    required this.measurementService,
    this.sessionService,
    this.reportService,
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

  Future<bool> _handleWillPop() async {
    if (!_isAcquiring) return true;
    final confirmed = await ClinicalConfirmDialog.show(
      context,
      title: 'Cancel Active Measurement?',
      message:
          'Measurement acquisition is actively running. If you leave now, this recording session will be cancelled and discarded. No result will be saved.',
      confirmLabel: 'Cancel Recording',
      cancelLabel: 'Keep Measuring',
      isDestructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (confirmed == true) {
      _timer?.cancel();
      return true;
    }
    return false;
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
      final session = await widget.measurementService.startSession(
        patientId: patientId,
        demoMode: widget.demoMode,
      );

      _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
        final currentProgress = _progress + 0.1;
        if (currentProgress >= 1.0) {
          timer.cancel();
          try {
            final finishedSession = await widget.measurementService.stopSession(session.sessionId);
            if (widget.sessionService != null) {
              await widget.sessionService!.saveSession(finishedSession);
            }
            if (widget.reportService != null && widget.patient != null) {
              await widget.reportService!.generateReportForSession(
                session: finishedSession,
                patient: widget.patient!,
              );
            }
            if (mounted) {
              setState(() {
                _isAcquiring = false;
                _progress = 1.0;
                _statusMessage = 'Measurement completed successfully.';
                _completedSession = finishedSession;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isAcquiring = false;
                _error = 'Measurement could not be finalized: ${e.toString()}';
                _statusMessage = 'Acquisition unavailable.';
              });
            }
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
        String friendlyError = 'Measurement acquisition could not be completed. Please ensure finger is firmly placed on sensor.';
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('timeout')) {
          friendlyError = 'HemoPi did not respond in time. Please verify that the instrument is switched on.';
        } else if (errStr.contains('socket') || errStr.contains('unreachable')) {
          friendlyError = 'Cannot reach HemoPi. Check that this phone and HemoPi are connected to the same Wi-Fi network.';
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
    return PopScope(
      canPop: !_isAcquiring,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final allow = await _handleWillPop();
          if (allow && mounted) {
            Navigator.of(this.context).pop();
          }
        }
      },
      child: ClinicalScaffold(
        appBar: AppBar(
          title: const Text('Measurement in Progress'),
          automaticallyImplyLeading: !_isAcquiring,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
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
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 10,
                        backgroundColor: AppColors.surfaceSubtle,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(_progress * 100).toInt()}% Completed',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        Text(
                          _isAcquiring ? 'Keep finger steady' : 'Ready',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(_statusMessage, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.statusErrorBg,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(color: AppColors.statusErrorBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_rounded, color: AppColors.statusError, size: 18),
                            const SizedBox(width: AppSpacing.xs),
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
              const SizedBox(height: AppSpacing.md),
              const ClinicalNoticeBanner(
                title: 'Authentic Physical Recording Standard',
                message:
                    'HemoPi records strictly authentic optical counts and PPG pulses. Simulated readings or fabricated hemoglobin estimations are never generated.',
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_isAcquiring)
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop_circle_outlined, color: AppColors.statusError),
                  label: const Text('Cancel Measurement', style: TextStyle(color: AppColors.statusError)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.statusErrorBorder)),
                  onPressed: () async {
                    final shouldCancel = await _handleWillPop();
                    if (shouldCancel && mounted) {
                      Navigator.of(this.context).pop();
                    }
                  },
                )
              else
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
      ),
    );
  }
}

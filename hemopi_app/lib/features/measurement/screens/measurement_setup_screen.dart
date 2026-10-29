import 'package:flutter/material.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/measurement_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/clinical_detail_row.dart';
import '../../../app/design_tokens.dart';
import '../../../app/routes.dart';

enum MeasurementReadinessState {
  checking,
  disconnected,
  validationPending,
  sensorMissing,
  ready,
  unknownError,
}

class MeasurementSetupScreen extends StatefulWidget {
  final Patient? patient;
  final DeviceService deviceService;
  final MeasurementService measurementService;

  const MeasurementSetupScreen({
    super.key,
    this.patient,
    required this.deviceService,
    required this.measurementService,
  });

  @override
  State<MeasurementSetupScreen> createState() => _MeasurementSetupScreenState();
}

class _MeasurementSetupScreenState extends State<MeasurementSetupScreen> {
  MeasurementReadinessState _readinessState = MeasurementReadinessState.checking;
  bool _sensorsDetected = false;

  @override
  void initState() {
    super.initState();
    _checkHardwarePreflight();
  }

  Future<void> _checkHardwarePreflight() async {
    setState(() {
      _readinessState = MeasurementReadinessState.checking;
      _sensorsDetected = false;
    });

    try {
      final status = await widget.deviceService.getSensorStatus();
      if (!mounted) return;

      final bothDetected = status.max30102Present && status.as7341Present;
      final ready = bothDetected &&
          status.as7341ResearchReady &&
          status.as7341PhysicallyValidated;

      if (!status.max30102Present || !status.as7341Present) {
        setState(() {
          _readinessState = MeasurementReadinessState.sensorMissing;
          _sensorsDetected = false;
        });
      } else if (!status.as7341ResearchReady || !status.as7341PhysicallyValidated) {
        setState(() {
          _readinessState = MeasurementReadinessState.validationPending;
          _sensorsDetected = true;
        });
      } else if (ready) {
        setState(() {
          _readinessState = MeasurementReadinessState.ready;
          _sensorsDetected = true;
        });
      } else {
        setState(() {
          _readinessState = MeasurementReadinessState.validationPending;
          _sensorsDetected = bothDetected;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _readinessState = MeasurementReadinessState.disconnected;
        _sensorsDetected = false;
      });
    }
  }

  bool get _isReadyForAcquisition =>
      _readinessState == MeasurementReadinessState.ready && widget.patient != null;

  bool get _canStartDemoMeasurement =>
      _sensorsDetected && widget.patient != null;

  @override
  Widget build(BuildContext context) {
    return ClinicalScaffold(
      appBar: AppBar(
        title: const Text('Start Measurement'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section A: Patient Card
            CustomCard(
              title: 'Patient',
              subtitle: widget.patient != null ? 'Subject: ${widget.patient!.patientId}' : 'No patient selected',
              trailing: widget.patient != null
                  ? const StatusBadge(label: 'Selected', type: BadgeType.ready)
                  : const StatusBadge(label: 'Required', type: BadgeType.warning),
              child: widget.patient == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select or register a patient before continuing with the measurement.',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.patientList),
                          icon: const Icon(Icons.people_outline, size: 18),
                          label: const Text('Select Patient'),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        ClinicalDetailRow(
                          label: 'Patient ID',
                          value: widget.patient!.patientId,
                        ),
                        const Divider(),
                        ClinicalDetailRow(
                          label: 'Age',
                          value: widget.patient!.age != null ? '${widget.patient!.age} years' : 'Not recorded',
                        ),
                        const Divider(),
                        ClinicalDetailRow(
                          label: 'Biological Sex',
                          value: widget.patient!.sex ?? 'Unspecified',
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Section B: Measurement Availability Notice (Single compact notice)
            _buildAvailabilityNotice(),
            const SizedBox(height: AppSpacing.md),

            // Section C: Preparation Instructions (3 concise steps)
            const CustomCard(
              title: 'Measurement Preparation',
              subtitle: 'Patient instructions',
              child: Column(
                children: [
                  _InstructionRow(
                    step: '1',
                    text: 'Ask the patient to sit comfortably and rest their hand on a stable, flat surface.',
                  ),
                  SizedBox(height: AppSpacing.sm),
                  _InstructionRow(
                    step: '2',
                    text: 'Place index finger firmly over the sensor opening without pressing excessively.',
                  ),
                  SizedBox(height: AppSpacing.sm),
                  _InstructionRow(
                    step: '3',
                    text: 'Instruct the patient to remain still and relaxed during recording.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Section D: Primary Action
            if (_isReadyForAcquisition)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Start Measurement'),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.measurementProgress,
                    arguments: {
                      'patient': widget.patient,
                      'demo_mode': false,
                    },
                  );
                },
              )
            else if (_canStartDemoMeasurement)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Start Demo Measurement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.measurementProgress,
                    arguments: {
                      'patient': widget.patient,
                      'demo_mode': true,
                    },
                  );
                },
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Start Measurement'),
                onPressed: null,
              ),
            if (!_isReadyForAcquisition && !_canStartDemoMeasurement) ...[
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: Text(
                  _getDisabledActionHint(),
                  style: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else if (!_isReadyForAcquisition && _canStartDemoMeasurement) ...[
              const SizedBox(height: AppSpacing.xs),
              const Center(
                child: Text(
                  'Physical sensors detected. Live raw acquisition available for demonstration.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityNotice() {
    switch (_readinessState) {
      case MeasurementReadinessState.checking:
        return _buildNoticeCard(
          icon: Icons.sync_rounded,
          iconColor: AppColors.primary,
          title: 'Checking instrument',
          message: 'Please wait while the instrument is checked.',
          bgColor: AppColors.primaryContainer,
          borderColor: AppColors.primaryLight,
          textColor: AppColors.primaryDark,
          isLoading: true,
        );

      case MeasurementReadinessState.disconnected:
        return _buildNoticeCard(
          icon: Icons.wifi_off_rounded,
          iconColor: AppColors.statusError,
          title: 'Instrument unavailable',
          message: 'HemoPi is not connected. Check the instrument connection or Wi-Fi network.',
          bgColor: AppColors.statusErrorBg,
          borderColor: AppColors.statusErrorBorder,
          textColor: const Color(0xFF991B1B),
          onRetry: _checkHardwarePreflight,
        );

      case MeasurementReadinessState.sensorMissing:
        return _buildNoticeCard(
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.statusWarning,
          title: 'Instrument not detected',
          message: 'One or more sensors are not responding. Verify sensor connections or consult technician diagnostics.',
          bgColor: AppColors.statusWarningBg,
          borderColor: AppColors.statusWarningBorder,
          textColor: const Color(0xFF92400E),
          onRetry: _checkHardwarePreflight,
        );

      case MeasurementReadinessState.validationPending:
        return _buildNoticeCard(
          icon: Icons.info_outline_rounded,
          iconColor: AppColors.statusWarning,
          title: 'Measurement not yet available',
          message: 'The instrument needs to complete its required validation before a measurement can be taken.',
          bgColor: AppColors.statusWarningBg,
          borderColor: AppColors.statusWarningBorder,
          textColor: const Color(0xFF92400E),
          onRetry: _checkHardwarePreflight,
        );

      case MeasurementReadinessState.ready:
        return _buildNoticeCard(
          icon: Icons.check_circle_outline_rounded,
          iconColor: AppColors.statusSuccess,
          title: 'Ready for measurement',
          message: 'The instrument is ready. You can continue when the patient is prepared.',
          bgColor: AppColors.statusSuccessBg,
          borderColor: AppColors.statusSuccessBorder,
          textColor: const Color(0xFF14532D),
        );

      case MeasurementReadinessState.unknownError:
        return _buildNoticeCard(
          icon: Icons.info_outline_rounded,
          iconColor: AppColors.statusWarning,
          title: 'Status unavailable',
          message: 'Could not determine instrument readiness. Check device connection.',
          bgColor: AppColors.statusWarningBg,
          borderColor: AppColors.statusWarningBorder,
          textColor: const Color(0xFF92400E),
          onRetry: _checkHardwarePreflight,
        );
    }
  }

  Widget _buildNoticeCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    bool isLoading = false,
    VoidCallback? onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
                  )
                : Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.95),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null && !isLoading) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Retry status check',
              color: textColor,
              onPressed: onRetry,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  String _getDisabledActionHint() {
    if (widget.patient == null) {
      return 'Please select a patient before starting a measurement.';
    }
    switch (_readinessState) {
      case MeasurementReadinessState.checking:
        return 'Waiting for instrument check to complete…';
      case MeasurementReadinessState.disconnected:
        return 'Instrument is disconnected.';
      case MeasurementReadinessState.validationPending:
      case MeasurementReadinessState.sensorMissing:
        return 'Measurement is disabled until required validation is completed.';
      case MeasurementReadinessState.unknownError:
        return 'Instrument readiness cannot be confirmed.';
      case MeasurementReadinessState.ready:
        return '';
    }
  }
}

class _InstructionRow extends StatelessWidget {
  final String step;
  final String text;

  const _InstructionRow({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
          ),
        ),
      ],
    );
  }
}

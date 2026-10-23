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
  bool _isCheckingHardware = true;
  bool _hardwareReady = false;
  bool _instrumentConnected = false;
  String _hardwareStatusText = 'Checking sensor hardware…';

  @override
  void initState() {
    super.initState();
    _checkHardwarePreflight();
  }

  Future<void> _checkHardwarePreflight() async {
    setState(() {
      _isCheckingHardware = true;
    });

    try {
      final status = await widget.deviceService.getSensorStatus();
      if (mounted) {
        final ready = status.max30102Present &&
            status.as7341Present &&
            status.as7341ResearchReady &&
            status.as7341PhysicallyValidated;
        setState(() {
          _instrumentConnected = status.max30102Present || status.as7341Present;
          _hardwareReady = ready;
          if (!status.max30102Present || !status.as7341Present) {
            _hardwareStatusText =
                'One or more physical sensors are not detected. Verify sensor connections on the HemoPi instrument.';
          } else if (!status.as7341ResearchReady || !status.as7341PhysicallyValidated) {
            _hardwareStatusText =
                'Measurement is currently unavailable because the optical sensor has not completed the required physical validation.';
          } else {
            _hardwareStatusText =
                'All sensors detected and verified. Ready for research acquisition.';
          }
          _isCheckingHardware = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _instrumentConnected = false;
          _hardwareReady = false;
          _hardwareStatusText = 'Unable to communicate with HemoPi. Check that the device is switched on and connected.';
          _isCheckingHardware = false;
        });
      }
    }
  }

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
            // Patient Selection / Overview
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
                          'A registered patient must be chosen before taking a measurement.',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.patientList),
                          icon: const Icon(Icons.people_outline, size: 18),
                          label: const Text('Select or Add Patient'),
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

            // Hardware Preflight Checklist
            CustomCard(
              title: 'Hardware Readiness Check',
              subtitle: 'Automated pre-measurement verification',
              trailing: StatusBadge(
                label: _isCheckingHardware
                    ? 'Checking…'
                    : (_hardwareReady ? 'Ready' : 'Gated'),
                type: _isCheckingHardware
                    ? BadgeType.validating
                    : (_hardwareReady ? BadgeType.ready : BadgeType.warning),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCheckItem(
                    'HemoPi Connection',
                    _instrumentConnected,
                    'Instrument online and responding',
                    'Instrument unreachable on network',
                  ),
                  const Divider(height: 16),
                  _buildCheckItem(
                    'Pulse & PPG Sensor',
                    _instrumentConnected,
                    'Pulse sensor detected and initialized',
                    'Pulse sensor not detected',
                  ),
                  const Divider(height: 16),
                  _buildCheckItem(
                    'Multispectral Optical Sensor',
                    _instrumentConnected,
                    'Spectral sensor detected (Validation Pending)',
                    'Optical sensor not detected',
                    warning: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: _hardwareReady ? AppColors.statusSuccessBg : AppColors.statusWarningBg,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: _hardwareReady ? AppColors.statusSuccessBorder : AppColors.statusWarningBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hardwareReady ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          color: _hardwareReady ? AppColors.statusSuccess : AppColors.statusWarning,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _hardwareStatusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: _hardwareReady ? AppColors.statusSuccess : const Color(0xFF92400E),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Practical Clinical Instructions
            const CustomCard(
              title: 'Measurement Preparation',
              subtitle: 'Subject placement instructions',
              child: Column(
                children: [
                  _InstructionRow(
                    step: '1',
                    text: 'Ask subject to sit comfortably and rest hand on a stable, flat surface.',
                  ),
                  SizedBox(height: AppSpacing.sm),
                  _InstructionRow(
                    step: '2',
                    text: 'Place index finger firmly over the sensor opening without pressing excessively.',
                  ),
                  SizedBox(height: AppSpacing.sm),
                  _InstructionRow(
                    step: '3',
                    text: 'Instruct subject to remain relaxed and avoid talking or moving during recording.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Start Measurement Button
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Start Measurement'),
              onPressed: (_hardwareReady && !_isCheckingHardware && widget.patient != null)
                  ? () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.measurementProgress,
                        arguments: {
                          'patient': widget.patient,
                        },
                      );
                    }
                  : null,
            ),
            if (!_hardwareReady) ...[
              const SizedBox(height: AppSpacing.xs),
              const Center(
                child: Text(
                  'Button is disabled until sensor validation is completed on the instrument.',
                  style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
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

  Widget _buildCheckItem(String title, bool ok, String okText, String failText, {bool warning = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? (warning ? Icons.info_rounded : Icons.check_circle_rounded) : Icons.cancel_rounded,
          size: 18,
          color: ok ? (warning ? AppColors.statusWarning : AppColors.statusSuccess) : AppColors.statusError,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(
                ok ? okText : failText,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
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

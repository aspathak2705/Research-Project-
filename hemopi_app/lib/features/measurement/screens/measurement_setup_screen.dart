import 'package:flutter/material.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/measurement_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';
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
          _hardwareStatusText = 'Unable to communicate with HemoPi. Check that the device is switched on.';
          _isCheckingHardware = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Measurement'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Patient Selection / Overview
            CustomCard(
              title: 'Patient',
              subtitle: widget.patient != null ? 'Subject: ${widget.patient!.patientId}' : 'No patient selected',
              trailing: widget.patient != null
                  ? const StatusBadge(label: 'Selected', type: BadgeType.ready)
                  : const StatusBadge(label: 'Action Required', type: BadgeType.warning),
              child: widget.patient == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'A registered patient must be chosen before taking a measurement.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.patientList),
                          icon: const Icon(Icons.people_outline, size: 18),
                          label: const Text('Select or Add Patient'),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Age', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            Text('${widget.patient!.age ?? "N/A"} years', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Sex', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            Text(widget.patient!.sex ?? 'Unspecified', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

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
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _hardwareReady ? const Color(0xFFE8F5E9) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hardwareReady ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          color: _hardwareReady ? const Color(0xFF0D8A58) : const Color(0xFFD97706),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _hardwareStatusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: _hardwareReady ? const Color(0xFF0D8A58) : const Color(0xFF92400E),
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
            const SizedBox(height: 16),

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
                  SizedBox(height: 10),
                  _InstructionRow(
                    step: '2',
                    text: 'Place index finger firmly over the sensor opening without pressing excessively.',
                  ),
                  SizedBox(height: 10),
                  _InstructionRow(
                    step: '3',
                    text: 'Instruct subject to remain relaxed and avoid talking or moving during recording.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Button is disabled until sensor validation is completed on the instrument.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 16),
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
          color: ok ? (warning ? const Color(0xFFD97706) : const Color(0xFF0D8A58)) : const Color(0xFFDC2626),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Text(
                ok ? okText : failText,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
            color: const Color(0xFFE0F2F1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF007A78),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.35),
          ),
        ),
      ],
    );
  }
}

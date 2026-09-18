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
  String _hardwareStatusText = 'Checking physical I2C sensors...';

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
        final ready = status.max30102Present && status.as7341Present;
        setState(() {
          _hardwareReady = ready;
          _hardwareStatusText = ready
              ? 'Physical sensors MAX30102 (0x57) and AS7341 (0x39) detected and ready.'
              : 'Hardware Gated: ${status.max30102Present ? "" : "MAX30102 missing. "}${status.as7341Present ? "" : "AS7341 missing."} Real hardware required to proceed.';
          _isCheckingHardware = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hardwareReady = false;
          _hardwareStatusText = 'Error verifying hardware: $e';
          _isCheckingHardware = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurement Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomCard(
              title: 'Subject Information',
              subtitle: widget.patient != null
                  ? 'Subject ID: ${widget.patient!.patientId}'
                  : 'No subject selected',
              child: widget.patient == null
                  ? const Text('Please select or register a patient prior to starting session.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Age: ${widget.patient!.age ?? "N/A"}'),
                        Text('Sex: ${widget.patient!.sex ?? "Unspecified"}'),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              title: 'Hardware Pre-Flight Check',
              subtitle: 'Phase 1 - Gate keeping real sensor requirement',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sensor Gating Status', style: TextStyle(fontWeight: FontWeight.bold)),
                      StatusBadge(
                        label: _isCheckingHardware
                            ? 'Checking...'
                            : (_hardwareReady ? 'Ready' : 'Gated'),
                        type: _isCheckingHardware
                            ? BadgeType.validating
                            : (_hardwareReady ? BadgeType.ready : BadgeType.error),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hardwareStatusText,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const CustomCard(
              title: 'Acquisition Protocol Guidelines',
              subtitle: 'Real Physical Measurement Rules',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Ensure finger is firmly resting on MAX30102 PPG sensor lens.'),
                  Text('2. Ensure optical alignment with AS7341 multispectral sensor.'),
                  Text('3. Minimize ambient light interference and finger movement.'),
                  Text('4. System will record real hardware raw counts strictly.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Physical Acquisition'),
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
            ),
          ],
        ),
      ),
    );
  }
}

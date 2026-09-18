import 'package:flutter/material.dart';
import '../../../core/models/measurement_session.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../app/routes.dart';

class SessionResultScreen extends StatelessWidget {
  final MeasurementSession session;

  const SessionResultScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Result'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CustomCard(
              title: 'Acquisition Summary',
              subtitle: 'Session ID: ${session.sessionId}',
              child: Column(
                children: [
                  _buildRow('Subject ID', session.patientId),
                  _buildRow('Timestamp', session.timestamp.toIso8601String().replaceAll('T', ' ').substring(0, 19)),
                  _buildRow('Status', session.status.name.toUpperCase()),
                  _buildRow('Raw Readings Count', '${session.rawSampleCount} samples'),
                  _buildRow('CSV File Saved', session.csvPath ?? 'Pending save'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const CustomCard(
              title: 'Hemoglobin Prediction Status',
              subtitle: 'Phase 1 - Scientific Honesty Gating',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estimated Hb Value', style: TextStyle(fontWeight: FontWeight.bold)),
                      StatusBadge(label: 'Pending Phase 4', type: BadgeType.info),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No fake or simulated hemoglobin (g/dL) values are displayed. Hemoglobin concentration models require physical multispectral calibration (Phase 4).',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.dashboard,
                        (route) => false,
                      );
                    },
                    child: const Text('Dashboard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.sessionHistory);
                    },
                    child: const Text('All Sessions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

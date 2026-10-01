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
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomCard(
              title: 'Acquisition Summary',
              subtitle: 'Recorded Session Identifier: ${session.sessionId}',
              trailing: StatusBadge(
                label: session.status.name.toUpperCase(),
                type: session.validSamples > 0 ? BadgeType.success : BadgeType.info,
              ),
              child: Column(
                children: [
                  _buildRow('Subject Identifier', session.patientId),
                  const Divider(height: 16),
                  _buildRow('Recorded Date & Time', session.createdAt.toIso8601String().replaceAll('T', ' ').substring(0, 19)),
                  const Divider(height: 16),
                  _buildRow('Total Samples Attempted', '${session.attemptedSamples}'),
                  const Divider(height: 16),
                  _buildRow('Valid Sensor Readings', '${session.validSamples}'),
                  const Divider(height: 16),
                  _buildRow('Offline CSV Saved', session.localValidCsvFile != null ? 'Saved locally' : 'Gated'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const CustomCard(
              title: 'Clinical Hemoglobin Estimation',
              subtitle: 'Research Gating Standard',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Hb Value Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      StatusBadge(label: 'Pending Optical Calibration', type: BadgeType.warning),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'In accordance with clinical protocol, no synthetic, mock, or simulated hemoglobin concentration (g/dL) values are displayed. Hemoglobin estimation requires full optical sensor calibration on physical hardware.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.dashboard,
                  (route) => false,
                );
              },
              child: const Text('Return to Home'),
            ),
            const SizedBox(height: 10),

            OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.sessionHistory);
              },
              child: const Text('View All Sessions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF64748B), fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

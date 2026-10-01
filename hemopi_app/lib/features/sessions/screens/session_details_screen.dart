import 'package:flutter/material.dart';
import '../../../core/models/measurement_session.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';

class SessionDetailsScreen extends StatelessWidget {
  final MeasurementSession session;

  const SessionDetailsScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Session ${session.sessionId}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          children: [
            CustomCard(
              title: 'Session Details',
              subtitle: 'Recorded Session Identifier: ${session.sessionId}',
              trailing: StatusBadge(
                label: session.status.name.toUpperCase(),
                type: session.validSamples > 0 ? BadgeType.success : BadgeType.info,
              ),
              child: Column(
                children: [
                  _buildRow('Subject Identifier', session.patientId),
                  const Divider(height: 16),
                  _buildRow('Created At', session.createdAt.toIso8601String().replaceAll('T', ' ').substring(0, 19)),
                  const Divider(height: 16),
                  _buildRow('Total Samples Attempted', '${session.attemptedSamples}'),
                  const Divider(height: 16),
                  _buildRow('Valid Sensor Readings', '${session.validSamples}'),
                  const Divider(height: 16),
                  _buildRow('Rejected Readings', '${session.rejectedSamples}'),
                  const Divider(height: 16),
                  _buildRow('Acquisition State', session.validationStatus),
                  const Divider(height: 16),
                  _buildRow('Stored CSV File', session.localValidCsvFile ?? 'Pending session validation'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const CustomCard(
              title: 'Offline Storage Notice',
              subtitle: 'Local Client Persistence',
              child: Text(
                'Session records and research data are secured in offline local storage on this Android device. All readings originate strictly from physical hardware acquisition.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
              ),
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

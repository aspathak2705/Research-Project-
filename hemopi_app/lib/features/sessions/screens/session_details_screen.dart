import 'package:flutter/material.dart';
import '../../../core/models/measurement_session.dart';
import '../../../shared/widgets/custom_card.dart';

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
        title: Text('Session: ${session.sessionId}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CustomCard(
              title: 'Session Metadata',
              subtitle: 'Subject: ${session.patientId}',
              child: Column(
                children: [
                  _buildRow('Session Identifier', session.sessionId),
                  _buildRow('Subject Identifier', session.patientId),
                  _buildRow('Timestamp', session.timestamp.toIso8601String().replaceAll('T', ' ').substring(0, 19)),
                  _buildRow('Status', session.status.name.toUpperCase()),
                  _buildRow('Total Samples', '${session.rawSampleCount}'),
                  _buildRow('CSV Storage Path', session.csvPath ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const CustomCard(
              title: 'Raw Sensor Log Access',
              subtitle: 'Research Storage Verification',
              child: Text(
                'Raw CSV files are stored locally on the Raspberry Pi acquisition unit in the designated research storage directory. Transfer or inspection occurs via local SSH/SFTP.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
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

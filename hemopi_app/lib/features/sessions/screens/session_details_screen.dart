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
              subtitle: 'Subject ID: ${session.patientId}',
              child: Column(
                children: [
                  _buildRow('Session Identifier', session.sessionId),
                  _buildRow('Subject Identifier', session.patientId),
                  _buildRow('Created At', session.createdAt.toIso8601String().replaceAll('T', ' ').substring(0, 19)),
                  _buildRow('Status', session.status.name.toUpperCase()),
                  _buildRow('Attempted Samples', '${session.attemptedSamples}'),
                  _buildRow('Valid Samples', '${session.validSamples}'),
                  _buildRow('Rejected Samples', '${session.rejectedSamples}'),
                  _buildRow('Validation Status', session.validationStatus),
                  _buildRow('Local CSV File', session.localValidCsvFile ?? 'Not generated / pending'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const CustomCard(
              title: 'Android Local Storage Notice',
              subtitle: 'Local Client Persistence',
              child: Text(
                'Session metadata and physical acquisition CSV files are saved locally on this Android device. The Raspberry Pi functions as a sensor acquisition node and does NOT maintain permanent research records.',
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

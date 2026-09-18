import 'package:flutter/material.dart';
import '../../../core/models/patient.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../app/routes.dart';

class PatientDetailScreen extends StatelessWidget {
  final Patient patient;

  const PatientDetailScreen({
    super.key,
    required this.patient,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient: ${patient.patientId}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CustomCard(
              title: 'Subject Profile',
              subtitle: 'ID: ${patient.patientId}',
              child: Column(
                children: [
                  _buildDetailRow('Age', patient.age != null ? '${patient.age} yrs' : 'Not recorded'),
                  _buildDetailRow('Sex', patient.sex ?? 'Unspecified'),
                  _buildDetailRow('Created', patient.createdAt.toIso8601String().substring(0, 10)),
                  _buildDetailRow('Notes', patient.notes ?? 'No notes recorded'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              title: 'Acquisition Actions',
              subtitle: 'Initiate physical sensor measurement for this subject',
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sensors),
                  label: const Text('Start Measurement Session'),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.measurementSetup,
                      arguments: patient,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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

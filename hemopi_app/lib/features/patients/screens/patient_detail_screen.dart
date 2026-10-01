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
        title: Text(patient.patientId),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Subject Profile Card
            CustomCard(
              title: 'Patient Information',
              subtitle: 'Study Identifier: ${patient.patientId}',
              child: Column(
                children: [
                  _buildDetailRow('Age', patient.age != null ? '${patient.age} years' : 'Not recorded'),
                  const Divider(height: 16),
                  _buildDetailRow('Biological Sex', patient.sex ?? 'Unspecified'),
                  const Divider(height: 16),
                  _buildDetailRow('Registration Date', patient.createdAt.toIso8601String().substring(0, 10)),
                  const Divider(height: 16),
                  _buildDetailRow('Clinical Notes', patient.notes ?? 'None recorded'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Start Measurement CTA Card
            CustomCard(
              title: 'New Session',
              subtitle: 'Initiate physical optical & pulse sensor acquisition',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start a guided measurement sequence for this subject using the connected HemoPi instrument.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text('Start Measurement'),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.measurementSetup,
                        arguments: patient,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF64748B), fontSize: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }
}

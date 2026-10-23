import 'package:flutter/material.dart';
import '../../../core/models/patient.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/clinical_detail_row.dart';
import '../../../app/design_tokens.dart';
import '../../../app/routes.dart';

class PatientDetailScreen extends StatelessWidget {
  final Patient patient;

  const PatientDetailScreen({
    super.key,
    required this.patient,
  });

  @override
  Widget build(BuildContext context) {
    return ClinicalScaffold(
      appBar: AppBar(
        title: Text(patient.patientId),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Subject Profile Card
            CustomCard(
              title: 'Patient Profile',
              subtitle: 'Study Identifier: ${patient.patientId}',
              child: Column(
                children: [
                  ClinicalDetailRow(
                    label: 'Age',
                    value: patient.age != null ? '${patient.age} years' : 'Not recorded',
                  ),
                  const Divider(),
                  ClinicalDetailRow(
                    label: 'Biological Sex',
                    value: patient.sex ?? 'Unspecified',
                  ),
                  const Divider(),
                  ClinicalDetailRow(
                    label: 'Registration Date',
                    value: patient.createdAt.toIso8601String().substring(0, 10),
                  ),
                  const Divider(),
                  ClinicalDetailRow(
                    label: 'Clinical Notes',
                    value: patient.notes ?? 'None recorded',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Start Measurement CTA Card
            CustomCard(
              title: 'New Measurement Session',
              subtitle: 'Initiate optical and pulse sensor acquisition',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Begin a guided measurement sequence for this subject using the connected HemoPi instrument.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
}

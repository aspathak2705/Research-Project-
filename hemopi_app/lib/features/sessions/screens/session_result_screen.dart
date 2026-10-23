import 'package:flutter/material.dart';
import '../../../core/models/measurement_session.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/clinical_notice_banner.dart';
import '../../../shared/widgets/clinical_detail_row.dart';
import '../../../app/design_tokens.dart';
import '../../../app/routes.dart';

class SessionResultScreen extends StatelessWidget {
  final MeasurementSession session;

  const SessionResultScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return ClinicalScaffold(
      appBar: AppBar(
        title: const Text('Session Result'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomCard(
              title: 'Acquisition Summary',
              subtitle: 'Session ID: ${session.sessionId}',
              trailing: StatusBadge(
                label: session.status.name.toUpperCase(),
                type: session.validSamples > 0 ? BadgeType.success : BadgeType.info,
              ),
              child: Column(
                children: [
                  ClinicalDetailRow(label: 'Patient ID', value: session.patientId),
                  const Divider(),
                  ClinicalDetailRow(
                    label: 'Recorded Time',
                    value: session.createdAt.toIso8601String().replaceAll('T', ' ').substring(0, 19),
                  ),
                  const Divider(),
                  ClinicalDetailRow(
                    label: 'Attempted Samples',
                    value: '${session.attemptedSamples}',
                  ),
                  const Divider(),
                  ClinicalDetailRow(
                    label: 'Valid Sensor Readings',
                    value: '${session.validSamples}',
                  ),
                  const Divider(),
                  ClinicalDetailRow(
                    label: 'Offline Data File',
                    value: session.localValidCsvFile != null ? 'Saved locally' : 'Gated / Incomplete',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            CustomCard(
              title: 'Hemoglobin Concentration (Hb)',
              subtitle: 'Research Gating Standard',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimate Status',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      StatusBadge(label: 'Calibration Pending', type: BadgeType.warning),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const ClinicalNoticeBanner.gated(
                    title: 'Investigational Safeguard',
                    message:
                        'No synthetic, simulated, or predicted hemoglobin concentration (g/dL) values are displayed. True clinical hemoglobin estimation requires full physical optical sensor calibration on the instrument.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

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
            const SizedBox(height: AppSpacing.xs),

            OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.sessionHistory);
              },
              child: const Text('View All Sessions'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

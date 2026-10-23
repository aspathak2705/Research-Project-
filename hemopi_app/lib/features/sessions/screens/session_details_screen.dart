import 'package:flutter/material.dart';
import '../../../core/models/measurement_session.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/clinical_notice_banner.dart';
import '../../../shared/widgets/clinical_detail_row.dart';
import '../../../app/design_tokens.dart';

class SessionDetailsScreen extends StatelessWidget {
  final MeasurementSession session;

  const SessionDetailsScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return ClinicalScaffold(
      appBar: AppBar(
        title: Text('Session ${session.sessionId}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomCard(
              title: 'Session Profile',
              subtitle: 'Subject: ${session.patientId}',
              trailing: StatusBadge(
                label: session.status.name.toUpperCase(),
                type: session.validSamples > 0 ? BadgeType.success : BadgeType.warning,
              ),
              child: Column(
                children: [
                  ClinicalDetailRow(label: 'Session ID', value: session.sessionId),
                  const Divider(),
                  ClinicalDetailRow(label: 'Patient ID', value: session.patientId),
                  const Divider(),
                  ClinicalDetailRow(
                    label: 'Recorded Time',
                    value: session.createdAt.toIso8601String().replaceAll('T', ' ').substring(0, 19),
                  ),
                  const Divider(),
                  ClinicalDetailRow(label: 'Sensor Readiness', value: session.sensorReadinessState),
                  const Divider(),
                  ClinicalDetailRow(label: 'Attempted Samples', value: '${session.attemptedSamples}'),
                  const Divider(),
                  ClinicalDetailRow(label: 'Valid Samples', value: '${session.validSamples}'),
                  const Divider(),
                  ClinicalDetailRow(label: 'Rejected Samples', value: '${session.rejectedSamples}'),
                  const Divider(),
                  ClinicalDetailRow(label: 'Validation Status', value: session.validationStatus),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            const ClinicalNoticeBanner(
              title: 'Investigational Record',
              message:
                  'Session records reflect non-invasive sensor acquisition data collected under clinical study protocols.',
            ),
            const SizedBox(height: AppSpacing.md),

            if (session.errorMessage != null && session.errorMessage!.isNotEmpty) ...[
              CustomCard(
                title: 'Recorded Issue',
                subtitle: session.errorCode ?? 'Acquisition Diagnostic Note',
                child: Text(
                  session.errorMessage!,
                  style: const TextStyle(fontSize: 13, color: AppColors.statusError, height: 1.4),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

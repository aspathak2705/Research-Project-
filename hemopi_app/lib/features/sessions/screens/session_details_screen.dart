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

            if (session.readings != null) ...[
              CustomCard(
                title: 'Sensor Acquisition Readings',
                subtitle: session.isDemo ? 'Live Demonstration Capture' : 'Authentic Physical Readings',
                trailing: StatusBadge(
                  label: session.isDemo ? 'Demo Mode' : 'Authentic',
                  type: BadgeType.ready,
                ),
                child: Column(
                  children: [
                    ClinicalDetailRow(
                      label: 'MAX30102 Red',
                      value: '${session.readings!['max30102_red']} ADC counts',
                    ),
                    const Divider(),
                    ClinicalDetailRow(
                      label: 'MAX30102 Infrared',
                      value: '${session.readings!['max30102_ir']} ADC counts',
                    ),
                    const Divider(),
                    ClinicalDetailRow(
                      label: 'AS7341 415 nm (Violet)',
                      value: '${session.readings!['as7341_415nm']} counts',
                    ),
                    const Divider(),
                    ClinicalDetailRow(
                      label: 'AS7341 445 nm (Indigo)',
                      value: '${session.readings!['as7341_445nm']} counts',
                    ),
                    const Divider(),
                    ClinicalDetailRow(
                      label: 'AS7341 480 nm (Blue)',
                      value: '${session.readings!['as7341_480nm']} counts',
                    ),
                    const Divider(),
                    ClinicalDetailRow(
                      label: 'AS7341 515 nm (Cyan)',
                      value: '${session.readings!['as7341_515nm']} counts',
                    ),
                    const Divider(),
                    ClinicalDetailRow(
                      label: 'AS7341 555 nm (Green)',
                      value: '${session.readings!['as7341_555nm']} counts',
                    ),
                    const Divider(),
                    ClinicalDetailRow(
                      label: 'AS7341 590 nm (Yellow)',
                      value: '${session.readings!['as7341_590nm']} counts',
                    ),
                    const Divider(),
                    ClinicalDetailRow(
                      label: 'AS7341 630 nm (Orange)',
                      value: '${session.readings!['as7341_630nm']} counts',
                    ),
                    const Divider(),
                    ClinicalDetailRow(
                      label: 'AS7341 680 nm (Red)',
                      value: '${session.readings!['as7341_680nm']} counts',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

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

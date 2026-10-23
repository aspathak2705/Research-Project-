import 'package:flutter/material.dart';
import '../../../core/models/device_info.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/patient_service.dart';
import '../../../core/services/report_service.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/clinical_notice_banner.dart';
import '../../../app/design_tokens.dart';
import '../../../app/routes.dart';

class DashboardScreen extends StatefulWidget {
  final DeviceService deviceService;
  final PatientService patientService;
  final ReportService reportService;

  const DashboardScreen({
    super.key,
    required this.deviceService,
    required this.patientService,
    required this.reportService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ClinicalScaffold(
      appBar: AppBar(
        title: const Text('HemoPi Clinical Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Local Storage',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.localStorageManagement),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Clinical Research Banner
            const ClinicalNoticeBanner(
              title: 'Investigational Clinical Device',
              message:
                  'HemoPi is an observational evaluation system. Measurements are investigational and must not be used as the sole basis for clinical diagnosis.',
            ),
            const SizedBox(height: AppSpacing.md),

            // Instrument Readiness Card
            ValueListenableBuilder<DeviceInfo>(
              valueListenable: widget.deviceService.deviceInfoNotifier,
              builder: (context, info, _) {
                final isConnected = info.isConnected;
                return CustomCard(
                  title: 'HemoPi Instrument',
                  subtitle: isConnected ? 'Online on local clinic network' : 'Not reachable on network',
                  trailing: StatusBadge(
                    label: isConnected ? 'Online' : 'Attention Required',
                    type: isConnected ? BadgeType.ready : BadgeType.warning,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isConnected ? Icons.check_circle_outline : Icons.wifi_off_outlined,
                            size: 18,
                            color: isConnected ? AppColors.statusSuccess : AppColors.statusWarning,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              isConnected
                                  ? 'Instrument connected. Ready to prepare patient measurement.'
                                  : 'Connect this phone and HemoPi to the same clinic Wi-Fi network.',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.preflightCheck),
                              icon: const Icon(Icons.fact_check_rounded, size: 18),
                              label: const Text('Check Instrument'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isConnected ? AppColors.primary : AppColors.textMuted,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, AppRoutes.deviceStatus),
                            icon: const Icon(Icons.info_outline_rounded, size: 18),
                            label: const Text('Status'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Primary Action: Start New Measurement
            Card(
              elevation: 0,
              color: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, AppRoutes.measurementSetup),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 34, color: Colors.white),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start New Measurement',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Select patient and record sensor session',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 28),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Quick Stats Row: Patients and Reports
            Row(
              children: [
                Expanded(
                  child: CustomCard(
                    title: 'Patients',
                    subtitle: 'Study participants',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.patientList),
                    child: ValueListenableBuilder(
                      valueListenable: widget.patientService.patientsNotifier,
                      builder: (context, patients, _) => Row(
                        children: [
                          Text(
                            '${patients.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Text(
                            'Registered',
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: CustomCard(
                    title: 'Reports',
                    subtitle: 'Recorded sessions',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.recentReports),
                    child: ValueListenableBuilder(
                      valueListenable: widget.reportService.reportsNotifier,
                      builder: (context, reports, _) => Row(
                        children: [
                          Text(
                            '${reports.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Text(
                            'Saved',
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Navigation Links Card
            CustomCard(
              title: 'Clinical Workflow',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: const Icon(Icons.people_outline_rounded, color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Manage Patients', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Register, review, and search participants', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.patientList),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.statusInfoBg,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: const Icon(Icons.history_rounded, color: AppColors.statusInfo, size: 20),
                    ),
                    title: const Text('Previous Sessions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Timeline of past measurement sessions', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.sessionHistory),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: const Icon(Icons.storage_outlined, color: AppColors.textSecondary, size: 20),
                    ),
                    title: const Text('Settings & Storage', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Review offline storage and backup files', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.localStorageManagement),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) Navigator.pushNamed(context, AppRoutes.patientList);
          if (index == 2) Navigator.pushNamed(context, AppRoutes.recentReports);
          if (index == 3) Navigator.pushNamed(context, AppRoutes.deviceStatus);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors_rounded),
            label: 'Instrument',
          ),
        ],
      ),
    );
  }
}

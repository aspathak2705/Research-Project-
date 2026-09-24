import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/device_info.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/patient_service.dart';
import '../../../core/services/report_service.dart';
import '../../../shared/widgets/status_badge.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage_outlined),
            tooltip: 'Local Storage Management',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.localStorageManagement),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: '2.1.0 (Android Local Storage)',
                children: [
                  const SizedBox(height: 12),
                  const Text(AppConstants.researchNotice),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Notice banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.science_outlined, color: Colors.amber.shade900),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppConstants.researchNotice,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Device Status Card
            ValueListenableBuilder<DeviceInfo>(
              valueListenable: widget.deviceService.deviceInfoNotifier,
              builder: (context, info, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              info.deviceName,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            StatusBadge(
                              label: info.isConnected ? 'Connected' : 'Disconnected',
                              type: info.isConnected ? BadgeType.connected : BadgeType.error,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hostname: ${info.hostname}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.deviceStatus),
                          icon: const Icon(Icons.settings_remote_outlined, size: 18),
                          label: const Text('View Device Status'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Start Measurement Action Card
            Card(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline, size: 28, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'New Measurement',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configure subject parameters and launch hardware acquisition sequence.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.measurementSetup),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Start Measurement Setup'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Navigation Grid
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.patientList),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 32, color: theme.colorScheme.primary),
                            const SizedBox(height: 8),
                            const Text('Subjects', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            ValueListenableBuilder(
                              valueListenable: widget.patientService.patientsNotifier,
                              builder: (context, patients, _) => Text(
                                '${patients.length} Local Records',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.recentReports),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(Icons.assessment_outlined, size: 32, color: theme.colorScheme.primary),
                            const SizedBox(height: 8),
                            const Text('Reports', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            ValueListenableBuilder(
                              valueListenable: widget.reportService.reportsNotifier,
                              builder: (context, reports, _) => Text(
                                '${reports.length} Generated',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Secondary Quick Actions Card
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.history, color: theme.colorScheme.primary),
                    title: const Text('All Session History'),
                    subtitle: const Text('View past local acquisition session logs'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.sessionHistory),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.folder_open_outlined, color: theme.colorScheme.primary),
                    title: const Text('Report History & Export'),
                    subtitle: const Text('Search and export generated research reports'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.reportHistory),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.bug_report_outlined, color: theme.colorScheme.secondary),
                    title: const Text('Diagnostics & Hardware Status'),
                    subtitle: const Text('Inspect I2C bus metrics and rejection logs'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.diagnostics),
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
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Subjects'),
          NavigationDestination(icon: Icon(Icons.assessment_outlined), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_remote_outlined), label: 'Device'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/models/device_info.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/patient_service.dart';
import '../../../core/services/report_service.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/custom_card.dart';
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
        title: const Text('HemoPi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Data Storage',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.localStorageManagement),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Clinical Research Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Research Study Protocol: Non-invasive observational evaluation.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Instrument Readiness Card
            ValueListenableBuilder<DeviceInfo>(
              valueListenable: widget.deviceService.deviceInfoNotifier,
              builder: (context, info, _) {
                final isConnected = info.isConnected;
                return CustomCard(
                  title: 'HemoPi Instrument',
                  subtitle: isConnected ? 'Connected & ready' : 'Not reachable on network',
                  trailing: StatusBadge(
                    label: isConnected ? 'Ready' : 'Needs Attention',
                    type: isConnected ? BadgeType.ready : BadgeType.warning,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isConnected ? Icons.check_circle_outline : Icons.wifi_off_outlined,
                            size: 18,
                            color: isConnected ? const Color(0xFF0D8A58) : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isConnected
                                  ? 'Instrument connected. Sensors detected and operational.'
                                  : 'Connect this phone and HemoPi to the same clinic network.',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.deviceStatus),
                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                        label: const Text('Check Sensor Health'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),

            // Primary Action: Start New Measurement
            Card(
              elevation: 0,
              color: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, AppRoutes.measurementSetup),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
                      ),
                      const SizedBox(width: 18),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Measurement',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Select patient and start sensor recording session',
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
            const SizedBox(height: 18),

            // Quick Stats Row: Patients and Reports
            Row(
              children: [
                Expanded(
                  child: CustomCard(
                    title: 'Patients',
                    subtitle: 'Study cohort',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.patientList),
                    child: ValueListenableBuilder(
                      valueListenable: widget.patientService.patientsNotifier,
                      builder: (context, patients, _) => Row(
                        children: [
                          Text(
                            '${patients.length}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Registered',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
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
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Saved',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Navigation Links Card
            CustomCard(
              title: 'Clinical Workflow',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.people_outline_rounded, color: theme.colorScheme.primary, size: 20),
                    ),
                    title: const Text('Manage Patients', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Register, review, and search participants', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.patientList),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.history_rounded, color: Color(0xFF0284C7), size: 20),
                    ),
                    title: const Text('Previous Sessions', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Timeline of past measurement sessions', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.sessionHistory),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.settings_outlined, color: Color(0xFF475569), size: 20),
                    ),
                    title: const Text('Settings & Data Export', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Review offline storage and backup files', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded),
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

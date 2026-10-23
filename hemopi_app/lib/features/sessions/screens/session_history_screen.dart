import 'package:flutter/material.dart';
import '../../../core/models/measurement_session.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../app/design_tokens.dart';
import '../../../app/routes.dart';

class SessionHistoryScreen extends StatefulWidget {
  final SessionService sessionService;

  const SessionHistoryScreen({
    super.key,
    required this.sessionService,
  });

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  List<MeasurementSession> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await widget.sessionService.getSessions();
      if (mounted) {
        setState(() {
          _sessions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load sessions. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClinicalScaffold(
      appBar: AppBar(
        title: const Text('Previous Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? StateView(
                  icon: Icons.error_outline_rounded,
                  iconColor: AppColors.statusError,
                  title: 'Unable to Load Sessions',
                  description: _error!,
                  actionLabel: 'Try Again',
                  onAction: _loadSessions,
                )
              : _sessions.isEmpty
                  ? const StateView(
                      icon: Icons.history_toggle_off_rounded,
                      title: 'No Recorded Sessions',
                      description: 'Initiate a new measurement to begin recording research sessions.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final dateStr = session.createdAt.toIso8601String().replaceAll('T', ' ').substring(0, 16);

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: const Icon(Icons.show_chart_rounded, color: AppColors.primary),
                            ),
                            title: Text(
                              session.sessionId,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                'Subject: ${session.patientId}  •  $dateStr\nValid: ${session.validSamples} / ${session.attemptedSamples}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                              ),
                            ),
                            trailing: StatusBadge(
                              label: session.status.name.toUpperCase(),
                              type: session.validSamples > 0 ? BadgeType.success : BadgeType.warning,
                            ),
                            isThreeLine: true,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.sessionDetails,
                                arguments: session,
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}

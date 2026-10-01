import 'package:flutter/material.dart';
import '../../../core/models/measurement_session.dart';
import '../../../core/services/session_service.dart';
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
    return Scaffold(
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
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSessions,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_toggle_off_rounded, size: 48, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No Previous Sessions',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Completed patient acquisition recordings will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.measurementSetup),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('New Measurement'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final dateStr = session.createdAt.toIso8601String().replaceAll('T', ' ').substring(0, 16);

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE0F2FE),
                              child: const Icon(Icons.sensors_rounded, color: Color(0xFF0284C7)),
                            ),
                            title: Text(
                              'Patient: ${session.patientId}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '$dateStr  •  ${session.validSamples} valid / ${session.attemptedSamples} total',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
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

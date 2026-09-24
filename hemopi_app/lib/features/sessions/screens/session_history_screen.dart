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
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSessions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _sessions.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No acquisition sessions recorded yet.', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.insert_chart_outlined),
                            ),
                            title: Text('Session: ${session.sessionId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Subject: ${session.patientId} | ${session.createdAt.toIso8601String().substring(0, 10)}\nSamples: ${session.attemptedSamples} (Valid: ${session.validSamples})',
                            ),
                            trailing: const Icon(Icons.chevron_right),
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

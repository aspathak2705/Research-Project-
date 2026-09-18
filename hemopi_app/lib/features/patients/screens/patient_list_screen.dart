import 'package:flutter/material.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/patient_service.dart';
import '../../../app/routes.dart';

class PatientListScreen extends StatefulWidget {
  final PatientService patientService;

  const PatientListScreen({
    super.key,
    required this.patientService,
  });

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  List<Patient> _patients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await widget.patientService.getPatients();
      if (mounted) {
        setState(() {
          _patients = list;
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
        title: const Text('Patient Registry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPatients,
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
                        onPressed: _loadPatients,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _patients.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No patients registered yet.', style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.pushNamed(context, AppRoutes.addPatient);
                              _loadPatients();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Patient'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _patients.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final patient = _patients[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                patient.patientId.substring(0, patient.patientId.length > 3 ? 3 : patient.patientId.length).toUpperCase(),
                              ),
                            ),
                            title: Text('ID: ${patient.patientId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Age: ${patient.age ?? 'N/A'} | Sex: ${patient.sex ?? 'N/A'}${patient.notes != null ? ' | Notes: ${patient.notes}' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.patientDetail,
                                arguments: patient,
                              );
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.addPatient);
          _loadPatients();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('New Patient'),
      ),
    );
  }
}

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
  List<Patient> _filteredPatients = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _searchController.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterList() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPatients = _patients;
      } else {
        _filteredPatients = _patients.where((p) {
          final idMatch = p.patientId.toLowerCase().contains(query);
          final notesMatch = (p.notes ?? '').toLowerCase().contains(query);
          return idMatch || notesMatch;
        }).toList();
      }
    });
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
          _filteredPatients = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load patients. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadPatients,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patients by ID or notes…',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFDC2626)),
                              const SizedBox(height: 16),
                              Text(_error!, style: const TextStyle(fontSize: 16, color: Color(0xFF1E293B))),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPatients,
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredPatients.isEmpty
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
                                    child: const Icon(Icons.person_search_outlined, size: 48, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _patients.isEmpty ? 'No Patients Registered Yet' : 'No Matching Patients',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _patients.isEmpty
                                        ? 'Register a study participant to begin recording research measurements.'
                                        : 'Check the spelling or clear search filter.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
                                  ),
                                  if (_patients.isEmpty) ...[
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        await Navigator.pushNamed(context, AppRoutes.addPatient);
                                        _loadPatients();
                                      },
                                      icon: const Icon(Icons.person_add_rounded),
                                      label: const Text('Add Patient'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredPatients.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final patient = _filteredPatients[index];
                              return Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFE0F2F1),
                                    child: const Icon(Icons.person_rounded, color: Color(0xFF007A78)),
                                  ),
                                  title: Text(
                                    patient.patientId,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      '${patient.age != null ? "Age: ${patient.age}  •  " : ""}${patient.sex ?? "Unspecified"}${patient.notes != null ? "  •  ${patient.notes}" : ""}',
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.addPatient);
          _loadPatients();
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Patient'),
      ),
    );
  }
}

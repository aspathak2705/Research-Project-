import 'package:flutter/material.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/patient_service.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../app/design_tokens.dart';
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
    return ClinicalScaffold(
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patients by ID or notes…',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: AppSpacing.md),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? StateView(
                        icon: Icons.cloud_off_rounded,
                        iconColor: AppColors.statusError,
                        title: 'Unable to Load Patients',
                        description: _error!,
                        actionLabel: 'Try Again',
                        onAction: _loadPatients,
                      )
                    : _filteredPatients.isEmpty
                        ? StateView(
                            icon: Icons.person_search_outlined,
                            title: _patients.isEmpty ? 'No Patients Registered Yet' : 'No Matching Patients',
                            description: _patients.isEmpty
                                ? 'Register a study participant to begin recording research measurements.'
                                : 'Check spelling or clear the search query.',
                            actionLabel: _patients.isEmpty ? 'Register Patient' : null,
                            onAction: _patients.isEmpty
                                ? () async {
                                    await Navigator.pushNamed(context, AppRoutes.addPatient);
                                    _loadPatients();
                                  }
                                : null,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                            itemCount: _filteredPatients.length,
                            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final patient = _filteredPatients[index];
                              return Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primaryLight,
                                    child: const Icon(Icons.person_rounded, color: AppColors.primary),
                                  ),
                                  title: Text(
                                    patient.patientId,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 3.0),
                                    child: Text(
                                      '${patient.age != null ? "Age: ${patient.age}  •  " : ""}${patient.sex ?? "Unspecified"}${patient.notes != null ? "  •  ${patient.notes}" : ""}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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

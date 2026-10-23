import 'package:flutter/material.dart';
import '../../../core/services/patient_service.dart';
import '../../../shared/widgets/clinical_scaffold.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../app/design_tokens.dart';

class AddPatientScreen extends StatefulWidget {
  final PatientService patientService;

  const AddPatientScreen({
    super.key,
    required this.patientService,
  });

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _ageController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedSex = 'Unspecified';
  bool _isSaving = false;

  @override
  void dispose() {
    _idController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final age = int.tryParse(_ageController.text.trim());
      await widget.patientService.createPatient(
        patientId: _idController.text.trim(),
        age: age,
        sex: _selectedSex,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient registered successfully.'),
            backgroundColor: AppColors.statusSuccess,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Could not register patient. Please check the details and try again.';
        if (e.toString().contains('409') || e.toString().toLowerCase().contains('duplicate')) {
          msg = 'A patient with this ID already exists. Please use a unique identifier.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.statusError,
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClinicalScaffold(
      appBar: AppBar(
        title: const Text('Register Patient'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomCard(
                title: 'Participant Information',
                subtitle: 'Standard clinical identifiers for this subject',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Patient Identifier
                    TextFormField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: 'Patient Identifier *',
                        hintText: 'e.g. SUBJ-0042',
                        prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textMuted),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Patient Identifier is required.';
                        }
                        if (value.trim().length < 2) {
                          return 'Identifier must have at least 2 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Age
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Age (Years)',
                        hintText: 'e.g. 35',
                        prefixIcon: Icon(Icons.cake_outlined, color: AppColors.textMuted),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final age = int.tryParse(value.trim());
                          if (age == null || age < 0 || age > 125) {
                            return 'Enter a valid age between 0 and 125.';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Biological Sex
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSex,
                      decoration: const InputDecoration(
                        labelText: 'Biological Sex',
                        prefixIcon: Icon(Icons.wc_outlined, color: AppColors.textMuted),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Unspecified', child: Text('Unspecified')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSex = val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Clinical Notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Clinical / Study Notes (Optional)',
                        hintText: 'e.g. Fasting state, baseline reference Hb, clinical cohort notes…',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 40.0),
                          child: Icon(Icons.notes_outlined, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePatient,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(_isSaving ? 'Registering…' : 'Register Patient'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

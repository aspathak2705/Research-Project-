import 'package:flutter/material.dart';
import '../../../core/services/patient_service.dart';

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
          const SnackBar(content: Text('Patient registered successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registering patient: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Patient Record'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'Patient Subject ID *',
                  hintText: 'e.g. SUBJ_001',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Patient ID is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age (Years)',
                  hintText: 'e.g. 45',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedSex,
                decoration: const InputDecoration(
                  labelText: 'Sex / Gender Category',
                  border: OutlineInputBorder(),
                ),
                items: ['Unspecified', 'Male', 'Female', 'Other']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSex = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Clinical / Research Notes',
                  hintText: 'Optional notes regarding study protocol...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePatient,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Register Patient'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

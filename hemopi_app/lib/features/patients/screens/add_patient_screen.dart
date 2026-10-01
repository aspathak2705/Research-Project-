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
          const SnackBar(
            content: Text('Patient registered successfully.'),
            backgroundColor: Color(0xFF0D8A58),
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
            backgroundColor: const Color(0xFFDC2626),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Patient'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Participant Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter standard clinical research identifiers for this subject.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _idController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Patient / Subject ID *',
                  hintText: 'e.g. SUBJ-001',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a patient identifier.';
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
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final n = int.tryParse(value.trim());
                    if (n == null || n < 0 || n > 125) {
                      return 'Please enter a valid age between 0 and 125.';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedSex,
                decoration: const InputDecoration(
                  labelText: 'Biological Sex',
                  prefixIcon: Icon(Icons.wc_outlined),
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
                  labelText: 'Clinical Notes (Optional)',
                  hintText: 'Medical history notes, clinical observations, or study protocol notes…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _isSaving ? null : _savePatient,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Patient'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

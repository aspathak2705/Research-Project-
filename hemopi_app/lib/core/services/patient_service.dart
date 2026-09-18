import 'package:flutter/foundation.dart';
import '../models/patient.dart';

abstract class PatientService {
  ValueListenable<List<Patient>> get patientsNotifier;
  Future<List<Patient>> getPatients();
  Future<Patient> createPatient({
    required String patientId,
    int? age,
    String? sex,
    String? notes,
  });
}

class Phase1PatientService implements PatientService {
  final ValueNotifier<List<Patient>> _patients = ValueNotifier([]);

  @override
  ValueListenable<List<Patient>> get patientsNotifier => _patients;

  @override
  Future<List<Patient>> getPatients() async {
    return _patients.value;
  }

  @override
  Future<Patient> createPatient({
    required String patientId,
    int? age,
    String? sex,
    String? notes,
  }) async {
    final newPatient = Patient(
      patientId: patientId,
      age: age,
      sex: sex,
      notes: notes,
      createdAt: DateTime.now(),
    );
    _patients.value = [..._patients.value, newPatient];
    return newPatient;
  }
}

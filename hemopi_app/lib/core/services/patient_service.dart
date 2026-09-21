import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import '../network/api_client.dart';

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

class HttpPatientService implements PatientService {
  final ApiClient apiClient;
  final ValueNotifier<List<Patient>> _patients = ValueNotifier([]);

  HttpPatientService({ApiClient? client}) : apiClient = client ?? ApiClient();

  @override
  ValueListenable<List<Patient>> get patientsNotifier => _patients;

  @override
  Future<List<Patient>> getPatients() async {
    try {
      final res = await apiClient.get('/api/patients');
      if (res != null && res['patients'] is List) {
        final List list = res['patients'];
        final parsed = list.map((p) {
          return Patient(
            patientId: p['patient_id'],
            age: p['age'],
            sex: p['sex'],
            notes: p['notes'],
            createdAt: p['created_at'] != null ? DateTime.parse(p['created_at']) : DateTime.now(),
          );
        }).toList();
        _patients.value = parsed;
        return parsed;
      }
    } catch (_) {}
    return _patients.value;
  }

  @override
  Future<Patient> createPatient({
    required String patientId,
    int? age,
    String? sex,
    String? notes,
  }) async {
    final res = await apiClient.post('/api/patients', {
      'patient_id': patientId,
      'age': age,
      'sex': sex,
      'notes': notes,
    });
    final p = Patient(
      patientId: res['patient_id'],
      age: res['age'],
      sex: res['sex'],
      notes: res['notes'],
      createdAt: res['created_at'] != null ? DateTime.parse(res['created_at']) : DateTime.now(),
    );
    _patients.value = [..._patients.value, p];
    return p;
  }
}

import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import '../storage/local_database_service.dart';

abstract class PatientService {
  ValueListenable<List<Patient>> get patientsNotifier;
  Future<List<Patient>> getPatients();
  Future<Patient?> getPatient(String patientId);
  Future<Patient> createPatient({
    required String patientId,
    String? anonymizedCode,
    int? age,
    String? sex,
    String? notes,
  });
  Future<void> updatePatient(Patient patient);
  Future<void> deletePatient(String patientId);
}

class AndroidLocalPatientService implements PatientService {
  final LocalDatabaseService dbService;
  final ValueNotifier<List<Patient>> _patients = ValueNotifier([]);

  AndroidLocalPatientService({LocalDatabaseService? db})
      : dbService = db ?? LocalDatabaseService();

  @override
  ValueListenable<List<Patient>> get patientsNotifier => _patients;

  @override
  Future<List<Patient>> getPatients() async {
    final list = await dbService.getPatients();
    _patients.value = list;
    return list;
  }

  @override
  Future<Patient?> getPatient(String patientId) async {
    return await dbService.getPatient(patientId);
  }

  @override
  Future<Patient> createPatient({
    required String patientId,
    String? anonymizedCode,
    int? age,
    String? sex,
    String? notes,
  }) async {
    final now = DateTime.now();
    final p = Patient(
      patientId: patientId,
      anonymizedCode: anonymizedCode ?? 'SUBJ_${patientId.hashCode.abs().toString().substring(0, 4)}',
      age: age,
      sex: sex,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      recordStatus: 'ACTIVE',
    );
    await dbService.insertPatient(p);
    await getPatients();
    return p;
  }

  @override
  Future<void> updatePatient(Patient patient) async {
    final updated = Patient(
      patientId: patient.patientId,
      anonymizedCode: patient.anonymizedCode,
      age: patient.age,
      sex: patient.sex,
      notes: patient.notes,
      createdAt: patient.createdAt,
      updatedAt: DateTime.now(),
      recordStatus: patient.recordStatus,
    );
    await dbService.updatePatient(updated);
    await getPatients();
  }

  @override
  Future<void> deletePatient(String patientId) async {
    await dbService.deletePatientSoft(patientId);
    await getPatients();
  }
}

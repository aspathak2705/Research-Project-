import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/patient.dart';
import '../models/measurement_session.dart';
import '../models/report_metadata.dart';

class LocalDatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'hemopi_local.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        patient_id TEXT PRIMARY KEY,
        anonymized_code TEXT NOT NULL,
        age INTEGER,
        sex TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        record_status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE measurement_sessions (
        session_id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        status TEXT NOT NULL,
        sensor_readiness_state TEXT NOT NULL,
        attempted_samples INTEGER NOT NULL,
        valid_samples INTEGER NOT NULL,
        rejected_samples INTEGER NOT NULL,
        validation_status TEXT NOT NULL,
        report_available INTEGER NOT NULL,
        local_valid_csv_file TEXT,
        local_rejected_csv_file TEXT,
        local_summary_file TEXT,
        error_code TEXT,
        error_message TEXT,
        FOREIGN KEY (patient_id) REFERENCES patients (patient_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE report_metadata (
        report_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        patient_id TEXT NOT NULL,
        anonymized_code TEXT NOT NULL,
        generated_at TEXT NOT NULL,
        status TEXT NOT NULL,
        valid_sample_count INTEGER NOT NULL,
        rejected_sample_count INTEGER NOT NULL,
        validation_status TEXT NOT NULL,
        pdf_relative_path TEXT,
        csv_relative_path TEXT,
        is_complete INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES measurement_sessions (session_id),
        FOREIGN KEY (patient_id) REFERENCES patients (patient_id)
      )
    ''');
  }

  // Patient CRUD
  Future<int> insertPatient(Patient patient) async {
    final db = await database;
    return await db.insert(
      'patients',
      patient.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  Future<List<Patient>> getPatients() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'patients',
      where: 'record_status = ?',
      whereArgs: ['ACTIVE'],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Patient.fromMap(maps[i]));
  }

  Future<Patient?> getPatient(String patientId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'patients',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
    if (maps.isEmpty) return null;
    return Patient.fromMap(maps.first);
  }

  Future<int> updatePatient(Patient patient) async {
    final db = await database;
    return await db.update(
      'patients',
      patient.toMap(),
      where: 'patient_id = ?',
      whereArgs: [patient.patientId],
    );
  }

  Future<int> deletePatientSoft(String patientId) async {
    final db = await database;
    return await db.update(
      'patients',
      {'record_status': 'DELETED', 'updated_at': DateTime.now().toIso8601String()},
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
  }

  // Session CRUD
  Future<int> insertSession(MeasurementSession session) async {
    final db = await database;
    return await db.insert(
      'measurement_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MeasurementSession>> getSessions({String? patientId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'measurement_sessions',
      where: patientId != null ? 'patient_id = ?' : null,
      whereArgs: patientId != null ? [patientId] : null,
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => MeasurementSession.fromMap(maps[i]));
  }

  Future<MeasurementSession?> getSession(String sessionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'measurement_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    if (maps.isEmpty) return null;
    return MeasurementSession.fromMap(maps.first);
  }

  // Report CRUD
  Future<int> insertReport(ReportMetadata report) async {
    final db = await database;
    return await db.insert(
      'report_metadata',
      report.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ReportMetadata>> getReports({String? patientId, int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'report_metadata',
      where: patientId != null ? 'patient_id = ?' : null,
      whereArgs: patientId != null ? [patientId] : null,
      orderBy: 'generated_at DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => ReportMetadata.fromMap(maps[i]));
  }

  Future<ReportMetadata?> getReport(String reportId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'report_metadata',
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
    if (maps.isEmpty) return null;
    return ReportMetadata.fromMap(maps.first);
  }

  Future<void> clearAllLocalData() async {
    final db = await database;
    await db.delete('report_metadata');
    await db.delete('measurement_sessions');
    await db.delete('patients');
  }
}

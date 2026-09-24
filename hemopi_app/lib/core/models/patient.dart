class Patient {
  final String patientId;
  final String anonymizedCode;
  final int? age;
  final String? sex;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String recordStatus;

  const Patient({
    required this.patientId,
    required this.anonymizedCode,
    this.age,
    this.sex,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.recordStatus = 'ACTIVE',
  });

  Map<String, dynamic> toMap() {
    return {
      'patient_id': patientId,
      'anonymized_code': anonymizedCode,
      'age': age,
      'sex': sex,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'record_status': recordStatus,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      patientId: map['patient_id'],
      anonymizedCode: map['anonymized_code'] ?? map['patient_id'],
      age: map['age'],
      sex: map['sex'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at'] ?? map['created_at']),
      recordStatus: map['record_status'] ?? 'ACTIVE',
    );
  }
}

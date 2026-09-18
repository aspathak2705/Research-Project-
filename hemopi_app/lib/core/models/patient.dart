class Patient {
  final String patientId;
  final int? age;
  final String? sex;
  final String? notes;
  final DateTime createdAt;

  const Patient({
    required this.patientId,
    this.age,
    this.sex,
    this.notes,
    required this.createdAt,
  });
}

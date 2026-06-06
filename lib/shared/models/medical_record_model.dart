class MedicalRecordModel {
  final String recordId;
  final String patientUserId;
  final String dateOfBirth;
  final String gender;
  final String previousConditions;
  final String chronicConditions;
  final String allergies;
  final String currentMedications;
  final String pastSurgeries;
  final String bloodType;
  final String previousDiagnoses;
  final String doctorNotes;
  final String nurseNotes;
  final String additionalNotes;

  const MedicalRecordModel({
    required this.recordId,
    required this.patientUserId,
    required this.dateOfBirth,
    required this.gender,
    required this.previousConditions,
    required this.chronicConditions,
    required this.allergies,
    required this.currentMedications,
    required this.pastSurgeries,
    required this.bloodType,
    required this.previousDiagnoses,
    required this.doctorNotes,
    required this.nurseNotes,
    required this.additionalNotes,
  });

  factory MedicalRecordModel.fromJson(Map<String, dynamic> json) {
    return MedicalRecordModel(
      recordId: (json['recordId'] ?? '').toString(),
      patientUserId: (json['patientUserId'] ?? '').toString(),
      dateOfBirth: (json['dateOfBirth'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      previousConditions: (json['previousConditions'] ?? '').toString(),
      chronicConditions: (json['chronicConditions'] ?? '').toString(),
      allergies: (json['allergies'] ?? '').toString(),
      currentMedications: (json['currentMedications'] ?? '').toString(),
      pastSurgeries: (json['pastSurgeries'] ?? '').toString(),
      bloodType: (json['bloodType'] ?? '').toString(),
      previousDiagnoses: (json['previousDiagnoses'] ?? '').toString(),
      doctorNotes: (json['doctorNotes'] ?? '').toString(),
      nurseNotes: (json['nurseNotes'] ?? '').toString(),
      additionalNotes: (json['additionalNotes'] ?? '').toString(),
    );
  }
}

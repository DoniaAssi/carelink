class AppointmentModel {
  final String appointmentId;
  final String patientUserId;
  final String providerUserId;
  final String providerName;
  final String providerRole;
  final String specialization;
  final String status;
  final String location;
  final String notes;
  final DateTime? scheduledAt;

  const AppointmentModel({
    required this.appointmentId,
    required this.patientUserId,
    required this.providerUserId,
    required this.providerName,
    required this.providerRole,
    required this.specialization,
    required this.status,
    required this.location,
    required this.notes,
    required this.scheduledAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['scheduledAt'] ?? '').toString();
    return AppointmentModel(
      appointmentId:
          (json['appointmentId'] ?? json['requestId'] ?? '').toString(),
      patientUserId: (json['patientUserId'] ?? '').toString(),
      providerUserId: (json['providerUserId'] ?? json['doctorUserId'] ?? '')
          .toString(),
      providerName:
          (json['providerName'] ?? json['doctorName'] ?? '').toString(),
      providerRole: (json['providerRole'] ?? '').toString(),
      specialization: (json['specialization'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      location: (json['location'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      scheduledAt: DateTime.tryParse(rawDate.replaceFirst(' ', 'T')),
    );
  }
}

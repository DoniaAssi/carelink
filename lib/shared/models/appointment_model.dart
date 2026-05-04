class AppointmentModel {
  final String appointmentId;
  final String patientUserId;
  final String providerUserId;
  final String providerName;
  final String providerRole;
  final String specialization;
  final String status;
  final String location;
  final String visitAddress;
  final String locationNote;
  final String symptoms;
  final bool isUrgent;
  final String additionalNotes;
  final String paymentMethod;
  final String paymentStatus;
  final double? visitLatitude;
  final double? visitLongitude;
  final String notes;
  final DateTime? scheduledAt;
  final double? providerCurrentLat;
  final double? providerCurrentLng;
  final DateTime? providerLocationUpdatedAt;
  /// Set when patient submitted a post-visit rating (1–5).
  final int? patientRatingStars;
  final String patientRatingComment;

  const AppointmentModel({
    required this.appointmentId,
    required this.patientUserId,
    required this.providerUserId,
    required this.providerName,
    required this.providerRole,
    required this.specialization,
    required this.status,
    required this.location,
    required this.visitAddress,
    required this.locationNote,
    required this.symptoms,
    required this.isUrgent,
    required this.additionalNotes,
    required this.paymentMethod,
    required this.paymentStatus,
    this.visitLatitude,
    this.visitLongitude,
    required this.notes,
    required this.scheduledAt,
    this.providerCurrentLat,
    this.providerCurrentLng,
    this.providerLocationUpdatedAt,
    this.patientRatingStars,
    this.patientRatingComment = '',
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['scheduledAt'] ?? '').toString();
    return AppointmentModel(
      appointmentId: (json['appointmentId'] ?? json['requestId'] ?? '')
          .toString(),
      patientUserId: (json['patientUserId'] ?? '').toString(),
      providerUserId: (json['providerUserId'] ?? json['doctorUserId'] ?? '')
          .toString(),
      providerName: (json['providerName'] ?? json['doctorName'] ?? '')
          .toString(),
      providerRole: (json['providerRole'] ?? '').toString(),
      specialization: (json['specialization'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      location: (json['location'] ?? '').toString(),
      visitAddress: (json['visitAddress'] ?? '').toString(),
      locationNote: (json['locationNote'] ?? '').toString(),
      symptoms: (json['symptoms'] ?? '').toString(),
      isUrgent:
          json['isUrgent'] == true ||
          json['isUrgent'] == 1 ||
          (json['isUrgent'] ?? '').toString() == '1',
      additionalNotes: (json['additionalNotes'] ?? '').toString(),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      paymentStatus: (json['paymentStatus'] ?? '').toString(),
      visitLatitude: double.tryParse((json['visitLatitude'] ?? '').toString()),
      visitLongitude: double.tryParse(
        (json['visitLongitude'] ?? '').toString(),
      ),
      notes: (json['notes'] ?? '').toString(),
      scheduledAt: DateTime.tryParse(rawDate.replaceFirst(' ', 'T')),
      providerCurrentLat: double.tryParse(
        (json['providerCurrentLat'] ?? '').toString(),
      ),
      providerCurrentLng: double.tryParse(
        (json['providerCurrentLng'] ?? '').toString(),
      ),
      providerLocationUpdatedAt: DateTime.tryParse(
        (json['providerLocationUpdatedAt'] ?? '').toString().replaceFirst(
              ' ',
              'T',
            ),
      ),
      patientRatingStars: _parseOptionalInt(json['patientRatingStars']),
      patientRatingComment: (json['patientRatingComment'] ?? '').toString(),
    );
  }

  static int? _parseOptionalInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}

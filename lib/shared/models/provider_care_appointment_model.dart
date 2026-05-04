/// One row from `GET /providers/appointments` (servicerequest as appointment/visit).
class ProviderCareAppointment {
  final String requestId;
  final String patientUserId;
  final String providerUserId;
  final String serviceType;
  final String status;
  final String notes;
  final String location;
  final String visitAddress;
  final DateTime? scheduledAt;
  final String patientName;
  final double? providerCurrentLat;
  final double? providerCurrentLng;
  final DateTime? providerLocationUpdatedAt;

  const ProviderCareAppointment({
    required this.requestId,
    required this.patientUserId,
    required this.providerUserId,
    required this.serviceType,
    required this.status,
    required this.notes,
    required this.location,
    required this.visitAddress,
    required this.scheduledAt,
    required this.patientName,
    this.providerCurrentLat,
    this.providerCurrentLng,
    this.providerLocationUpdatedAt,
  });

  factory ProviderCareAppointment.fromJson(Map<String, dynamic> json) {
    final raw = (json['scheduledAt'] ?? '').toString();
    return ProviderCareAppointment(
      requestId: (json['requestId'] ?? '').toString(),
      patientUserId: (json['patientUserId'] ?? '').toString(),
      providerUserId: (json['providerUserId'] ?? '').toString(),
      serviceType: (json['serviceType'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString().toLowerCase().trim(),
      notes: (json['notes'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      visitAddress: (json['visitAddress'] ?? '').toString(),
      scheduledAt: DateTime.tryParse(raw.replaceFirst(' ', 'T')),
      patientName: (json['patientName'] ?? '').toString(),
      providerCurrentLat: double.tryParse(
        (json['providerCurrentLat'] ?? '').toString(),
      ),
      providerCurrentLng: double.tryParse(
        (json['providerCurrentLng'] ?? '').toString(),
      ),
      providerLocationUpdatedAt: DateTime.tryParse(
        (json['providerLocationUpdatedAt'] ?? '')
            .toString()
            .replaceFirst(' ', 'T'),
      ),
    );
  }
}

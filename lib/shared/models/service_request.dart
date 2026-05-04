class ServiceRequest {
  final String id;
  final String patientId;
  final String providerId;
  final String patientName;
  final String serviceType;
  final String location;
  final DateTime scheduledDate;
  final String status; // pending, scheduled, completed, cancelled
  final String? notes;
  final DateTime createdAt;

  ServiceRequest({
    required this.id,
    required this.patientId,
    required this.providerId,
    this.patientName = '',
    required this.serviceType,
    required this.location,
    required this.scheduledDate,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: (json['id'] ?? json['requestId'] ?? '').toString(),
      patientId: (json['patientId'] ?? json['patientUserId'] ?? '').toString(),
      providerId: (json['providerId'] ?? json['providerUserId'] ?? '').toString(),
      patientName: (json['patientName'] ?? '').toString(),
      serviceType: json['serviceType'] ?? '',
      location: json['location'] ?? '',
      scheduledDate: _parseDateTime(
        json['scheduledDate'] ?? json['scheduledAt'],
      ),
      status: _normalizeStatus(json['status']),
      notes: json['notes']?.toString(),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'providerId': providerId,
      'patientName': patientName,
      'serviceType': serviceType,
      'location': location,
      'scheduledDate': scheduledDate.toIso8601String(),
      'status': status,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static String _normalizeStatus(dynamic value) {
    final status = (value ?? 'pending').toString().toLowerCase();
    if (status == 'confirmed') return 'scheduled';
    return status;
  }
}

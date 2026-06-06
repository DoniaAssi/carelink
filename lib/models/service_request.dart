class ServiceRequest {
  final int id;
  final int patientId;
  final int providerId;
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
    required this.serviceType,
    required this.location,
    required this.scheduledDate,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: _parseId(json['id']),
      patientId: _parseId(json['patientId']),
      providerId: _parseId(json['providerId']),
      serviceType: json['serviceType'] ?? '',
      location: json['location'] ?? '',
      scheduledDate: _parseDateTime(json['scheduledDate']),
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'providerId': providerId,
      'serviceType': serviceType,
      'location': location,
      'scheduledDate': scheduledDate.toIso8601String(),
      'status': status,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static int _parseId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

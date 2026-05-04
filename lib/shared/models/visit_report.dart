class VisitReport {
  /// Backend uses UUID strings; numeric ids are still supported in JSON.
  final String id;
  final String providerId;
  final String patientId;
  final String patientName;
  final String serviceType;
  final String location;
  final DateTime scheduledDate;
  final int durationHours;
  final String visitSummary;
  final String vitalSigns;
  final String medications;
  final String observations;
  final String recommendations;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  VisitReport({
    required this.id,
    required this.providerId,
    required this.patientId,
    required this.patientName,
    required this.serviceType,
    required this.location,
    required this.scheduledDate,
    required this.durationHours,
    required this.visitSummary,
    required this.vitalSigns,
    required this.medications,
    required this.observations,
    required this.recommendations,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VisitReport.fromJson(Map<String, dynamic> json) {
    return VisitReport(
      id: _stringId(json['id']),
      providerId: _stringId(json['providerId']),
      patientId: _stringId(json['patientId']),
      patientName: json['patientName'] ?? '',
      serviceType: json['serviceType'] ?? '',
      location: json['location'] ?? '',
      scheduledDate: _parseDateTime(json['scheduledDate']),
      durationHours: _parseInt(json['durationHours']),
      visitSummary: json['visitSummary'] ?? '',
      vitalSigns: json['vitalSigns'] ?? '',
      medications: json['medications'] ?? '',
      observations: json['observations'] ?? '',
      recommendations: json['recommendations'] ?? '',
      status: json['status'] ?? 'completed',
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerId': providerId,
      'patientId': patientId,
      'patientName': patientName,
      'serviceType': serviceType,
      'location': location,
      'scheduledDate': scheduledDate.toIso8601String(),
      'durationHours': durationHours,
      'visitSummary': visitSummary,
      'vitalSigns': vitalSigns,
      'medications': medications,
      'observations': observations,
      'recommendations': recommendations,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static String _stringId(dynamic value) {
    if (value == null) return '';
    final s = value.toString().trim();
    return s;
  }

  static int _parseInt(dynamic value) {
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

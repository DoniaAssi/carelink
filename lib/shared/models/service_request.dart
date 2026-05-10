class ServiceRequest {
  final String id;
  final String patientId;
  final String providerId;
  final String patientName;
  final String patientPhone;
  final int patientAge;
  final String serviceType;
  final String location;
  final String patientAddress;
  final double? gpsLat;
  final double? gpsLng;
  final DateTime scheduledDate;
  final String status; // pending, assigned, in_progress, waiting_report, completed, cancelled
  final String? notes;
  final String reasonForVisit;
  final String medicalCondition;
  final int expectedDurationHours;
  final double price;
  final DateTime? actualStartedAt;
  final DateTime? actualEndedAt;
  final int actualDurationMinutes;
  final List<Map<String, dynamic>> nursingActivities;
  final DateTime createdAt;

  ServiceRequest({
    required this.id,
    required this.patientId,
    required this.providerId,
    this.patientName = '',
    this.patientPhone = '',
    this.patientAge = 0,
    required this.serviceType,
    required this.location,
    this.patientAddress = '',
    this.gpsLat,
    this.gpsLng,
    required this.scheduledDate,
    required this.status,
    this.notes,
    this.reasonForVisit = '',
    this.medicalCondition = '',
    this.expectedDurationHours = 2,
    this.price = 0,
    this.actualStartedAt,
    this.actualEndedAt,
    this.actualDurationMinutes = 0,
    this.nursingActivities = const [],
    required this.createdAt,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: (json['id'] ?? json['requestId'] ?? '').toString(),
      patientId: (json['patientId'] ?? json['patientUserId'] ?? '').toString(),
      providerId: (json['providerId'] ?? json['providerUserId'] ?? '').toString(),
      patientName: (json['patientName'] ?? '').toString(),
      patientPhone: (json['patientPhone'] ?? json['phone'] ?? '').toString(),
      patientAge: _parseInt(json['patientAge'] ?? json['age']),
      serviceType: json['serviceType'] ?? '',
      location: json['location'] ?? '',
      patientAddress: (json['patientAddress'] ?? '').toString(),
      gpsLat: _parseDoubleOrNull(json['gpsLat']),
      gpsLng: _parseDoubleOrNull(json['gpsLng']),
      scheduledDate: _parseDateTime(
        json['scheduledDate'] ?? json['scheduledAt'],
      ),
      status: _normalizeStatus(json['status']),
      notes: json['notes']?.toString(),
      reasonForVisit: (json['reasonForVisit'] ?? '').toString(),
      medicalCondition: (json['medicalCondition'] ?? '').toString(),
      expectedDurationHours: _parseInt(json['expectedDurationHours']) == 0
          ? 2
          : _parseInt(json['expectedDurationHours']),
      price: _parseDouble(json['price']),
      actualStartedAt: _parseNullableDateTime(json['actualStartedAt']),
      actualEndedAt: _parseNullableDateTime(json['actualEndedAt']),
      actualDurationMinutes: _parseInt(json['actualDurationMinutes']),
      nursingActivities: _parseActivities(json['nursingActivities']),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'providerId': providerId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'patientAge': patientAge,
      'serviceType': serviceType,
      'location': location,
      'patientAddress': patientAddress,
      'gpsLat': gpsLat,
      'gpsLng': gpsLng,
      'scheduledDate': scheduledDate.toIso8601String(),
      'status': status,
      'notes': notes,
      'reasonForVisit': reasonForVisit,
      'medicalCondition': medicalCondition,
      'expectedDurationHours': expectedDurationHours,
      'price': price,
      'actualStartedAt': actualStartedAt?.toIso8601String(),
      'actualEndedAt': actualEndedAt?.toIso8601String(),
      'actualDurationMinutes': actualDurationMinutes,
      'nursingActivities': nursingActivities,
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

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static double? _parseDoubleOrNull(dynamic value) {
    if (value == null) return null;
    final parsed = _parseDouble(value);
    return parsed == 0 && value.toString() != '0' ? null : parsed;
  }

  static List<Map<String, dynamic>> _parseActivities(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  static String _normalizeStatus(dynamic value) {
    final status = (value ?? 'pending').toString().toLowerCase();
    if (status == 'confirmed' || status == 'scheduled') return 'assigned';
    if (status == 'visit ended') return 'waiting_report';
    return status;
  }
}

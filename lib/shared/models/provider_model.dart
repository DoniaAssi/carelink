class AvailabilitySlot {
  final String day;
  final String startTime;
  final String endTime;

  const AvailabilitySlot({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      day: json['day']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
    );
  }

  String get label => '$day $startTime-$endTime';

  String get formattedDay => day.isEmpty ? 'Day unavailable' : day;

  String get formattedTime =>
      '${_formatClock(startTime)} - ${_formatClock(endTime)}';

  String get durationLabel {
    final start = _parseMinutes(startTime);
    final end = _parseMinutes(endTime);

    if (start == null || end == null || end <= start) {
      return 'Duration unavailable';
    }

    final diff = end - start;
    final hours = diff ~/ 60;
    final minutes = diff % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }
    return '$minutes min';
  }

  static String _formatClock(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;

    final period = hour >= 12 ? 'PM' : 'AM';
    final normalizedHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$normalizedHour:${minute.toString().padLeft(2, '0')} $period';
  }

  static int? _parseMinutes(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return hour * 60 + minute;
  }
}

class ProviderModel {
  final String userId;
  final String fullName;
  final String specialization;
  final String serviceType;
  final double overallRating;
  final String role;
  final bool isAvailable;
  final double? consultationFee;
  /// سنوات الخبرة (من جدول careprovider) — تُستخدم في التوصية الذكية.
  final int? experienceYears;
  final double? gpsLat;
  final double? gpsLng;
  final List<String> availableTimeSlots;
  final List<AvailabilitySlot> availableSlots;

  ProviderModel({
    required this.userId,
    required this.fullName,
    required this.specialization,
    required this.serviceType,
    required this.overallRating,
    required this.role,
    required this.isAvailable,
    this.consultationFee,
    this.experienceYears,
    this.gpsLat,
    this.gpsLng,
    List<String>? availableTimeSlots,
    List<AvailabilitySlot>? availableSlots,
  }) : availableTimeSlots = availableTimeSlots ?? const [],
       availableSlots = availableSlots ?? const [];

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    final rating =
        double.tryParse(json['overallRating']?.toString() ?? '0') ?? 0;
    final role = json['role']?.toString() ?? 'doctor';
    final isAvailable =
        json['isAvailable'] == true ||
        json['isAvailable'] == 1 ||
        json['isAvailable']?.toString() == '1';
    final gpsLat = double.tryParse(json['gpsLat']?.toString() ?? '');
    final gpsLng = double.tryParse(json['gpsLng']?.toString() ?? '');
    final fee = double.tryParse(
      json['consultationFee']?.toString() ??
          json['hourlyRate']?.toString() ??
          json['price']?.toString() ??
          '',
    );
    final expYears = int.tryParse(json['experienceYears']?.toString() ?? '');
    final serviceType =
        (json['serviceType'] ??
                json['serviceCategory'] ??
                json['service'] ??
                '')
            .toString()
            .trim();

    final dynamic rawAvailableSlots = json['availableSlots'];
    final List<AvailabilitySlot> availableSlots = rawAvailableSlots is List
        ? rawAvailableSlots
              .whereType<Map>()
              .map(
                (e) => AvailabilitySlot.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <AvailabilitySlot>[];

    final dynamic rawAvailableTimeSlots = json['availableTimeSlots'];
    final List<String> availableTimeSlots = availableSlots.isNotEmpty
        ? availableSlots.map((slot) => slot.label).toList()
        : rawAvailableTimeSlots is List
        ? rawAvailableTimeSlots.map((e) => e.toString()).toList()
        : <String>[];

    return ProviderModel(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      specialization: json['specialization']?.toString() ?? '',
      serviceType: serviceType,
      overallRating: rating,
      role: role,
      isAvailable: isAvailable,
      consultationFee: fee,
      experienceYears: expYears,
      gpsLat: gpsLat,
      gpsLng: gpsLng,
      availableTimeSlots: availableTimeSlots,
      availableSlots: availableSlots,
    );
  }
}

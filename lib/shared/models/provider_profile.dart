class ProviderProfile {
  final String providerId;
  final String fullName;
  final String email;
  final String bio;
  final String specialization;
  final int experienceYears;
  final double hourlyRate;
  final String phone;
  final bool isAvailable;
  final List<String> certifications;
  final Map<String, String> availabilitySchedule;

  ProviderProfile({
    required this.providerId,
    required this.fullName,
    required this.email,
    required this.bio,
    required this.specialization,
    required this.experienceYears,
    required this.hourlyRate,
    required this.phone,
    required this.isAvailable,
    required this.certifications,
    required this.availabilitySchedule,
  });

  factory ProviderProfile.fromJson(Map<String, dynamic> json) {
    return ProviderProfile(
      providerId: (json['providerId'] ?? json['id'] ?? '').toString(),
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      bio: json['bio'] ?? '',
      specialization: json['specialization'] ?? '',
      experienceYears: _parseId(json['experienceYears']),
      hourlyRate: _parseDouble(json['hourlyRate']),
      phone: json['phone'] ?? '',
      isAvailable: json['isAvailable'] == 1 || json['isAvailable'] == true,
      certifications: json['certifications'] != null
          ? List<String>.from(json['certifications'])
          : [],
      availabilitySchedule: json['availabilitySchedule'] != null
          ? Map<String, String>.from(json['availabilitySchedule'])
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'providerId': providerId,
      'fullName': fullName,
      'email': email,
      'bio': bio,
      'specialization': specialization,
      'experienceYears': experienceYears,
      'hourlyRate': hourlyRate,
      'phone': phone,
      'isAvailable': isAvailable ? 1 : 0,
      'certifications': certifications,
      'availabilitySchedule': availabilitySchedule,
    };
  }

  static int _parseId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

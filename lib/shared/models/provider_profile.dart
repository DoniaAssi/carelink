class ProviderProfile {
  final String providerId;
  final String fullName;
  final String email;
  final String bio;
  final String specialization;
  final String serviceAreas;
  final String experienceTier;
  final String approvalStatus;
  final String rateAcceptanceStatus;
  final int experienceYears;
  final double hourlyRate;
  final double rating;
  final String phone;
  final String profileImageUrl;
  final bool isAvailable;
  final bool canWork;
  final String workGateMessage;
  final String nursingLicenseUrl;
  final String medicalCertificateUrl;
  final String idCardUrl;
  final String cvFileUrl;
  final List<String> certifications;
  final Map<String, String> availabilitySchedule;

  ProviderProfile({
    required this.providerId,
    required this.fullName,
    required this.email,
    required this.bio,
    required this.specialization,
    required this.serviceAreas,
    required this.experienceTier,
    required this.approvalStatus,
    required this.rateAcceptanceStatus,
    required this.experienceYears,
    required this.hourlyRate,
    required this.rating,
    required this.phone,
    required this.profileImageUrl,
    required this.isAvailable,
    required this.canWork,
    required this.workGateMessage,
    required this.nursingLicenseUrl,
    required this.medicalCertificateUrl,
    required this.idCardUrl,
    required this.cvFileUrl,
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
      serviceAreas:
          (json['serviceAreas'] ??
                  json['service_areas'] ??
                  json['serviceArea'] ??
                  json['service_area'] ??
                  json['location'] ??
                  '')
              .toString(),
      experienceTier:
          (json['experienceTier'] ?? json['experience_tier'] ?? 'junior')
              .toString(),
      approvalStatus: (json['approvalStatus'] ?? 'pending').toString(),
      rateAcceptanceStatus: (json['rateAcceptanceStatus'] ?? 'pending')
          .toString(),
      experienceYears: _parseId(json['experienceYears']),
      hourlyRate: _parseDouble(json['hourlyRate']),
      rating: _parseDouble(json['rating'] ?? json['overallRating']),
      phone: json['phone'] ?? '',
      profileImageUrl:
          (json['profileImageUrl'] ??
                  json['profilePictureUrl'] ??
                  json['profile_image_url'] ??
                  '')
              .toString(),
      isAvailable: json['isAvailable'] == 1 || json['isAvailable'] == true,
      canWork: json['canWork'] == true,
      workGateMessage: (json['workGateMessage'] ?? json['reason'] ?? '')
          .toString(),
      nursingLicenseUrl: _documentUrl(json, 'nursingLicenseUrl'),
      medicalCertificateUrl: _documentUrl(json, 'medicalCertificateUrl'),
      idCardUrl: _documentUrl(json, 'idCardUrl'),
      cvFileUrl: _documentUrl(json, 'cvFileUrl'),
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
      'serviceAreas': serviceAreas,
      'experienceTier': experienceTier,
      'approvalStatus': approvalStatus,
      'rateAcceptanceStatus': rateAcceptanceStatus,
      'experienceYears': experienceYears,
      'hourlyRate': hourlyRate,
      'rating': rating,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'isAvailable': isAvailable ? 1 : 0,
      'canWork': canWork,
      'workGateMessage': workGateMessage,
      'nursingLicenseUrl': nursingLicenseUrl,
      'medicalCertificateUrl': medicalCertificateUrl,
      'idCardUrl': idCardUrl,
      'cvFileUrl': cvFileUrl,
      'certifications': certifications,
      'availabilitySchedule': availabilitySchedule,
    };
  }

  static String _documentUrl(Map<String, dynamic> json, String camelKey) {
    final snakeKey = camelKey
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst('_url', '');
    final documents = json['documents'];
    final fromDocuments = documents is Map ? documents[camelKey] : null;
    return (json[camelKey] ?? json[snakeKey] ?? fromDocuments ?? '').toString();
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

class Provider {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String specialization;
  final double rating;
  final String role; // nurse or doctor
  final DateTime createdAt;

  Provider({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.specialization,
    required this.rating,
    required this.role,
    required this.createdAt,
  });

  factory Provider.fromJson(Map<String, dynamic> json) {
    return Provider(
      id: _parseId(json['id']),
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      specialization: json['specialization'] ?? '',
      rating: _parseDouble(json['rating']),
      role: json['role'] ?? 'nurse',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'specialization': specialization,
      'rating': rating,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
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

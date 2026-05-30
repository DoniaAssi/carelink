class User {
  final int id;
  final String email;
  final String password;
  final String fullName;
  final String phone;
  final String role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _parseId(json['id']),
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'patient',
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'fullName': fullName,
      'phone': phone,
      'role': role,
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

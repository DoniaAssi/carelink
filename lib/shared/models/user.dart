class User {
  final int id;
  /// UUID from the API; use [carelinkUserId] for backend calls when present.
  final String? serverUserId;
  final String email;
  final String password;
  final String fullName;
  final String phone;
  final String role;
  final DateTime createdAt;

  User({
    required this.id,
    this.serverUserId,
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  /// Prefer server UUID, then numeric [id] as string.
  String get carelinkUserId {
    if (serverUserId != null && serverUserId!.isNotEmpty) {
      return serverUserId!;
    }
    if (id > 0) return id.toString();
    return '';
  }

  /// Alias for code that expects a string `userId` for nurse/provider API paths.
  String get userId => carelinkUserId;

  factory User.fromJson(Map<String, dynamic> json) {
    String? su = json['userId']?.toString().trim();
    if (su == null || su.isEmpty) {
      final idRaw = json['id'];
      if (idRaw is String && int.tryParse(idRaw) == null) {
        su = idRaw;
      }
    }
    return User(
      id: _parseId(json['id'] ?? json['userId']),
      serverUserId: (su != null && su.isNotEmpty) ? su : null,
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
      if (serverUserId != null) 'userId': serverUserId,
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

class PaymentMethod {
  final int id;
  final int providerId;
  final String type;
  final String details;
  final bool isDefault;

  PaymentMethod({
    required this.id,
    required this.providerId,
    required this.type,
    required this.details,
    required this.isDefault,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: _parseId(json['id']),
      providerId: _parseId(json['providerId']),
      type: json['type'] ?? '',
      details: json['details'] ?? '',
      isDefault: (json['isDefault'] == 1 || json['isDefault'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerId': providerId,
      'type': type,
      'details': details,
      'isDefault': isDefault ? 1 : 0,
    };
  }

  static int _parseId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

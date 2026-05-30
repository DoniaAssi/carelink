class PaymentTransaction {
  final int id;
  final int providerId;
  final String service;
  final String patientName;
  final double amount;
  final String status;
  final String paymentMethod;
  final DateTime date;

  PaymentTransaction({
    required this.id,
    required this.providerId,
    required this.service,
    required this.patientName,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.date,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: _parseId(json['id']),
      providerId: _parseId(json['providerId']),
      service: json['service'] ?? '',
      patientName: json['patientName'] ?? '',
      amount: _parseDouble(json['amount']),
      status: json['status'] ?? 'pending',
      paymentMethod: json['paymentMethod'] ?? '',
      date: _parseDateTime(json['date']),
    );
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

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

class PaymentModel {
  final String paymentId;
  final String appointmentId;
  final String patientUserId;
  final String providerUserId;
  final double amount;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime? createdAt;

  const PaymentModel({
    required this.paymentId,
    required this.appointmentId,
    required this.patientUserId,
    required this.providerUserId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      paymentId: (json['paymentId'] ?? '').toString(),
      appointmentId: (json['appointmentId'] ?? json['requestId'] ?? '').toString(),
      patientUserId: (json['patientUserId'] ?? '').toString(),
      providerUserId: (json['providerUserId'] ?? '').toString(),
      amount: double.tryParse((json['amount'] ?? '0').toString()) ?? 0,
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      paymentStatus: (json['paymentStatus'] ?? 'unpaid').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

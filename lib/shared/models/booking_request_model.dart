class BookingRequestModel {
  final String patientId;
  final String providerId;
  final String providerName;
  final String providerRole;
  final String specialization;
  final String serviceType;
  final String appointmentDate;
  final String appointmentTime;
  final double visitLatitude;
  final double visitLongitude;
  final String visitAddress;
  final String locationNote;
  final String patientReason;
  final String symptoms;
  final bool isUrgent;
  final String additionalNotes;
  final double price;

  /// Platform or add-on fees (e.g. travel); included in [totalAmount].
  final double extraFees;
  final String paymentMethod;
  final String paymentStatus;
  final String bookingStatus;

  const BookingRequestModel({
    required this.patientId,
    required this.providerId,
    required this.providerName,
    required this.providerRole,
    required this.specialization,
    required this.serviceType,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.visitLatitude,
    required this.visitLongitude,
    required this.visitAddress,
    required this.locationNote,
    required this.patientReason,
    required this.symptoms,
    required this.isUrgent,
    required this.additionalNotes,
    required this.price,
    this.extraFees = 0,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.bookingStatus,
  });

  /// Total to charge or record (service price + extras).
  double get totalAmount => price + extraFees;

  String get currentCaseSummary {
    final segments = <String>[
      if (patientReason.trim().isNotEmpty) patientReason.trim(),
      if (symptoms.trim().isNotEmpty) symptoms.trim(),
      if (isUrgent) 'Urgent case',
      if (additionalNotes.trim().isNotEmpty) additionalNotes.trim(),
    ];
    return segments.join(' | ');
  }

  BookingRequestModel copyWith({
    String? patientId,
    String? providerId,
    String? providerName,
    String? providerRole,
    String? specialization,
    String? serviceType,
    String? appointmentDate,
    String? appointmentTime,
    double? visitLatitude,
    double? visitLongitude,
    String? visitAddress,
    String? locationNote,
    String? patientReason,
    String? symptoms,
    bool? isUrgent,
    String? additionalNotes,
    double? price,
    double? extraFees,
    String? paymentMethod,
    String? paymentStatus,
    String? bookingStatus,
  }) {
    return BookingRequestModel(
      patientId: patientId ?? this.patientId,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      providerRole: providerRole ?? this.providerRole,
      specialization: specialization ?? this.specialization,
      serviceType: serviceType ?? this.serviceType,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      visitLatitude: visitLatitude ?? this.visitLatitude,
      visitLongitude: visitLongitude ?? this.visitLongitude,
      visitAddress: visitAddress ?? this.visitAddress,
      locationNote: locationNote ?? this.locationNote,
      patientReason: patientReason ?? this.patientReason,
      symptoms: symptoms ?? this.symptoms,
      isUrgent: isUrgent ?? this.isUrgent,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      price: price ?? this.price,
      extraFees: extraFees ?? this.extraFees,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      bookingStatus: bookingStatus ?? this.bookingStatus,
    );
  }

  String get composedNotes {
    final segments = <String>[
      'Service: $serviceType',
      if (visitAddress.trim().isNotEmpty) 'Address: $visitAddress',
      if (locationNote.trim().isNotEmpty) 'LocationNote: $locationNote',
      if (currentCaseSummary.trim().isNotEmpty)
        'CurrentCase: $currentCaseSummary',
      if (patientReason.trim().isNotEmpty) 'Reason: $patientReason',
      if (symptoms.trim().isNotEmpty) 'Symptoms: $symptoms',
      if (isUrgent) 'Urgency: urgent',
      if (additionalNotes.trim().isNotEmpty) 'Additional: $additionalNotes',
      'VisitGPS: ${visitLatitude.toStringAsFixed(6)},${visitLongitude.toStringAsFixed(6)}',
    ];
    return segments.join(' | ');
  }
}

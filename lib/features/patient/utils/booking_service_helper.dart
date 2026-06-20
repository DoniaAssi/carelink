import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';

class BookingServiceHelper {
  static BookingRequestModel createRequestForProvider({
    required ProviderModel provider,
    required String patientId,
    String? recommendationId,
  }) {
    String serviceType = provider.serviceType.trim();
    if (serviceType.isEmpty) {
      if (provider.role.toLowerCase() == 'nurse') {
        serviceType = 'Home Nursing Care';
      } else {
        serviceType = 'General Doctor';
      }
    }

    double price = provider.consultationFee ?? 0;
    if (price <= 0) {
      if (provider.role.toLowerCase() == 'nurse') {
        price = 60;
      } else {
        price = 80;
      }
    }

    return BookingRequestModel(
      patientId: patientId,
      providerId: provider.userId,
      providerName: provider.fullName,
      providerRole: provider.role,
      providerImageUrl: provider.profileImageUrl ?? '',
      specialization: provider.specialization,
      serviceType: serviceType,
      appointmentType: 'home',
      appointmentDate: '',
      appointmentTime: '',
      visitLatitude: provider.gpsLat ?? 0,
      visitLongitude: provider.gpsLng ?? 0,
      visitAddress: '',
      locationNote: '',
      patientReason: '',
      symptoms: '',
      isUrgent: false,
      additionalNotes: '',
      price: price,
      paymentMethod: '',
      paymentStatus: 'unpaid',
      bookingStatus: 'pending',
      recommendationId: recommendationId,
    );
  }
}

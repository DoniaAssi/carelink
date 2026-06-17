import 'package:flutter/material.dart';

import 'package:carelink/features/patient/payment/payment_screen.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/screens/booking_success_screen.dart';
import 'package:carelink/features/patient/widgets/patient_navigation_shell.dart';

import 'package:carelink/core/app_localizations.dart';

/// Patient booking lifecycle:
/// 1. Create a hidden `draft` service request and keep its id in this method.
/// 2. Pass that id to the existing payment screen.
/// 3. After card payment succeeds, submit the paid draft as
///    `pending_provider_approval`.
///
/// The draft is required because the payment ledger references a request id.
/// It is never stored in app state and must not be visible to either party.
class BookingPaymentFlow {
  const BookingPaymentFlow._();

  static Future<void> open({
    required BuildContext context,
    required BookingRequestModel request,
  }) async {
    final api = ApiService();

    // 1. Check for duplicates
    final isDuplicate = await api.checkDuplicateBooking(
      patientId: request.patientId,
      providerId: request.providerId,
      serviceType: request.serviceType,
      date: request.appointmentDate,
      time: request.appointmentTime,
    );

    if (!context.mounted) return;

    if (isDuplicate) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('booking.duplicate.title')),
          content: Text(ctx.l10n.isArabic ? 'لديك طلب حجز موجود بالفعل لهذا الموعد.' : 'You already have a booking request for this appointment.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.tr('booking.duplicate.back')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientNavigationShell(
                      userId: request.patientId,
                      initialTab: 1, // Bookings tab
                    ),
                  ),
                  (route) => false,
                );
              },
              child: Text(ctx.tr('booking.duplicate.viewBookings')),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;

    // 3. Navigate to Payment Screen passing the full request
    final paymentSuccessData = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          request: request,
        ),
      ),
    );

    // 4. Handle Payment result
    if (paymentSuccessData != null && paymentSuccessData['success'] == true) {
      final appointmentId = paymentSuccessData['appointmentId'] as String;
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            patientUserId: request.patientId,
            appointmentId: appointmentId,
            providerName: request.providerName,
            serviceType: request.serviceType,
            appointmentDate: request.appointmentDate,
            appointmentTime: request.appointmentTime,
            amountPaid: request.totalAmount,
          ),
        ),
        (route) => false,
      );
    }
  }
}

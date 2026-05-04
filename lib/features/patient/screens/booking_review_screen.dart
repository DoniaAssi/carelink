import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/features/patient/payment/payment_screen.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';

class BookingReviewScreen extends StatefulWidget {
  final BookingRequestModel request;

  const BookingReviewScreen({super.key, required this.request});

  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  bool _isSubmitting = false;

  Future<void> _confirmBooking() async {
    setState(() => _isSubmitting = true);
    try {
      final request = widget.request.copyWith(
        bookingStatus: 'pending',
        paymentMethod: '',
        paymentStatus: 'unpaid',
      );

      final booking = await ApiService().createBooking(
        patientId: request.patientId,
        providerId: request.providerId,
        date: request.appointmentDate,
        time: request.appointmentTime,
        notes: request.composedNotes,
        serviceType: request.serviceType,
        visitLatitude: request.visitLatitude,
        visitLongitude: request.visitLongitude,
        visitAddress: request.visitAddress,
        locationNote: request.locationNote,
        symptoms: request.symptoms,
        isUrgent: request.isUrgent,
        urgencyLevel: request.isUrgent ? 'urgent' : 'routine',
        additionalNotes: request.additionalNotes,
        paymentMethod: request.paymentMethod,
        paymentStatus: request.paymentStatus,
      );

      final appointmentId = (booking['appointmentId'] ?? '').toString();
      if (appointmentId.isEmpty) {
        throw Exception('Booking created but booking id is missing');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            appointmentId: appointmentId,
            patientId: request.patientId,
            providerId: request.providerId,
            providerName: request.providerName,
            providerRole: request.providerRole,
            appointmentDate: request.appointmentDate,
            appointmentTime: request.appointmentTime,
            amount: request.totalAmount,
            serviceType: request.serviceType,
            location: request.visitAddress,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final r = widget.request;

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: AppBar(
        title: const CarelinkAppBarTitle('Review booking'),
        actions: carelinkAppBarActions(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const BookingStepIndicator(currentStep: BookingFlowStep.review),
          const SizedBox(height: 20),
          Text(
            r.providerName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: p.inkDark,
            ),
          ),
          Text(
            '${r.serviceType} · ${r.appointmentDate} · ${r.appointmentTime}',
            style: TextStyle(color: p.inkMuted),
          ),
          const SizedBox(height: 16),
          _section(
            p,
            'Current case',
            [
              if (r.patientReason.trim().isNotEmpty)
                _row('Reason', r.patientReason),
              if (r.symptoms.trim().isNotEmpty) _row('Symptoms', r.symptoms),
              _row('Urgency', r.isUrgent ? 'Urgent' : 'Routine'),
              if (r.visitAddress.trim().isNotEmpty)
                _row('Address', r.visitAddress),
            ],
          ),
          const SizedBox(height: 12),
          _section(
            p,
            'Price',
            [
              _row('Service', r.price.toStringAsFixed(2)),
              if (r.extraFees > 0)
                _row('Fees', r.extraFees.toStringAsFixed(2)),
              _row(
                'Total',
                r.totalAmount.toStringAsFixed(2),
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'You will choose cash, card, or wallet on the next step.',
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _isSubmitting ? null : _confirmBooking,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Continue to payment'),
          ),
        ),
      ),
    );
  }

  Widget _section(
    CarelinkPalette p,
    String title,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CarelinkPalette.of(context).inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: CarelinkPalette.of(context).inkDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

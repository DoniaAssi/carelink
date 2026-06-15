import 'package:flutter/material.dart';

import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/payment/payment_screen.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/features/patient/widgets/booking_provider_summary.dart';

class BookingReviewScreen extends StatefulWidget {
  final BookingRequestModel request;

  const BookingReviewScreen({super.key, required this.request});

  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _canConfirm {
    final r = widget.request;
    final hasBase =
        r.patientId.trim().isNotEmpty &&
        r.providerId.trim().isNotEmpty &&
        r.serviceType.trim().isNotEmpty &&
        r.appointmentDate.trim().isNotEmpty &&
        r.appointmentTime.trim().isNotEmpty &&
        r.patientReason.trim().isNotEmpty;
    if (!hasBase) return false;
    if (r.appointmentType == 'remote') return true;
    return r.visitAddress.trim().isNotEmpty;
  }

  Future<void> _confirmBooking() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final request = widget.request.copyWith(
        bookingStatus: 'pending_payment',
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
        appointmentType: request.appointmentType,
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
        status: request.bookingStatus,
      );

      final appointmentId = (booking['appointmentId'] ?? '').toString();
      if (appointmentId.isEmpty) {
        throw Exception('missing appointment id');
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
            servicePrice: request.price,
            discount: request.discount,
            isRemote: request.appointmentType == 'remote',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String errorText = e.toString().replaceAll('Exception: ', '');
      
      final has409 = errorText.contains('Status: 409');
      final technicalDetailsRegex = RegExp(r'\s*\(Status: \d+, URL: .*\)');
      errorText = errorText.replaceAll(technicalDetailsRegex, '').trim();

      if (has409) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.isArabic 
                  ? 'هذا الموعد لم يعد متاحاً، الرجاء اختيار وقت آخر.' 
                  : 'This appointment time is no longer available. Please select another time.',
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _errorMessage = errorText.isNotEmpty ? errorText : context.tr('booking.review.submitFailed');
      });
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
      appBar: PatientAppBar(title: context.tr('booking.review.title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const BookingStepIndicator(currentStep: BookingFlowStep.review),
          const SizedBox(height: 20),
          BookingProviderSummary(request: r),
          const SizedBox(height: 10),
          Text(
            '${_appointmentTypeLabel(r.appointmentType)} · ${r.appointmentDate} · ${r.appointmentTime}',
            style: TextStyle(color: p.inkMuted),
          ),
          const SizedBox(height: 16),
          _section(p, context.tr('booking.review.currentCase'), [
            if (r.patientReason.trim().isNotEmpty)
              _row(context.tr('booking.review.reason'), r.patientReason),
            if (r.symptoms.trim().isNotEmpty)
              _row(context.tr('booking.review.symptoms'), r.symptoms),
            _row(
              context.tr('booking.review.urgency'),
              r.isUrgent
                  ? context.tr('booking.review.urgent')
                  : context.tr('booking.review.routine'),
            ),
            if (r.visitAddress.trim().isNotEmpty)
              _row(context.tr('booking.review.address'), r.visitAddress),
          ]),
          const SizedBox(height: 12),
          _section(p, context.tr('booking.review.price'), [
            _row(
              context.tr('booking.review.service'),
              _serviceLabel(r.serviceType),
            ),
            _row(
              context.tr('booking.review.appointmentType'),
              _appointmentTypeLabel(r.appointmentType),
            ),
            _row(
              context.tr('booking.review.price'),
              '${r.price.toStringAsFixed(2)} ILS',
            ),
            if (r.discount > 0)
              _row(
                context.l10n.isArabic ? 'الخصم' : 'Discount',
                '-${r.discount.toStringAsFixed(2)} ILS',
              ),
            if (r.extraFees > 0)
              _row(
                context.tr('booking.review.fees'),
                '${r.extraFees.toStringAsFixed(2)} ILS',
              ),
            _row(
              context.tr('booking.review.total'),
              '${r.totalAmount.toStringAsFixed(2)} ILS',
              bold: true,
            ),
          ]),
          const SizedBox(height: 16),
          Text(
            context.tr('booking.review.nextPayment'),
            style: TextStyle(color: p.inkMuted, fontSize: 13.5, height: 1.35),
          ),
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: PatientPrimaryButton(
            onPressed: _isSubmitting || !_canConfirm ? null : _confirmBooking,
            isLoading: _isSubmitting,
            icon: _errorMessage != null ? Icons.refresh_rounded : Icons.lock_outline_rounded,
            label: _errorMessage != null 
                ? context.tr('booking.tryAgain') 
                : context.tr('booking.review.continuePayment'),
          ),
        ),
      ),
    );
  }

  Widget _section(CarelinkPalette p, String title, List<Widget> children) {
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
            style: TextStyle(fontWeight: FontWeight.w800, color: p.inkDark),
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
          Expanded(
            flex: 2,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CarelinkPalette.of(context).inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
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

  String _appointmentTypeLabel(String value) {
    return value == 'remote'
        ? context.tr('booking.remoteConsultation')
        : context.tr('booking.homeVisit');
  }

  String _serviceLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'home nursing care':
        return context.tr('booking.service.homeNursing');
      case 'general doctor':
      case 'doctor consultation':
        return context.tr('booking.service.generalDoctor');
      case 'post-surgery care':
      case 'post surgery care':
        return context.tr('booking.service.postSurgery');
      case 'elderly care':
        return context.tr('booking.service.elderlyCare');
      case 'physiotherapy':
        return context.tr('booking.service.physiotherapy');
      case 'mental support':
      case 'mental health':
        return context.tr('booking.service.mentalSupport');
      default:
        return value;
    }
  }
}

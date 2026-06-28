import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/payment/booking_payment_flow.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';

class BookingReviewScreen extends StatefulWidget {
  final BookingRequestModel request;

  const BookingReviewScreen({super.key, required this.request});

  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _reasonController.text = widget.request.patientReason;
    _reasonController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    final r = widget.request;
    final hasBase =
        r.patientId.trim().isNotEmpty &&
        r.providerId.trim().isNotEmpty &&
        r.serviceType.trim().isNotEmpty &&
        r.appointmentDate.trim().isNotEmpty &&
        r.appointmentTime.trim().isNotEmpty &&
        _reasonController.text.trim().isNotEmpty;
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
      final finalRequest = widget.request.copyWith(
        patientReason: _reasonController.text.trim(),
        bookingStatus: 'pending',
      );
      await BookingPaymentFlow.open(context: context, request: finalRequest);
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
        _errorMessage = context.l10n.userMessage(
          errorText.isEmpty ? Exception('') : Exception(errorText),
          fallbackKey: 'booking.review.submitFailed',
        );
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final r = widget.request;

    return PatientScaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(
        title: context.l10n.isArabic
            ? 'مراجعة الحجز'
            : context.tr('booking.review.title'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const BookingStepIndicator(currentStep: BookingFlowStep.review),
          const SizedBox(height: 20),
          if (r.isRebook) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.replay_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.isArabic
                          ? 'هذا حجز جديد مبني على حجز سابق.'
                          : 'This is a new booking based on a previous booking.',
                      style: TextStyle(
                        color: p.inkDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.stroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: p.isDark ? 0.22 : 0.045,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow(
                  context,
                  Icons.person_outline_rounded,
                  r.providerName,
                ),
                const SizedBox(height: 12),
                _summaryRow(
                  context,
                  Icons.medical_services_outlined,
                  _serviceLabel(r.serviceType),
                ),
                const SizedBox(height: 12),
                _summaryRow(
                  context,
                  Icons.calendar_today_rounded,
                  r.appointmentDate,
                ),
                const SizedBox(height: 12),
                _summaryRow(context, Icons.schedule_rounded, r.appointmentTime),
                if (r.visitAddress.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _summaryRow(
                    context,
                    Icons.location_on_outlined,
                    r.visitAddress,
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.isArabic ? 'المجموع' : 'Total',
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${r.totalAmount.toStringAsFixed(0)} ILS',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.stroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: p.isDark ? 0.22 : 0.045,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.isArabic ? 'تفاصيل الزيارة' : 'Visit Details',
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.isArabic ? 'سبب الزيارة' : 'Reason for visit',
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 200,
                  cursorColor: AppColors.primary,
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: context.l10n.isArabic
                        ? 'اكتب باختصار سبب طلب الموعد'
                        : 'Briefly describe why you need this appointment',
                    hintStyle: TextStyle(color: p.inkMuted, fontSize: 13),
                    filled: true,
                    fillColor: p.filterSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                if (r.locationNote.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.tr('booking.location.note'),
                    style: TextStyle(
                      color: p.inkDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: p.surfaceSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      r.locationNote,
                      style: TextStyle(
                        color: p.inkDark,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.stroke),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: p.inkMuted, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.isArabic
                        ? 'يمكنك إلغاء الطلب قبل موافقة مقدم الرعاية'
                        : 'You can cancel the request before provider approval',
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
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
            icon: _errorMessage != null
                ? Icons.refresh_rounded
                : Icons.lock_outline_rounded,
            label: _errorMessage != null
                ? context.tr('booking.tryAgain')
                : context.tr('booking.review.continuePayment'),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: CarelinkPalette.of(context).inkDark,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
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

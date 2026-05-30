import 'package:flutter/material.dart';

import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';
import 'package:carelink/features/ai/widgets/appointment_summary_card.dart';
import 'package:carelink/features/ai/screens/ai_booking_confirmed_screen.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/services/api_service.dart';

/// Review visit reason, fee, and confirm booking + payment state for the AI flow.
class AiAppointmentScreen extends StatefulWidget {
  const AiAppointmentScreen({
    super.key,
    required this.request,
    required this.aiResult,
    required this.displayDate,
    required this.displayTime,
  });

  final BookingRequestModel request;
  final AIRecommendationResult aiResult;
  final String displayDate;
  final String displayTime;

  @override
  State<AiAppointmentScreen> createState() => _AiAppointmentScreenState();
}

class _AiAppointmentScreenState extends State<AiAppointmentScreen> {
  bool _busy = false;
  final _api = ApiService();

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final r = widget.request;
      final booking = await _api.createBooking(
        patientId: r.patientId,
        providerId: r.providerId,
        date: r.appointmentDate,
        time: r.appointmentTime,
        notes: r.composedNotes,
        serviceType: r.serviceType,
        visitLatitude: r.visitLatitude,
        visitLongitude: r.visitLongitude,
        visitAddress: r.visitAddress,
        locationNote: r.locationNote,
        symptoms: r.symptoms,
        isUrgent: r.isUrgent,
        additionalNotes: r.additionalNotes,
        paymentMethod: 'visa_card',
        paymentStatus: 'unpaid',
      );
      final appointmentId = (booking['appointmentId'] ?? '').toString();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Booking created'),
          content: Text(
            appointmentId.isEmpty
                ? 'Booking stored locally for demo. Complete Visa checkout from your schedule when ready.'
                : 'Appointment $appointmentId created. Pay with Visa when you open the visit (demo test cards).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AiBookingConfirmedScreen(
            request: r,
            appointmentId: appointmentId.isEmpty ? 'demo_${DateTime.now().millisecondsSinceEpoch}' : appointmentId,
            displayDate: widget.displayDate,
            displayTime: widget.displayTime,
            patientUserId: r.patientId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Offline / server unavailable'),
          content: const Text(
            'Proceed with a local demo confirmation so your graduation flow stays usable without the API.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AiBookingConfirmedScreen(
                      request: widget.request,
                      appointmentId: id,
                      displayDate: widget.displayDate,
                      displayTime: widget.displayTime,
                      patientUserId: widget.request.patientId,
                    ),
                  ),
                );
              },
              child: const Text('Demo confirm'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final fee = r.totalAmount;

    return Scaffold(
      backgroundColor: AiFlowTheme.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AiFlowTheme.ink,
        title: const Text(
          'Appointment',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AiFlowTheme.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _busy ? null : _confirm,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirm & pay',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppointmentSummaryCard(
            provider: widget.aiResult.provider,
            dateLabel: widget.displayDate,
            timeLabel: widget.displayTime,
            reason: r.patientReason.trim().isEmpty
                ? 'General consultation'
                : r.patientReason.trim(),
            priceLabel: '\$${fee.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 14),
          const Text(
            'Payment details',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AiFlowTheme.cardStroke),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CareLink secure checkout (demo)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'We record a paid status for prototyping. Integrate your PSP in production.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AiFlowTheme.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

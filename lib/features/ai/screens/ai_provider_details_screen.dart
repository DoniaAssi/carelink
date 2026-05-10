import 'package:flutter/material.dart';

import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';
import 'package:carelink/features/ai/widgets/ai_score_breakdown.dart';
import 'package:carelink/features/ai/screens/ai_appointment_screen.dart';
import 'package:carelink/features/ai/ai_slot_utils.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';

/// Provider detail with explicit “why recommended” breakdown (thesis friendly).
class AiProviderDetailsScreen extends StatefulWidget {
  const AiProviderDetailsScreen({
    super.key,
    required this.result,
    this.patientUserId,
    this.distanceKm,
  });

  final AIRecommendationResult result;
  final String? patientUserId;
  final double? distanceKm;

  @override
  State<AiProviderDetailsScreen> createState() =>
      _AiProviderDetailsScreenState();
}

class _AiProviderDetailsScreenState extends State<AiProviderDetailsScreen> {
  AvailabilitySlot? _slot;
  final _reason = TextEditingController();

  ProviderModel get _p => widget.result.provider;

  @override
  void initState() {
    super.initState();
    final slots = AiSlotUtils.sortedSlots(_p.availableSlots);
    _slot = slots.isNotEmpty ? slots.first : null;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _continueBooking() {
    final id = widget.patientUserId?.trim() ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in as a patient to book.')),
      );
      return;
    }
    if (_slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available slots for this provider.')),
      );
      return;
    }

    final slotDate = AiSlotUtils.nextOccurrence(_slot!.day);
    final dateStr = slotDate.toIso8601String().split('T').first;
    final timeStr = _slot!.startTime;

    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AiAppointmentScreen(
          request: BookingRequestModel(
            patientId: id,
            providerId: _p.userId,
            providerName: _p.fullName,
            providerRole: _p.role,
            specialization: _p.specialization,
            serviceType: _p.serviceType.isNotEmpty
                ? _p.serviceType.split(',').first.trim()
                : 'Doctor consultation',
            appointmentDate: dateStr,
            appointmentTime: timeStr,
            visitLatitude: _p.gpsLat ?? 0,
            visitLongitude: _p.gpsLng ?? 0,
            visitAddress: '',
            locationNote: '',
            patientReason: _reason.text.trim(),
            symptoms: '',
            isUrgent: false,
            additionalNotes: '',
            price: _p.consultationFee ?? 65,
            paymentMethod: '',
            paymentStatus: 'unpaid',
            bookingStatus: 'pending',
          ),
          aiResult: widget.result,
          displayDate: AiSlotUtils.formatReadable(slotDate),
          displayTime: _slot!.formattedTime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = _p.role.toLowerCase() == 'doctor';
    final dist = widget.distanceKm;

    return Scaffold(
      backgroundColor: AiFlowTheme.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AiFlowTheme.ink,
        elevation: 0,
        title: const Text(
          'Provider details',
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
              onPressed: _continueBooking,
              child: const Text(
                'Continue / Book appointment',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  isDoctor
                      ? 'assets/images/doctorportrait.jpg'
                      : 'assets/images/nursemedical.jpg',
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _p.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AiFlowTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _p.specialization.isEmpty
                          ? _p.role
                          : _p.specialization,
                      style: const TextStyle(
                        color: AiFlowTheme.primaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF6B63C),
                        ),
                        Text(
                          _p.overallRating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (dist != null) ...[
                          const Text('  ·  ',
                              style: TextStyle(color: AiFlowTheme.inkMuted)),
                          Text(
                            dist < 1
                                ? '${(dist * 1000).round()} m away'
                                : '${dist.toStringAsFixed(1)} km away',
                            style: const TextStyle(
                              color: AiFlowTheme.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.result.matchPercentage}% AI match',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AiFlowTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'About',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _p.serviceType.isNotEmpty
                ? 'Services: ${_p.serviceType}. '
                    'Experienced ${_p.experienceYears ?? 0} years in community care.'
                : 'Community healthcare provider on CareLink.',
            style: const TextStyle(
              height: 1.4,
              color: AiFlowTheme.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Experience: ${_p.experienceYears ?? 0} years',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          const Text(
            'Available slots',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AiSlotUtils.sortedSlots(_p.availableSlots)
                .map(
                  (s) => ChoiceChip(
                    label: Text(
                      '${s.formattedDay} · ${s.formattedTime}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: _slot == s,
                    onSelected: (_) => setState(() => _slot = s),
                    selectedColor:
                        AiFlowTheme.primaryBlue.withValues(alpha: 0.18),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason for visit',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Why AI recommended this provider',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          AiScoreBreakdown(breakdown: widget.result.breakdown),
          const SizedBox(height: 12),
          ...widget.result.recommendationReasons
              .take(4)
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AiFlowTheme.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r,
                          style: const TextStyle(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

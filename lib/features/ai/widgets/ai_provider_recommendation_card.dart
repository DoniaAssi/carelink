import 'package:flutter/material.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/location_service.dart';

/// Ranked provider result card reused by the patient AI assistant flow.
class AiProviderRecommendationCard extends StatelessWidget {
  const AiProviderRecommendationCard({
    super.key,
    required this.result,
    required this.distanceKm,
    required this.onTap,
    this.availableHint,
    this.isArabic = false,
    this.rank,
  });

  final AIRecommendationResult result;
  final double? distanceKm;
  final VoidCallback onTap;
  final String? availableHint;
  final bool isArabic;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final p = result.provider;
    final isDoctor = p.role.toLowerCase() == 'doctor';
    final specialty = p.specialization.isEmpty ? p.role : p.specialization;
    final distLabel = _distanceLabel(distanceKm);
    final slotHint = availableHint ?? _slotHint(p);

    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    final cardBg = colorScheme.surface;
    final themeColor = colorScheme.onSurface;
    final helperColor = colorScheme.onSurfaceVariant;
    final strokeColor = colorScheme.outlineVariant;
    final primaryColor = colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: strokeColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      isDoctor
                          ? 'assets/images/doctorportrait.jpg'
                          : 'assets/images/nursemedical.jpg',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 64,
                          height: 64,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            isDoctor
                                ? Icons.person_rounded
                                : Icons.medical_services_rounded,
                            color: helperColor,
                            size: 32,
                          ),
                        );
                      },
                    ),
                  ),
                  if (rank != null)
                    Positioned(
                      top: -6,
                      left: isArabic ? null : -6,
                      right: isArabic ? -6 : null,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8922B),
                          shape: BoxShape.circle,
                          border: Border.all(color: cardBg, width: 1.5),
                        ),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            p.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: themeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // P2: Show Medical Match and Overall Match separately
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (result.medicalMatchScore != null) ...[
                              _matchPill(
                                context,
                                isArabic ? 'طبي' : 'Medical',
                                (result.medicalMatchScore! * 100).round().clamp(0, 99),
                                const Color(0xFF7C5CE7),
                              ),
                              const SizedBox(width: 4),
                            ],
                            _matchPill(
                              context,
                              isArabic ? 'إجمالي' : 'Overall',
                              result.matchPercentage,
                              const Color(0xFF2BB673),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: helperColor,
                        fontWeight: FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF2B036),
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          p.overallRating.toStringAsFixed(1),
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _fact(
                  Icons.event_available_rounded,
                  slotHint,
                  colorScheme,
                  helperColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _fact(
                  Icons.location_on_outlined,
                  distLabel,
                  colorScheme,
                  helperColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: onTap,
                    child: Text(
                      isArabic ? 'عرض التفاصيل' : 'View Details',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => _showWhyDialog(context, colorScheme, themeColor, helperColor),
                    child: Text(
                      isArabic ? 'لماذا هذا المزود؟' : 'Why This Provider?',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // P2: compact match percentage pill
  static Widget _matchPill(BuildContext context, String label, int percent, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percent%',
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
          ),
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w700, fontSize: 9),
          ),
        ],
      ),
    );
  }

  // P7: "Why This Provider?" dialog with score breakdown
  void _showWhyDialog(BuildContext context, ColorScheme colorScheme, Color themeColor, Color helperColor) {
    final bd = result.breakdown;
    final reasons = result.matchedTags.isNotEmpty
        ? result.matchedTags
        : result.recommendationReasons.take(4).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (ctx, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'لماذا هذا المزود؟' : 'Why This Provider?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: themeColor),
                ),
                const SizedBox(height: 4),
                Text(
                  isArabic
                      ? 'توضيح درجة التوافق لكل معيار'
                      : 'Score breakdown across every ranking criterion',
                  style: TextStyle(fontSize: 13, color: helperColor),
                ),
                // Matched tags / reasons
                if (reasons.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CE7).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF7C5CE7).withValues(alpha: 0.16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.medical_information_outlined, color: Color(0xFF7C5CE7), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              isArabic ? 'بناءً على سجلاتك الطبية' : 'Based on your medical records',
                              style: const TextStyle(color: Color(0xFF7C5CE7), fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: reasons.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C5CE7).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(tag, style: const TextStyle(color: Color(0xFF5A3FC0), fontSize: 11, fontWeight: FontWeight.w800)),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  isArabic ? 'تفصيل الدرجة' : 'Score Breakdown',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: themeColor),
                ),
                const SizedBox(height: 12),
                if (result.medicalMatchScore != null)
                  _scoreRow(ctx, isArabic ? 'التوافق الطبي' : 'Medical Match',
                      (result.medicalMatchScore! * 100).round(), const Color(0xFF7C5CE7), colorScheme),
                _scoreRow(ctx, isArabic ? 'التوافق الإجمالي' : 'Overall Match',
                    result.matchPercentage, const Color(0xFF2BB673), colorScheme),
                const Divider(height: 20),
                _scoreRow(ctx, isArabic ? 'التقييم' : 'Rating',
                    (bd.rating * 100).round(), colorScheme.primary, colorScheme),
                _scoreRow(ctx, isArabic ? 'الخبرة' : 'Experience',
                    (bd.experience * 100).round(), colorScheme.primary, colorScheme),
                _scoreRow(ctx, isArabic ? 'الموقع' : 'Location',
                    (bd.location * 100).round(), colorScheme.primary, colorScheme),
                _scoreRow(ctx, isArabic ? 'التوفر' : 'Availability',
                    (bd.availability * 100).round(), colorScheme.primary, colorScheme),
                _scoreRow(ctx, isArabic ? 'التخصص' : 'Specialization',
                    (bd.specialization * 100).round(), colorScheme.primary, colorScheme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scoreRow(BuildContext context, String label, int percent, Color color, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(color: colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text(
                '$percent%',
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: (percent / 100).clamp(0.0, 1.0),
              backgroundColor: colorScheme.outlineVariant,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(
    IconData icon,
    String text,
    ColorScheme colorScheme,
    Color helperColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: helperColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _distanceLabel(double? value) {
    if (value == null) return isArabic ? 'غير محدد' : 'Unavailable';
    if (value < 1) {
      final meters = (value * 1000).round();
      return isArabic ? '$meters م' : '$meters m';
    }
    final km = value.toStringAsFixed(1);
    return isArabic ? '$km كم' : '$km km';
  }

  String _slotHint(ProviderModel p) {
    if (p.availableSlots.isEmpty) {
      if (p.isAvailable) return isArabic ? 'متاح اليوم' : 'Open today';
      return isArabic ? 'مواعيد محدودة' : 'Limited slots';
    }
    final slot = p.availableSlots.first;
    return '${_day(slot.day)} ${_clock(slot.startTime)}';
  }

  String _day(String day) {
    if (!isArabic) return day.isEmpty ? 'Available' : day;
    const days = {
      'monday': 'الإثنين',
      'tuesday': 'الثلاثاء',
      'wednesday': 'الأربعاء',
      'thursday': 'الخميس',
      'friday': 'الجمعة',
      'saturday': 'السبت',
      'sunday': 'الأحد',
    };
    return days[day.trim().toLowerCase()] ?? 'متاح';
  }

  String _clock(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;
    final h = hour % 12 == 0 ? 12 : hour % 12;
    if (!isArabic) {
      final period = hour >= 12 ? 'PM' : 'AM';
      return '$h:${minute.toString().padLeft(2, '0')} $period';
    }
    final period = hour >= 12 ? 'م' : 'ص';
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }

  static double? distanceFrom(
    double? patientLat,
    double? patientLng,
    ProviderModel provider,
  ) {
    final m = LocationService().distanceInMeters(
      fromLat: patientLat,
      fromLng: patientLng,
      toLat: provider.gpsLat,
      toLng: provider.gpsLng,
    );
    if (m == null) return null;
    return m / 1000.0;
  }
}

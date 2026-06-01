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
                            isDoctor ? Icons.person_rounded : Icons.medical_services_rounded,
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2BB673).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${result.matchPercentage}% ${isArabic ? 'توافق' : 'match'}',
                            style: const TextStyle(
                              color: Color(0xFF259c60),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
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
              Expanded(child: _fact(Icons.event_available_rounded, slotHint, colorScheme, helperColor)),
              const SizedBox(width: 10),
              Expanded(child: _fact(Icons.location_on_outlined, distLabel, colorScheme, helperColor)),
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
                    onPressed: onTap,
                    child: Text(
                      isArabic ? 'لماذا هذا المقدم؟' : 'Why This Provider?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
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

  Widget _fact(IconData icon, String text, ColorScheme colorScheme, Color helperColor) {
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
    if (value == null) return isArabic ? 'غير محدد' : 'Unknown';
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

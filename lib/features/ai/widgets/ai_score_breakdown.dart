import 'package:flutter/material.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';

class AiScoreBreakdown extends StatelessWidget {
  const AiScoreBreakdown({
    super.key,
    required this.breakdown,
    this.isArabic = false,
  });

  final ScoreBreakdown breakdown;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColor = colorScheme.onSurface;
    final helperColor = colorScheme.onSurfaceVariant;
    final strokeColor = colorScheme.outlineVariant;
    final primaryColor = Colors.teal; // Primary teal fill as requested

    final rows = <_Row>[
      _Row(
        _label('location'),
        breakdown.location,
        Icons.location_on_outlined,
        _explanation('location', breakdown.location),
      ),
      _Row(
        _label('specialty'),
        breakdown.specialization,
        Icons.health_and_safety_outlined,
        _explanation('specialty', breakdown.specialization),
      ),
      _Row(
        _label('availability'),
        breakdown.availability,
        Icons.event_available_rounded,
        _explanation('availability', breakdown.availability),
      ),
      _Row(
        _label('experience'),
        breakdown.experience,
        Icons.workspace_premium_outlined,
        _explanation('experience', breakdown.experience),
      ),
      _Row(
        _label('rating'),
        breakdown.rating,
        Icons.star_rounded,
        _explanation('rating', breakdown.rating),
      ),
      _Row(
        _label('health'),
        breakdown.medicalCompatibility,
        Icons.medical_services_outlined,
        _explanation('health', breakdown.medicalCompatibility),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(r.icon, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: themeColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(r.value * 100).round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: r.value.clamp(0, 1),
                      backgroundColor: strokeColor,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: EdgeInsets.only(left: isArabic ? 0 : 28, right: isArabic ? 28 : 0),
                    child: Text(
                      r.explanation,
                      style: TextStyle(
                        fontSize: 12,
                        color: helperColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  String _label(String key) {
    if (!isArabic) {
      const en = {
        'location': 'Location',
        'specialty': 'Specialization',
        'availability': 'Availability',
        'experience': 'Experience',
        'rating': 'Rating',
        'health': 'Medical Compatibility',
      };
      return en[key] ?? key;
    }
    const ar = {
      'location': 'الموقع',
      'specialty': 'التخصص',
      'availability': 'التوفر',
      'experience': 'الخبرة',
      'rating': 'التقييم',
      'health': 'التوافق الطبي',
    };
    return ar[key] ?? key;
  }

  String _explanation(String key, double score) {
    if (!isArabic) {
      switch (key) {
        case 'location':
          return score >= 0.8
              ? 'Very close to your current location.'
              : 'Available within your service area.';
        case 'specialty':
          return score >= 0.8
              ? 'Exact match for your requested case type.'
              : 'Highly compatible healthcare specialty.';
        case 'availability':
          return score >= 0.8
              ? 'Has immediate or convenient upcoming slots.'
              : 'Available slots in the schedule.';
        case 'experience':
          return score >= 0.8
              ? 'Extensive years of clinical experience.'
              : 'Qualified specialist with proven track record.';
        case 'rating':
          return score >= 0.8
              ? 'Outstanding patient ratings and reviews.'
              : 'Well-rated by other patients.';
        case 'health':
          return score >= 0.8
              ? 'Perfect fit for your clinical profile and history.'
              : 'Compatible with your health requirements.';
        default:
          return '';
      }
    } else {
      switch (key) {
        case 'location':
          return score >= 0.8
              ? 'قريب جداً من موقعك الحالي.'
              : 'متاح في منطقة الخدمة الخاصة بك.';
        case 'specialty':
          return score >= 0.8
              ? 'تطابق تام مع نوع الرعاية المطلوبة.'
              : 'تخصص صحي متوافق بدرجة عالية.';
        case 'availability':
          return score >= 0.8
              ? 'لديه مواعيد قريبة ومناسبة جداً.'
              : 'تتوفر مواعيد مناسبة في الجدول.';
        case 'experience':
          return score >= 0.8
              ? 'سنوات طويلة من الخبرة العملية.'
              : 'أخصائي مؤهل ذو خبرة جيدة.';
        case 'rating':
          return score >= 0.8
              ? 'تقييمات وآراء ممتازة من المرضى.'
              : 'تقييم جيد من المرضى الآخرين.';
        case 'health':
          return score >= 0.8
              ? 'مناسب تماماً لملفك الطبي وتاريخك الصحي.'
              : 'متوافق مع متطلباتك الصحية.';
        default:
          return '';
      }
    }
  }
}

class _Row {
  _Row(this.label, this.value, this.icon, this.explanation);
  final String label;
  final double value;
  final IconData icon;
  final String explanation;
}

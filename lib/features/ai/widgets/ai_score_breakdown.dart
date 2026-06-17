import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
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
    final p = CarelinkPalette.of(context);

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
      children: rows
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.stroke.withValues(alpha: 0.8)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        r.value >= 0.5 ? Icons.check_rounded : r.icon,
                        size: 19,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: p.inkDark,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _matchLabel(r.value),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            r.explanation,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: p.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  String _label(String key) {
    if (!isArabic) {
      const en = {
        'location': 'Location Match',
        'specialty': 'Specialization Match',
        'availability': 'Availability Match',
        'experience': 'Experience Match',
        'rating': 'Patient Rating',
        'health': 'Medical Compatibility',
      };
      return en[key] ?? key;
    }
    const ar = {
      'location': 'توافق الموقع',
      'specialty': 'توافق التخصص',
      'availability': 'توافق المواعيد',
      'experience': 'توافق الخبرة',
      'rating': 'تقييم المرضى',
      'health': 'التوافق الطبي',
    };
    return ar[key] ?? key;
  }

  String _explanation(String key, double score) {
    if (!isArabic) {
      switch (key) {
        case 'location':
          if (score >= 0.8) return 'This provider is close to your location.';
          if (score >= 0.5) {
            return 'This provider serves your area but is not the closest option.';
          }
          return 'This provider may require a longer travel distance.';
        case 'specialty':
          if (score >= 0.8) {
            return 'Specializes in the type of care your condition needs.';
          }
          if (score >= 0.5) {
            return 'Has a related specialty suitable for your care request.';
          }
          return 'Can provide general support, but is not an exact specialty match.';
        case 'availability':
          if (score >= 0.8) {
            return 'Convenient appointment slots are available soon.';
          }
          if (score >= 0.4) {
            return 'Some appointment slots are available this week.';
          }
          return 'Appointment options are currently limited.';
        case 'experience':
          if (score >= 0.8) {
            return 'Highly experienced in this type of care.';
          }
          if (score >= 0.5) {
            return 'Has solid experience providing similar care.';
          }
          return 'Meets the basic experience requirements for this service.';
        case 'rating':
          if (score >= 0.8) return 'Highly rated by other patients.';
          if (score >= 0.5) return 'Receives positive patient feedback.';
          return 'Limited patient rating information is available.';
        case 'health':
          if (score >= 0.8) {
            return 'Strongly matches your health profile and care needs.';
          }
          if (score >= 0.5) {
            return 'Compatible with the main requirements of your condition.';
          }
          return 'Provides partial support for your medical requirements.';
        default:
          return '';
      }
    } else {
      switch (key) {
        case 'location':
          if (score >= 0.8) return 'مقدم الرعاية قريب من موقعك.';
          if (score >= 0.5) {
            return 'يخدم منطقتك، لكنه ليس الخيار الأقرب.';
          }
          return 'قد تحتاج إلى قطع مسافة أطول للوصول إليه.';
        case 'specialty':
          if (score >= 0.8) {
            return 'متخصص في نوع الرعاية التي تحتاجها حالتك.';
          }
          if (score >= 0.5) {
            return 'لديه تخصص قريب ومناسب لطلب الرعاية.';
          }
          return 'يمكنه تقديم رعاية عامة، لكنه ليس مطابقاً تماماً للتخصص.';
        case 'availability':
          if (score >= 0.8) return 'تتوفر مواعيد مناسبة قريباً.';
          if (score >= 0.4) {
            return 'تتوفر بعض المواعيد خلال هذا الأسبوع.';
          }
          return 'خيارات المواعيد محدودة حالياً.';
        case 'experience':
          if (score >= 0.8) {
            return 'يمتلك خبرة عالية في هذا النوع من الرعاية.';
          }
          if (score >= 0.5) {
            return 'لديه خبرة جيدة في تقديم رعاية مشابهة.';
          }
          return 'يستوفي متطلبات الخبرة الأساسية لهذه الخدمة.';
        case 'rating':
          if (score >= 0.8) return 'حاصل على تقييم مرتفع من المرضى.';
          if (score >= 0.5) return 'حصل على آراء إيجابية من المرضى.';
          return 'معلومات تقييم المرضى المتوفرة محدودة.';
        case 'health':
          if (score >= 0.8) {
            return 'متوافق بدرجة عالية مع ملفك الصحي واحتياجاتك.';
          }
          if (score >= 0.5) {
            return 'متوافق مع المتطلبات الأساسية لحالتك.';
          }
          return 'يوفر دعماً جزئياً لاحتياجاتك الطبية.';
        default:
          return '';
      }
    }
  }

  String _matchLabel(double score) {
    if (score >= 0.85) {
      return isArabic ? 'توافق ممتاز' : 'Excellent Match';
    }
    if (score >= 0.7) {
      return isArabic ? 'توافق جيد جداً' : 'Very Good Match';
    }
    if (score >= 0.5) {
      return isArabic ? 'توافق جيد' : 'Good Match';
    }
    return isArabic ? 'توافق متوسط' : 'Moderate Match';
  }
}

class _Row {
  _Row(this.label, this.value, this.icon, this.explanation);
  final String label;
  final double value;
  final IconData icon;
  final String explanation;
}

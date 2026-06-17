import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder;
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/location_service.dart';

class AiProviderRecommendationCard extends StatelessWidget {
  const AiProviderRecommendationCard({
    super.key,
    required this.result,
    required this.distanceKm,
    required this.onTap,
    this.isArabic = false,
    this.rank,
    this.highlighted = false,
  });

  final AIRecommendationResult result;
  final double? distanceKm;
  final VoidCallback onTap;
  final bool isArabic;
  final int? rank;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final provider = result.provider;
    final scheme = Theme.of(context).colorScheme;
    final displayName = _displayName(provider);
    final specialty = _displaySpecialty(provider);

    return PatientPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.55)
                : scheme.outlineVariant,
            width: highlighted ? 1.25 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(provider),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${result.matchPercentage}%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 13.5,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                specialty,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFB020),
                    size: 15,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    provider.overallRating.toStringAsFixed(1),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _price(provider),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        provider.isAvailable
                            ? (isArabic ? 'متاح' : 'Available')
                            : (isArabic ? 'مواعيد محدودة' : 'Limited'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: Semantics(
                      label: isArabic ? 'عرض التفاصيل' : 'View details',
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          isArabic
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(ProviderModel provider) {
    final isDoctor = provider.role.toLowerCase() == 'doctor';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.09),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.24),
          width: 1.25,
        ),
      ),
      child: ClipOval(
        child: profileAvatarOrPlaceholder(
          imageUrl: provider.profileImageUrl,
          size: 44,
          placeholderColor: AppColors.primary,
          placeholderIcon: isDoctor
              ? Icons.medical_services_outlined
              : Icons.local_hospital_outlined,
          iconSize: 21,
        ),
      ),
    );
  }

  String _price(ProviderModel provider) {
    final fee = provider.consultationFee;
    if (fee == null) return isArabic ? 'السعر لاحقاً' : 'Price later';
    return '${fee.toStringAsFixed(0)} ILS';
  }

  String _displayName(ProviderModel provider) {
    final name = provider.fullName.trim();
    if (_isInvalidDisplayValue(name)) {
      return isArabic ? 'مقدم رعاية' : 'Care Provider';
    }
    return name;
  }

  String _displaySpecialty(ProviderModel provider) {
    final specialization = provider.specialization.trim();
    if (!_isInvalidDisplayValue(specialization)) return specialization;

    final serviceType = provider.serviceType.trim();
    if (!_isInvalidDisplayValue(serviceType)) return serviceType;

    return isArabic ? 'مقدم رعاية عامة' : 'General Care Provider';
  }

  bool _isInvalidDisplayValue(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        const {
          'null',
          'unknown',
          'doctor',
          'nurse',
          'provider',
          'care provider',
          'carid',
          'careid',
          'n/a',
          '-',
        }.contains(normalized);
  }

  static double? distanceFrom(
    double? patientLat,
    double? patientLng,
    ProviderModel provider,
  ) {
    final meters = LocationService().distanceInMeters(
      fromLat: patientLat,
      fromLng: patientLng,
      toLat: provider.gpsLat,
      toLng: provider.gpsLng,
    );
    if (meters == null) return null;
    return meters / 1000;
  }
}

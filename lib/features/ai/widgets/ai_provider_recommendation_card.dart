import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
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
    final specialty = provider.specialization.trim().isNotEmpty
        ? provider.specialization.trim()
        : provider.serviceType.trim().isNotEmpty
        ? provider.serviceType.trim()
        : provider.role;
    final foreground = highlighted ? Colors.white : scheme.onSurface;
    final muted = highlighted
        ? Colors.white.withValues(alpha: 0.78)
        : scheme.onSurfaceVariant;
    final cardColor = highlighted ? AppColors.primary : scheme.surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlighted ? AppColors.primary : scheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: highlighted
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _avatar(context, provider, highlighted),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: highlighted
                            ? Colors.white.withValues(alpha: 0.16)
                            : AppColors.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${result.matchPercentage}%',
                        style: TextStyle(
                          color: highlighted ? Colors.white : AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  provider.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
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
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: highlighted ? Colors.white : AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      provider.overallRating.toStringAsFixed(1),
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _price(provider),
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: highlighted
                              ? Colors.white.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          provider.isAvailable
                              ? (isArabic ? 'متاح' : 'Available')
                              : (isArabic ? 'مواعيد محدودة' : 'Limited'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: highlighted
                                ? Colors.white
                                : AppColors.primary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        onPressed: onTap,
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: highlighted
                              ? Colors.white
                              : AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: highlighted
                              ? AppColors.primary
                              : AppColors.primary,
                        ),
                        icon: Icon(
                          isArabic
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          size: 17,
                        ),
                        tooltip: isArabic ? 'عرض التفاصيل' : 'View details',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(
    BuildContext context,
    ProviderModel provider,
    bool highlighted,
  ) {
    final isDoctor = provider.role.toLowerCase() == 'doctor';
    final fallback = isDoctor
        ? 'assets/images/doctorportrait.jpg'
        : 'assets/images/nursemedical.jpg';
    final imageUrl = provider.profileImageUrl?.trim() ?? '';

    Widget image;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      image = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(fallback, fit: BoxFit.cover),
      );
    } else {
      image = Image.asset(fallback, fit: BoxFit.cover);
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: highlighted
              ? Colors.white.withValues(alpha: 0.8)
              : AppColors.primary.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: ClipOval(child: image),
    );
  }

  String _price(ProviderModel provider) {
    final fee = provider.consultationFee;
    if (fee == null) return isArabic ? 'السعر لاحقاً' : 'Price later';
    return '\$${fee.toStringAsFixed(0)}';
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

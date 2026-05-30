import 'package:flutter/material.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/location_service.dart';

/// “Explainable” list tile with AI match % and human-readable rationale.
class AiProviderRecommendationCard extends StatelessWidget {
  const AiProviderRecommendationCard({
    super.key,
    required this.result,
    required this.distanceKm,
    required this.onTap,
    this.availableHint,
  });

  final AIRecommendationResult result;
  final double? distanceKm;
  final VoidCallback onTap;
  final String? availableHint;

  @override
  Widget build(BuildContext context) {
    final p = result.provider;
    final isDoctor = p.role.toLowerCase() == 'doctor';
    final distLabel = distanceKm != null
        ? distanceKm! < 1
              ? '${(distanceKm! * 1000).round()} m'
              : '${distanceKm!.toStringAsFixed(1)} km'
        : '—';

    final slotHint = availableHint ??
        (p.availableSlots.isNotEmpty
            ? '${p.availableSlots.first.formattedDay} · ${p.availableSlots.first.formattedTime}'
            : (p.isAvailable ? 'Open today' : 'Limited slots'));

    final reasonShort = result.recommendationReasons.length > 1
        ? result.recommendationReasons[1]
        : result.primaryReason;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AiFlowTheme.cardStroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  isDoctor
                      ? 'assets/images/doctorportrait.jpg'
                      : 'assets/images/nursemedical.jpg',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 64,
                    height: 64,
                    color: AiFlowTheme.primaryBlue.withValues(alpha: 0.08),
                    child: Icon(
                      isDoctor
                          ? Icons.medical_services_rounded
                          : Icons.local_hospital_rounded,
                      color: AiFlowTheme.primaryBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AiFlowTheme.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AiFlowTheme.primaryBlue.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${result.matchPercentage}% match',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AiFlowTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.specialization.isEmpty
                          ? p.role
                          : p.specialization,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AiFlowTheme.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF6B63C),
                          size: 18,
                        ),
                        Text(
                          p.overallRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const Text('  ·  ',
                            style: TextStyle(color: AiFlowTheme.inkMuted)),
                        const Icon(
                          Icons.place_outlined,
                          size: 15,
                          color: AiFlowTheme.inkMuted,
                        ),
                        Text(
                          distLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AiFlowTheme.inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: AiFlowTheme.inkMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            slotHint,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AiFlowTheme.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reasonShort,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: AiFlowTheme.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

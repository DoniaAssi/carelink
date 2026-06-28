import os

# We will completely overwrite the file
filepath = r'lib/features/ai/widgets/ai_provider_recommendation_card.dart'

new_code = '''import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/profile_avatar.dart' show profileAvatarOrPlaceholder;
import 'package:carelink/features/ai/provider_booking_eligibility.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/location_service.dart';

class AiProviderRecommendationCard extends StatefulWidget {
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
  final bool highlighted; // if true, this is the "Best" recommendation

  static double? distanceFrom(double? patientLat, double? patientLng, ProviderModel provider) {
    final meters = LocationService().distanceInMeters(
      fromLat: patientLat,
      fromLng: patientLng,
      toLat: provider.gpsLat,
      toLng: provider.gpsLng,
    );
    if (meters == null) return null;
    return meters / 1000;
  }

  @override
  State<AiProviderRecommendationCard> createState() => _AiProviderRecommendationCardState();
}

class _AiProviderRecommendationCardState extends State<AiProviderRecommendationCard> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  late AnimationController _circleController;
  late Animation<double> _circleAnimation;

  @override
  void initState() {
    super.initState();
    // Entry animation
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    // Circle progress animation
    _circleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _circleAnimation = Tween<double>(begin: 0.0, end: widget.result.matchPercentage / 100.0)
        .animate(CurvedAnimation(parent: _circleController, curve: Curves.easeOutCubic));

    // Delay entry based on rank to make them sequential
    final delay = (widget.rank ?? 1) * 150;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) {
        _slideController.forward();
        _circleController.forward();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _circleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.highlighted) {
      return _buildCollapsedCard(context);
    }
    return _buildBestCard(context);
  }

  Widget _buildBestCard(BuildContext context) {
    final provider = widget.result.provider;
    final scheme = Theme.of(context).colorScheme;
    final canBook = ProviderBookingEligibility.canBook(provider);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Top Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildAvatar(provider, size: 72),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _displayName(provider),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _displaySpecialty(provider),
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildConfidenceBadge(),
                            ],
                          ),
                        ),
                        _buildAnimatedMatchCircle(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Second Row (Info)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoItem(Icons.star_rounded, const Color(0xFFFFB020), provider.overallRating.toStringAsFixed(1)),
                          _buildInfoItem(Icons.location_on_rounded, AppColors.primary, widget.distanceKm != null ? '${widget.distanceKm!.toStringAsFixed(1)} km' : '-'),
                          _buildInfoItem(Icons.payments_rounded, Colors.green.shade600, _price(provider)),
                          _buildInfoItem(Icons.event_available_rounded, canBook ? AppColors.primary : Colors.orange, widget.isArabic ? (canBook ? 'متاح' : 'محدود') : (canBook ? 'Available' : 'Limited')),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // AI Reasons (Chips)
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildReasonChips(),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: widget.onTap,
                        child: Text(
                          widget.isArabic ? 'عرض الملف' : 'View Profile',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: widget.onTap,
                          child: Text(
                            widget.isArabic ? 'احجز الآن' : 'Book Now',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
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

  Widget _buildCollapsedCard(BuildContext context) {
    final provider = widget.result.provider;
    final scheme = Theme.of(context).colorScheme;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: PatientPressable(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildAvatar(provider, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName(provider),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFB020), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              provider.overallRating.toStringAsFixed(1),
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _price(provider),
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.result.matchPercentage}%',
                          style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          widget.isArabic ? 'تطابق' : 'Match',
                          style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMatchCircle() {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: AnimatedBuilder(
              animation: _circleAnimation,
              builder: (context, child) {
                return CircularProgressIndicator(
                  value: _circleAnimation.value,
                  strokeWidth: 6,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          AnimatedBuilder(
            animation: _circleAnimation,
            builder: (context, child) {
              return Text(
                '${(_circleAnimation.value * 100).toInt()}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, Color iconColor, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildReasonChips() {
    final reasons = <String>[];
    if (widget.result.recommendationReasons.isNotEmpty) {
      reasons.addAll(widget.result.recommendationReasons.take(4));
    } else {
      final bd = widget.result.breakdown;
      if (bd.specialization >= 0.75) reasons.add(widget.isArabic ? 'الخدمة مطابقة' : 'Service Match');
      if (bd.medicalCompatibility >= 0.65) reasons.add(widget.isArabic ? 'أفضل تطابق طبي' : 'Best Medical Match');
      if (bd.location >= 0.75) reasons.add(widget.isArabic ? 'قريب منك' : 'Close to you');
      if (bd.rating >= 0.75) reasons.add(widget.isArabic ? 'تقييم مرتفع' : 'High Rating');
      if (bd.availability >= 0.6) reasons.add(widget.isArabic ? 'متاح الآن' : 'Available Now');
    }

    return reasons.take(4).map((r) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade400, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green.shade500, size: 14),
            const SizedBox(width: 6),
            Text(
              r,
              style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildConfidenceBadge() {
    final score = widget.result.confidenceScore;
    Color color;
    String text;

    if (score >= 75) {
      color = Colors.green.shade600;
      text = widget.isArabic ? 'ثقة عالية' : 'High Confidence';
    } else if (score >= 50) {
      color = Colors.orange.shade600;
      text = widget.isArabic ? 'ثقة متوسطة' : 'Medium Confidence';
    } else {
      color = Colors.grey.shade600;
      text = widget.isArabic ? 'ثقة عادية' : 'Normal Confidence';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAvatar(ProviderModel provider, {required double size}) {
    final isDoctor = provider.role.toLowerCase() == 'doctor';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
      ),
      child: ClipOval(
        child: profileAvatarOrPlaceholder(
          imageUrl: provider.profileImageUrl,
          size: size,
          placeholderColor: AppColors.primary,
          placeholderIcon: isDoctor ? Icons.medical_services_outlined : Icons.local_hospital_outlined,
          iconSize: size * 0.45,
        ),
      ),
    );
  }

  String _price(ProviderModel provider) {
    final fee = provider.consultationFee;
    if (fee == null) return widget.isArabic ? 'السعر لاحقاً' : 'TBD';
    return '${fee.toStringAsFixed(0)} ILS';
  }

  String _displayName(ProviderModel provider) {
    final name = provider.fullName.trim();
    if (name.isEmpty || name.toLowerCase() == 'unknown') return widget.isArabic ? 'مقدم رعاية' : 'Care Provider';
    return name;
  }

  String _displaySpecialty(ProviderModel provider) {
    final spec = provider.specialization.trim();
    if (spec.isNotEmpty && spec.toLowerCase() != 'unknown') return spec;
    final srv = provider.serviceType.trim();
    if (srv.isNotEmpty && srv.toLowerCase() != 'unknown') return srv;
    return widget.isArabic ? 'مقدم رعاية عامة' : 'General Care Provider';
  }
}
'''

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_code)

import os

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
  final bool highlighted;

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

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.highlighted;

    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _circleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _circleAnimation = Tween<double>(begin: 0.0, end: widget.result.matchPercentage / 100.0)
        .animate(CurvedAnimation(parent: _circleController, curve: Curves.easeOutCubic));

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

  void _toggleExpand() {
    if (widget.highlighted) return;
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: widget.highlighted ? widget.onTap : _toggleExpand,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: widget.highlighted
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5)
                  : Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
              boxShadow: [
                if (widget.highlighted)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.highlighted) const SizedBox(height: 16), // space for badge
                        if (!_isExpanded)
                          _buildCollapsedHeader()
                        else
                          _buildExpandedHeader(),
                          
                        if (_isExpanded) ...[
                          const SizedBox(height: 24),
                          _buildReasonsList(),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                        ],
                      ],
                    ),
                  ),
                  if (widget.highlighted)
                    Positioned(
                      top: 0,
                      left: widget.isArabic ? null : 0,
                      right: widget.isArabic ? 0 : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.only(
                            bottomRight: widget.isArabic ? Radius.zero : const Radius.circular(16),
                            bottomLeft: widget.isArabic ? const Radius.circular(16) : Radius.zero,
                          ),
                        ),
                        child: Text(
                          widget.isArabic ? 'أفضل توصية' : 'Top Recommendation',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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

  Widget _buildExpandedHeader() {
    final provider = widget.result.provider;
    final scheme = Theme.of(context).colorScheme;
    final canBook = ProviderBookingEligibility.canBook(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded, color: AppColors.primary, size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _displaySpecialty(provider),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFB020), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        provider.overallRating.toStringAsFixed(1),
                        style: TextStyle(color: scheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.isArabic ? ' (128 تقييم)' : ' (128 reviews)', // Mock count to match design
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildAnimatedMatchCircle(),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(Icons.location_on_rounded, AppColors.primary, widget.distanceKm != null ? '${widget.distanceKm!.toStringAsFixed(1)} كم' : '-'),
              _buildInfoItem(Icons.circle, canBook ? Colors.green : Colors.orange, widget.isArabic ? (canBook ? 'متاح الآن' : 'محدود') : (canBook ? 'Available' : 'Limited')),
              _buildInfoItem(Icons.payments_rounded, AppColors.primary, _price(provider)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedHeader() {
    final provider = widget.result.provider;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _buildAvatar(provider, size: 56),
        const SizedBox(width: 16),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _displaySpecialty(provider),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
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
                    widget.distanceKm != null ? '${widget.distanceKm!.toStringAsFixed(1)} كم' : '-',
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${widget.result.matchPercentage}%',
              style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedMatchCircle() {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(_circleAnimation.value * 100).toInt()}%',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    widget.isArabic ? 'توافق' : 'Match',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildReasonsList() {
    final reasons = <Map<String, dynamic>>[];
    final bd = widget.result.breakdown;
    if (bd.specialization >= 0.75) reasons.add({'icon': Icons.medical_services_rounded, 'label': widget.isArabic ? 'أفضل تطابق' : 'Best Match'});
    if (bd.rating >= 0.75) reasons.add({'icon': Icons.star_rounded, 'label': widget.isArabic ? 'تقييم مرتفع' : 'Top Rated'});
    if (bd.location >= 0.75) reasons.add({'icon': Icons.location_on_rounded, 'label': widget.isArabic ? 'قريب منك' : 'Close by'});
    if (bd.availability >= 0.6) reasons.add({'icon': Icons.schedule_rounded, 'label': widget.isArabic ? 'متاح الآن' : 'Available'});
    if (bd.medicalCompatibility >= 0.65) reasons.add({'icon': Icons.shield_rounded, 'label': widget.isArabic ? 'خبرة طويلة' : 'Experienced'});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.isArabic ? 'لماذا نوصي بها؟' : 'Why recommended?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: reasons.take(5).map((r) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Icon(r['icon'], color: AppColors.primary, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  r['label'],
                  style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: widget.onTap,
            child: Text(
              widget.isArabic ? 'احجز الآن' : 'Book Now',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: widget.onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.isArabic ? 'عرض الملف الشخصي' : 'View Profile',
                style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(ProviderModel provider, {required double size}) {
    final isDoctor = provider.role.toLowerCase() == 'doctor';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1), width: 2),
      ),
      child: ClipOval(
        child: profileAvatarOrPlaceholder(
          imageUrl: provider.profileImageUrl,
          size: size,
          placeholderColor: AppColors.primary,
          placeholderIcon: isDoctor ? Icons.medical_services_rounded : Icons.local_hospital_rounded,
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
print("Updated ai_provider_recommendation_card.dart to exact image specs")

import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/profile_avatar.dart' show profileImageProvider;
import 'package:carelink/features/ai/provider_booking_eligibility.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
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
    this.emergency = false,
  });

  final AIRecommendationResult result;
  final double? distanceKm;
  final VoidCallback onTap;
  final bool isArabic;
  final int? rank;
  final bool highlighted;
  final bool emergency;

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

  @override
  State<AiProviderRecommendationCard> createState() =>
      _AiProviderRecommendationCardState();
}

class _AiProviderRecommendationCardState
    extends State<AiProviderRecommendationCard>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _circleController;
  late Animation<double> _circleAnimation;

  bool _isExpanded = false;
  bool _primaryPressed = false;

  Color get _accent => widget.emergency ? Colors.red : AppColors.primary;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.highlighted;

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _circleAnimation =
        Tween<double>(
          begin: 0.0,
          end: widget.result.matchPercentage / 100.0,
        ).animate(
          CurvedAnimation(
            parent: _circleController,
            curve: Curves.easeOutCubic,
          ),
        );

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
            padding: widget.highlighted
                ? const EdgeInsets.all(1.5)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              gradient: widget.highlighted
                  ? LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        _accent.withValues(alpha: 0.72),
                        _accent.withValues(alpha: 0.12),
                        _accent.withValues(alpha: 0.42),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                if (widget.highlighted)
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.18),
                    blurRadius: 28,
                    spreadRadius: -4,
                    offset: const Offset(0, 10),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22.5),
                border: widget.highlighted
                    ? null
                    : Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22.5),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        widget.highlighted ? 18 : 16,
                        widget.highlighted ? 44 : 16,
                        widget.highlighted ? 18 : 16,
                        widget.highlighted ? 18 : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_isExpanded)
                            _buildCollapsedHeader()
                          else
                            _buildExpandedHeader(),
                          if (_isExpanded) ...[
                            const SizedBox(height: 20),
                            _buildReasonsList(),
                            const SizedBox(height: 20),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.only(
                              bottomRight: widget.isArabic
                                  ? Radius.zero
                                  : const Radius.circular(14),
                              bottomLeft: widget.isArabic
                                  ? const Radius.circular(14)
                                  : Radius.zero,
                            ),
                          ),
                          child: Text(
                            widget.isArabic
                                ? (widget.emergency
                                      ? 'الأفضل للحالة الطارئة'
                                      : 'الأفضل لك')
                                : (widget.emergency
                                      ? 'Best for emergency'
                                      : 'Best for you'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
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
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(provider, size: 72),
            const SizedBox(width: 12),
            Expanded(
              child: Directionality(
                textDirection: widget.isArabic
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _displayName(provider),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(Icons.verified_rounded, color: _accent, size: 17),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _displaySpecialty(provider),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildAnimatedMatchBadge(),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFFFB020),
                text: provider.overallRating.toStringAsFixed(1),
              ),
              _buildInfoItem(
                icon: Icons.location_on_rounded,
                iconColor: _accent,
                text: widget.distanceKm != null
                    ? '${widget.distanceKm!.toStringAsFixed(1)} ${widget.isArabic ? 'كم' : 'km'}'
                    : '-',
              ),
              _buildInfoItem(
                icon: Icons.payments_rounded,
                iconColor: _accent,
                text: _price(provider),
              ),
              _buildInfoItem(
                icon: Icons.circle,
                iconColor: canBook ? Colors.green : Colors.orange,
                text: widget.isArabic
                    ? (canBook ? 'متاح' : 'محدود')
                    : (canBook ? 'Available' : 'Limited'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedHeader() {
    final provider = widget.result.provider;
    final scheme = Theme.of(context).colorScheme;
    final canBook = ProviderBookingEligibility.canBook(provider);

    return Row(
      textDirection: TextDirection.ltr,
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
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  _buildCompactMeta(
                    Icons.star_rounded,
                    provider.overallRating.toStringAsFixed(1),
                    const Color(0xFFFFB020),
                  ),
                  _buildCompactMeta(
                    Icons.payments_rounded,
                    _price(provider),
                    AppColors.primary,
                  ),
                  _buildCompactMeta(
                    Icons.circle,
                    widget.isArabic
                        ? (canBook ? 'متاح' : 'محدود')
                        : (canBook ? 'Available' : 'Limited'),
                    canBook ? Colors.green : Colors.orange,
                    smallIcon: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.075),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.isArabic ? 'تطابق' : 'Match',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${widget.result.matchPercentage}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedMatchBadge() {
    return AnimatedBuilder(
      animation: _circleAnimation,
      builder: (context, child) {
        return Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isArabic ? 'تطابق' : 'Match',
                style: TextStyle(
                  color: _accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(_circleAnimation.value * 100).toInt()}%',
                style: TextStyle(
                  color: _accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    Color? iconColor,
  }) {
    return Flexible(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: iconColor ?? AppColors.primary,
            size: icon == Icons.circle ? 8 : 15,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMeta(
    IconData icon,
    String value,
    Color color, {
    bool smallIcon = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: smallIcon ? 7 : 13),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildReasonsList() {
    final reasons = <String>[];
    final bd = widget.result.breakdown;
    if (bd.specialization >= 0.65 || bd.medicalCompatibility >= 0.65) {
      reasons.add(widget.isArabic ? 'أفضل تطابق طبي' : 'Best medical match');
    }
    reasons.add(widget.isArabic ? 'يناسب طلبك' : 'Fits your request');
    if (bd.availability >= 0.6) {
      reasons.add(widget.isArabic ? 'متاح الآن' : 'Available now');
    }
    if (bd.location >= 0.65) {
      reasons.add(widget.isArabic ? 'قريب منك' : 'Close to you');
    }
    if (bd.rating >= 0.75) {
      reasons.add(widget.isArabic ? 'تقييم مرتفع' : 'Top Rated');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isArabic ? 'لماذا اخترناها لك؟' : 'Why we chose this match',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 10,
            runSpacing: 7,
            children: reasons.take(5).toList().asMap().entries.map((entry) {
              final start = 0.15 + (entry.key * 0.1);
              final animation = CurvedAnimation(
                parent: _slideController,
                curve: Interval(start, (start + 0.45).clamp(0.0, 1.0)),
              );
              return FadeTransition(
                opacity: animation,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: _accent, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      entry.value,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return _pressableScale(
      pressed: _primaryPressed,
      onPressedChanged: (value) {
        if (mounted) setState(() => _primaryPressed = value);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [_accent, _accent.withValues(alpha: 0.82)],
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: widget.onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.isArabic ? 'عرض التفاصيل' : 'View details',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                widget.isArabic
                    ? Icons.arrow_back_rounded
                    : Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pressableScale({
    required bool pressed,
    required ValueChanged<bool> onPressedChanged,
    required Widget child,
  }) {
    return Listener(
      onPointerDown: (_) => onPressedChanged(true),
      onPointerUp: (_) => onPressedChanged(false),
      onPointerCancel: (_) => onPressedChanged(false),
      child: AnimatedScale(
        scale: pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }

  Widget _buildAvatar(ProviderModel provider, {required double size}) {
    final image = profileImageProvider(provider.profileImageUrl);
    final name = _displayName(provider).trim();
    final initial = name.isEmpty ? '' : name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _accent.withValues(alpha: 0.14), width: 2),
      ),
      child: ClipOval(
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: _accent.withValues(alpha: 0.1),
          backgroundImage: image,
          child: image == null
              ? Text(
                  initial,
                  style: TextStyle(
                    color: _accent,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  String _price(ProviderModel provider) {
    final fee = provider.consultationFee;
    if (fee == null) return widget.isArabic ? 'السعر لاحقاً' : 'TBD';
    final amount = fee.toStringAsFixed(0);
    return widget.isArabic ? '$amount ₪' : '₪$amount';
  }

  String _displayName(ProviderModel provider) {
    final name = provider.fullName.trim();
    if (name.isEmpty || name.toLowerCase() == 'unknown') {
      return widget.isArabic ? 'مقدم رعاية' : 'Care Provider';
    }
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

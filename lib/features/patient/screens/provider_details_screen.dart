import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/models/provider_profile.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/services/favorite_providers_service.dart';
import 'package:carelink/shared/services/location_service.dart';
import 'package:carelink/shared/services/provider_profile_service.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'select_service_screen.dart';

class ProviderDetailsScreen extends StatefulWidget {
  final ProviderModel provider;
  final String? patientUserId;

  /// Precomputed distance in km (e.g. from providers list). When null, the
  /// screen may try to resolve distance from device GPS once.
  final double? distanceKm;

  const ProviderDetailsScreen({
    super.key,
    required this.provider,
    this.patientUserId,
    this.distanceKm,
  });

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  static const double _kCardRadius = 20.0;
  static const double _kMinInfoCardContentHeight = 0.0;

  late ProviderModel _provider;
  ProviderProfile? _providerProfile;
  bool _isLoadingDetails = false;
  int? _selectedTimeIndex;
  String _distanceLine = '';
  bool _isResolvingDistance = false;
  bool _isFavorite = false;
  int _selectedQuickAction = 0;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _syncSelection(_provider.availableSlots);
    if (widget.distanceKm != null && widget.distanceKm! >= 0) {
      _distanceLine = '${widget.distanceKm!.toStringAsFixed(1)} km';
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeResolveDistance();
      });
    }
    _loadProviderDetails();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    try {
      final on = await FavoriteProvidersService.isFavorite(
        widget.patientUserId,
        _provider.userId,
      );
      if (!mounted) return;
      setState(() => _isFavorite = on);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    try {
      final nowFavorite = await FavoriteProvidersService.toggle(
        widget.patientUserId,
        _provider.userId,
      );
      if (!mounted) return;
      setState(() => _isFavorite = nowFavorite);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nowFavorite ? 'Added to favorites' : 'Removed from favorites',
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {}
  }

  Future<void> _loadProviderDetails() async {
    setState(() => _isLoadingDetails = true);

    try {
      final data = await ApiService().getProviderById(widget.provider.userId);
      final providerId = int.tryParse(widget.provider.userId);
      final profile = providerId == null
          ? null
          : await ProviderProfileService.getProfileLegacy(providerId);
      if (!mounted) return;

      final updatedProvider = ProviderModel.fromJson(data);
      setState(() {
        _provider = updatedProvider;
        _providerProfile = profile;
        _syncSelection(updatedProvider.availableSlots);
      });
      _maybeResolveDistance();
      _loadFavoriteState();
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  Future<void> _maybeResolveDistance() async {
    if (widget.distanceKm != null) return;
    if (_provider.gpsLat == null || _provider.gpsLng == null) return;
    if (_isResolvingDistance) return;
    setState(() => _isResolvingDistance = true);
    try {
      final pos = await LocationService().getCurrentPosition();
      final meters = LocationService().distanceInMeters(
        fromLat: pos.latitude,
        fromLng: pos.longitude,
        toLat: _provider.gpsLat,
        toLng: _provider.gpsLng,
      );
      if (!mounted || meters == null) return;
      setState(
        () => _distanceLine = '${(meters / 1000).toStringAsFixed(1)} km',
      );
    } catch (_) {
      if (mounted) setState(() => _distanceLine = '');
    } finally {
      if (mounted) setState(() => _isResolvingDistance = false);
    }
  }

  void _syncSelection(List<AvailabilitySlot> slots) {
    final ordered = _sortedSlots(slots);
    if (ordered.isEmpty) {
      _selectedTimeIndex = null;
      return;
    }

    _selectedTimeIndex = slots.indexOf(ordered.first);
  }

  List<AvailabilitySlot> _sortedSlots(List<AvailabilitySlot> slots) {
    final sorted = List<AvailabilitySlot>.from(slots);
    sorted.sort((a, b) {
      final dayCompare = _nextMatchingDate(
        a.day,
      ).compareTo(_nextMatchingDate(b.day));
      if (dayCompare != 0) return dayCompare;
      return a.startTime.compareTo(b.startTime);
    });
    return sorted;
  }

  List<String> _availableDays(List<AvailabilitySlot> slots) {
    final ordered = _sortedSlots(slots);
    final days = <String>[];
    for (final slot in ordered) {
      if (!days.contains(slot.day)) {
        days.add(slot.day);
      }
    }
    return days;
  }

  DateTime _nextMatchingDate(String slotDay) {
    final weekdayMap = <String, int>{
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    final targetWeekday = weekdayMap[slotDay.toLowerCase()];
    var candidate = DateTime.now();
    candidate = DateTime(candidate.year, candidate.month, candidate.day);

    if (targetWeekday == null) return candidate;

    for (var i = 0; i < 14; i++) {
      if (candidate.weekday == targetWeekday) return candidate;
      candidate = candidate.add(const Duration(days: 1));
    }

    return candidate;
  }

  String _headerSpecialization() {
    final spec = _safeText(_provider.specialization);
    if (spec.isNotEmpty) return spec;
    final st = _safeText(_provider.serviceType);
    if (st.isNotEmpty) {
      final first = st
          .split(',')
          .map((e) => e.trim())
          .firstWhere((e) => e.isNotEmpty, orElse: () => '');
      if (first.isNotEmpty) return first;
    }
    final role = _safeText(_provider.role).toLowerCase();
    if (role == 'doctor') return 'Medical care';
    if (role == 'nurse') return 'Nursing care';
    return 'Care services';
  }

  String? get _aboutText {
    final profileBio = _safeText(_providerProfile?.bio);
    if (profileBio.isNotEmpty) return profileBio;
    final shortBio = _safeText(_provider.serviceType);
    if (shortBio.isNotEmpty) return shortBio;
    return null;
  }

  String get _displayRating {
    if (_provider.overallRating <= 0) return 'Not available';
    return _provider.overallRating.toStringAsFixed(1);
  }

  String get _displayDistance {
    if (_isResolvingDistance) return '…';
    final t = _distanceLine.trim();
    if (t.isNotEmpty) return t;
    return 'Not available';
  }

  String get _displayAvailabilityMain {
    final hasDays = _availableDays(_provider.availableSlots).isNotEmpty;
    if (!hasDays) return 'Not available';
    return _provider.isAvailable ? 'Available' : 'Away';
  }

  String get _displayAvailabilitySub {
    final days = _availableDays(_provider.availableSlots).length;
    if (days <= 0) return '';
    return '$days days / wk';
  }

  String _roleTitle() {
    final r = _safeText(_provider.role).toLowerCase();
    if (r == 'nurse') return 'Nurse Specialist';
    if (r == 'doctor') return 'Physician';
    if (r == 'admin') return 'Care Administrator';
    return 'Care Professional';
  }

  String? get _serviceFocusLine {
    final raw = _safeText(_provider.serviceType);
    if (raw.isNotEmpty) {
      final first = raw
          .split(',')
          .map((e) => e.trim())
          .firstWhere((e) => e.isNotEmpty, orElse: () => '');
      if (first.isNotEmpty) return first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const bottomBarHeight = 88.0;
    return Scaffold(
      backgroundColor: p.pageBg,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          color: p.pageBg,
          elevation: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8 + bottomInset.clamp(0, 18),
            ),
            decoration: BoxDecoration(
              color: p.pageBg,
              border: Border(
                top: BorderSide(color: p.stroke.withValues(alpha: 0.7)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: _buildBottomBar(),
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildReferenceHeroAndActions(context)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatsRow(),
                if (_aboutText != null) ...[
                  const SizedBox(height: 12),
                  _buildAboutSection(),
                ],
                const SizedBox(height: 12),
                _buildServicesSectionReference(),
                const SizedBox(height: 12),
                _buildAvailableTodaySection(),
                const SizedBox(height: 12),
                _buildFeeSectionReference(),
                if (_isLoadingDetails) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    color: AppColors.primary,
                    backgroundColor: p.surfaceSoft,
                  ),
                ],
                SizedBox(height: bottomBarHeight + bottomInset),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// High-fidelity reference: page background, centered logo, round actions,
  /// then a floating profile card (ECG motif, role title in teal, CareLink
  /// badge, **teal** selected quick actions).
  Widget _buildReferenceHeroAndActions(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 380;
    final isDark = p.isDark;
    final topPad = MediaQuery.of(context).padding.top;
    final fullName = _safeText(_provider.fullName).isEmpty
        ? 'Care Provider'
        : _safeText(_provider.fullName);
    final serviceLine = _serviceFocusLine ?? _headerSpecialization();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(8, 4 + topPad, 8, 0),
          child: _buildTopNavBar(context, p),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildReferenceProfileCard(
            context: context,
            p: p,
            compact: compact,
            isDark: isDark,
            fullName: fullName,
            serviceLine: serviceLine,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildTopNavBar(BuildContext context, CarelinkPalette p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _roundToolbarIcon(
                p: p,
                onTap: () => Navigator.pop(context),
                child: Transform.translate(
                  offset: const Offset(2, 0),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: p.inkDark,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _roundToolbarIcon(
                    p: p,
                    onTap: () => themeController.toggle(),
                    child: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 20,
                      color: p.inkDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _roundToolbarIcon(
                    p: p,
                    onTap: () => localeController.toggle(),
                    child: Icon(
                      Icons.language_rounded,
                      size: 20,
                      color: p.inkDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _roundToolbarIcon(
                    p: p,
                    onTap: _toggleFavorite,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey<bool>(_isFavorite),
                        size: 20,
                        color: _isFavorite
                            ? const Color(0xFFFF6B6B)
                            : p.inkDark,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          CarelinkBrandLogo(
            height: 34,
            fallbackTextColor: p.inkDark,
            forceDarkLogo: p.isDark,
          ),
        ],
      ),
    );
  }

  Widget _roundToolbarIcon({
    required CarelinkPalette p,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.isDark
                ? p.surface.withValues(alpha: 0.95)
                : const Color(0xFFE8EEF0),
            shape: BoxShape.circle,
            border: Border.all(
              color: p.stroke,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: p.cardShadowColor(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildReferenceProfileCard({
    required BuildContext context,
    required CarelinkPalette p,
    required bool compact,
    required bool isDark,
    required String fullName,
    required String serviceLine,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor(isDark ? 0.4 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: 8,
            child: Opacity(
              opacity: isDark ? 0.1 : 0.07,
              child: Icon(
                Icons.health_and_safety_outlined,
                size: 120,
                color: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 96,
            child: CustomPaint(
              painter: _EcgLinePainter(isDark: isDark),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 20,
              20,
              compact ? 16 : 20,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReferenceAvatar(
                      p: p,
                      compact: compact,
                    ),
                    SizedBox(width: compact ? 14 : 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.inkDark,
                              fontSize: compact ? 20 : 24,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _roleTitle(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (serviceLine.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              serviceLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.inkMuted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          _memberOfCarelinkBadge(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildReferenceQuickActionRow(p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _quickActionIcons = <IconData>[
    Icons.person_outline_rounded,
    Icons.call_rounded,
    Icons.chat_bubble_outline_rounded,
    Icons.more_horiz_rounded,
  ];
  static const _quickActionLabels = <String>[
    'Details',
    'Call',
    'Chat',
    'More',
  ];

  Widget _memberOfCarelinkBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: 15,
            color: Colors.white,
          ),
          SizedBox(width: 6),
          Text(
            'Member of CareLink',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _roleHeroAsset() {
    final role = _safeText(_provider.role).toLowerCase();
    if (role == 'nurse') return 'assets/images/nursemedical.jpg';
    if (role == 'doctor') return 'assets/images/doctorportrait.jpg';
    return 'assets/images/healthcare.jpg';
  }

  Widget _buildReferenceAvatar({
    required CarelinkPalette p,
    required bool compact,
  }) {
    final size = compact ? 86.0 : 96.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          _roleHeroAsset(),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: p.surfaceSoft,
            child: Icon(
              Icons.co_present_outlined,
              size: 40,
              color: p.inkMuted,
            ),
          ),
        ),
      ),
    );
  }

  /// Selected segment: solid **teal** with white icon + label (reference UI).
  Widget _buildReferenceQuickActionRow(CarelinkPalette p) {
    return Material(
      color: p.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(4, (i) {
            final selected = _selectedQuickAction == i;
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedQuickAction = i),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _quickActionIcons[i],
                          size: 20,
                          color: selected
                              ? Colors.white
                              : p.inkMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _quickActionLabels[i],
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : p.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final p = CarelinkPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.24 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _metricCell(_MetricStyle.rating, _displayRating, '')),
          _statDivider(),
          Expanded(
            child: _metricCell(_MetricStyle.distance, _displayDistance, ''),
          ),
          _statDivider(),
          Expanded(
            child: _metricCell(
              _MetricStyle.available,
              _displayAvailabilityMain,
              _displayAvailabilitySub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    final p = CarelinkPalette.of(context);
    return Container(width: 1, height: 44, color: p.stroke);
  }

  Widget _metricCell(_MetricStyle style, String value, String subOrCategory) {
    final p = CarelinkPalette.of(context);
    final isMuted = value == 'Not available';
    final icon = switch (style) {
      _MetricStyle.rating => Icons.star_rounded,
      _MetricStyle.distance => Icons.location_on_rounded,
      _MetricStyle.available => Icons.circle,
    };
    final iconColor = switch (style) {
      _MetricStyle.rating =>
        isMuted ? const Color(0xFFB0BEC5) : const Color(0xFFF6B63C),
      _MetricStyle.distance =>
        isMuted ? const Color(0xFFB0BEC5) : AppColors.primary,
      _MetricStyle.available =>
        isMuted
            ? const Color(0xFFB0BEC5)
            : (value == 'Away'
                  ? const Color(0xFFFF9E29)
                  : const Color(0xFF1CAE62)),
    };
    final iconSize = style == _MetricStyle.available ? 7.0 : 16.0;
    final label = switch (style) {
      _MetricStyle.rating => 'Rating',
      _MetricStyle.distance => 'Distance',
      _MetricStyle.available => 'Availability',
    };
    // Reference: value row, optional sub, then small caption.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != '…') ...[
                Icon(icon, size: iconSize, color: iconColor),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isMuted ? 11.5 : 16,
                    fontWeight: FontWeight.w800,
                    color: isMuted ? p.inkMuted : p.inkDark,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          if (subOrCategory.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subOrCategory,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: p.inkMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: p.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    final p = CarelinkPalette.of(context);
    final aboutText = _aboutText;
    if (aboutText == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        aboutText,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, height: 1.5, color: p.inkMuted),
      ),
    );
  }

  /// Comma-separated list like the reference (no tag chips in body).
  Widget _buildServicesSectionReference() {
    final p = CarelinkPalette.of(context);
    final raw = _safeText(_provider.serviceType);
    final services = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final body = services.isEmpty ? 'Not available' : services.join(', ');
    return _sectionCard(
      title: 'Services',
      leadingIcon: Icons.grid_view_rounded,
      minContentHeight: 0,
      child: Text(
        body,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.4,
          color: p.inkMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static const _weekdayName = <int, String>{
    DateTime.monday: 'monday',
    DateTime.tuesday: 'tuesday',
    DateTime.wednesday: 'wednesday',
    DateTime.thursday: 'thursday',
    DateTime.friday: 'friday',
    DateTime.saturday: 'saturday',
    DateTime.sunday: 'sunday',
  };

  Widget _buildAvailableTodaySection() {
    final p = CarelinkPalette.of(context);
    final slots = _sortedSlots(_provider.availableSlots);
    if (slots.isEmpty) {
      return _sectionCard(
        title: 'Available Today',
        leadingIcon: Icons.access_time_rounded,
        child: Text(
          'Not available',
          style: TextStyle(
            fontSize: 13,
            color: p.inkMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final todayKey = _weekdayName[DateTime.now().weekday]!;
    var display = slots
        .where((s) => s.day.toString().trim().toLowerCase() == todayKey)
        .toList();
    if (display.isEmpty) {
      display = slots.take(6).toList();
    } else {
      display = display.take(6).toList();
    }

    return _sectionCard(
      title: 'Available Today',
      leadingIcon: Icons.access_time_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: display.map((slot) {
          final idx = _provider.availableSlots.indexOf(slot);
          final selected =
              _selectedTimeIndex != null &&
              idx >= 0 &&
              idx == _selectedTimeIndex;
          final label = slot.formattedTime.split(' - ').first;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTimeIndex = idx >= 0 ? idx : null;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : p.surfaceSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? AppColors.primary : p.stroke,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : p.inkDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeeSectionReference() {
    final p = CarelinkPalette.of(context);
    final fee = _provider.consultationFee;
    final hasFee = fee != null && fee > 0;
    return _sectionCard(
      title: 'Consultation Fee',
      leadingIcon: Icons.sell_outlined,
      minContentHeight: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Starting from',
              style: TextStyle(
                color: p.inkMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            hasFee ? '\$${fee.toStringAsFixed(0)}' : 'Not available',
            style: TextStyle(
              color: hasFee ? AppColors.primary : p.inkMuted,
              fontWeight: FontWeight.w800,
              fontSize: hasFee ? 30 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    IconData? leadingIcon,
    double minContentHeight = _kMinInfoCardContentHeight,
  }) {
    final p = CarelinkPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.22 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (leadingIcon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: p.isDark ? 0.16 : 0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(leadingIcon, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.inkMuted, size: 22),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minContentHeight),
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final p = CarelinkPalette.of(context);
    final patientId = _safeText(widget.patientUserId);
    final hasPatientId = patientId.isNotEmpty;
    final canContinue = hasPatientId;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: canContinue
            ? () {
                final defaultPrice = _provider.consultationFee ?? 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SelectServiceScreen(
                      request: BookingRequestModel(
                        patientId: patientId,
                        providerId: _provider.userId,
                        providerName: _provider.fullName,
                        providerRole: _provider.role,
                        specialization: _provider.specialization,
                        serviceType: '',
                        appointmentDate: '',
                        appointmentTime: '',
                        visitLatitude: _provider.gpsLat ?? 0,
                        visitLongitude: _provider.gpsLng ?? 0,
                        visitAddress: '',
                        locationNote: '',
                        patientReason: '',
                        symptoms: '',
                        isUrgent: false,
                        additionalNotes: '',
                        price: defaultPrice,
                        extraFees: 0,
                        paymentMethod: '',
                        paymentStatus: '',
                        bookingStatus: 'pending',
                      ),
                    ),
                  ),
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canContinue ? AppColors.primary : p.surfaceSoft,
          elevation: canContinue ? 3 : 0,
          shadowColor: canContinue
              ? AppColors.primary.withValues(alpha: 0.4)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 22,
            ),
            Expanded(
              child: Text(
                !hasPatientId
                    ? 'Login First'
                    : canContinue
                    ? 'Book Appointment'
                    : 'Login First',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  String _safeText(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.toLowerCase() == 'undefined' || text.toLowerCase() == 'null') {
      return '';
    }
    return text;
  }
}

/// Faint ECG / heartbeat line behind the profile text (reference mockup).
class _EcgLinePainter extends CustomPainter {
  _EcgLinePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final base = isDark
        ? const Color(0xFF00A79D)
        : const Color(0xFF00A896);
    final paint = Paint()
      ..color = base.withValues(alpha: isDark ? 0.14 : 0.11)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final y = size.height * 0.45;
    final w = size.width;
    const seg = 12.0;
    var x = 0.0;
    var up = true;
    final path = Path()..moveTo(0, y);
    while (x < w) {
      if (up) {
        path
          ..lineTo(x + seg * 0.2, y)
          ..lineTo(x + seg * 0.5, y - 5)
          ..lineTo(x + seg * 0.7, y + 6)
          ..lineTo(x + seg, y);
        up = false;
      } else {
        path.lineTo(x + seg, y);
        up = true;
      }
      x += seg;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EcgLinePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

enum _MetricStyle { rating, distance, available }

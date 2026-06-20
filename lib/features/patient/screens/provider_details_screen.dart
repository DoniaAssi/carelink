import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/patient_typography.dart';
import 'package:carelink/features/ai/provider_booking_eligibility.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/models/provider_profile.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/location_service.dart';
import 'package:carelink/shared/services/patient_favorites_service.dart';
import 'package:carelink/shared/services/provider_profile_service.dart';
import 'package:carelink/features/patient/screens/booking_screen.dart';
import 'package:carelink/features/patient/screens/chat_screen.dart';
import 'package:carelink/features/patient/utils/booking_service_helper.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'booking_review_screen.dart';

class ProviderDetailsScreen extends StatefulWidget {
  const ProviderDetailsScreen({
    super.key,
    required this.provider,
    this.patientUserId,
    this.distanceKm,
    this.recommendation,
    this.isRebook = false,
    this.existingBooking,
    this.draftBookingRequest,
  });

  final ProviderModel provider;
  final String? patientUserId;
  final double? distanceKm;

  /// Accepted for route compatibility; recommendation details are not shown on
  /// this simplified provider profile.
  final Map<String, dynamic>? recommendation;
  final bool isRebook;
  final Map<String, dynamic>? existingBooking;
  final BookingRequestModel? draftBookingRequest;

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  late ProviderModel _provider;
  ProviderProfile? _profile;
  bool _loadingDetails = false;
  bool _favorite = false;
  bool _favoriteBusy = false;
  bool _resolvingDistance = false;
  bool _rebookChecking = false;
  String _distance = '';
  double _reviewAverage = 0;
  int _reviewCount = 0;
  List<Map<String, dynamic>> _reviews = const [];
  bool _showAllServices = false;

  bool get _isArabic => context.l10n.isArabic;
  String _t(String en, String ar) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _distance = widget.distanceKm == null
        ? ''
        : '${widget.distanceKm!.toStringAsFixed(1)} km';
    _loadProviderDetails();
    _loadFavorite();
    _loadReviews();
    if (widget.distanceKm == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveDistance());
    }
  }

  Future<void> _loadProviderDetails() async {
    setState(() => _loadingDetails = true);
    try {
      final data = await ApiService().getProviderById(
        widget.provider.userId,
        realAvailability: true,
      );
      data['profileImageUrl'] ??=
          _provider.profileImageUrl ??
          widget.draftBookingRequest?.providerImageUrl;
      final numericId = int.tryParse(widget.provider.userId);
      final profile = numericId == null
          ? null
          : await ProviderProfileService.getProfileLegacy(numericId);
      if (!mounted) return;
      setState(() {
        _provider = ProviderModel.fromJson(data);
        _profile = profile;
      });
      _resolveDistance();
    } catch (_) {
      // Keep the provider data supplied by the previous screen.
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Future<void> _loadFavorite() async {
    final patientId = widget.patientUserId?.trim() ?? '';
    if (patientId.isEmpty) return;
    try {
      final value = await PatientFavoritesService.isFavorite(
        patientId,
        _provider.userId,
      );
      if (mounted) setState(() => _favorite = value);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final patientId = widget.patientUserId?.trim() ?? '';
    if (patientId.isEmpty || _favoriteBusy) return;
    final next = !_favorite;
    setState(() {
      _favorite = next;
      _favoriteBusy = true;
    });
    try {
      if (next) {
        await PatientFavoritesService.addFavorite(patientId, _provider.userId);
      } else {
        await PatientFavoritesService.removeFavorite(
          patientId,
          _provider.userId,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _favorite = !next);
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _loadReviews() async {
    try {
      final data = await ApiService().getProviderRatingsAggregate(
        widget.provider.userId,
        limit: 2,
      );
      final rawItems = data['items'];
      if (!mounted) return;
      setState(() {
        _reviewAverage =
            (data['averageRating'] as num?)?.toDouble() ??
            widget.provider.overallRating;
        _reviewCount =
            (data['ratingsCount'] as num?)?.round() ??
            widget.provider.ratingsCount;
        _reviews = rawItems is List
            ? rawItems
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .take(2)
                  .toList()
            : const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviewAverage = widget.provider.overallRating;
        _reviewCount = widget.provider.ratingsCount;
      });
    }
  }

  Future<void> _resolveDistance() async {
    if (widget.distanceKm != null ||
        _provider.gpsLat == null ||
        _provider.gpsLng == null ||
        _resolvingDistance) {
      return;
    }
    setState(() => _resolvingDistance = true);
    try {
      final position = await LocationService().getCurrentPosition();
      final meters = LocationService().distanceInMeters(
        fromLat: position.latitude,
        fromLng: position.longitude,
        toLat: _provider.gpsLat,
        toLng: _provider.gpsLng,
      );
      if (mounted && meters != null) {
        setState(() => _distance = '${(meters / 1000).toStringAsFixed(1)} km');
      }
    } catch (_) {
      // Distance is optional.
    } finally {
      if (mounted) setState(() => _resolvingDistance = false);
    }
  }

  List<AvailabilitySlot> get _orderedSlots {
    final slots = List<AvailabilitySlot>.from(_provider.availableSlots);
    slots.sort((a, b) {
      final day = _nextDate(a.day).compareTo(_nextDate(b.day));
      return day != 0 ? day : a.startTime.compareTo(b.startTime);
    });
    return slots;
  }

  DateTime _nextDate(String day) {
    const days = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    final target = days[day.trim().toLowerCase()];
    var date = DateTime.now();
    date = DateTime(date.year, date.month, date.day);
    if (target == null) return date;
    while (date.weekday != target) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: _appBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 10, 16, widget.isRebook ? 14 : 24),
          children: widget.isRebook && widget.draftBookingRequest != null
              ? _quickRebookExperience(p)
              : [
                  _heroSection(p),
                  const SizedBox(height: 12),
                  _actionRow(p),
                  const SizedBox(height: 14),
                  _servicesSection(p),
                  const SizedBox(height: 18),
                  _bookingBar(p),
                  if (_aboutText != null) ...[
                    const SizedBox(height: 18),
                    _aboutSection(p),
                  ],
                  if (_reviewCount > 0 || _reviews.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _privateReviewsSection(p),
                  ],
                  if (_loadingDetails) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(
                      color: AppColors.primary,
                      minHeight: 2,
                    ),
                  ],
                ],
        ),
      ),
    );
  }

  List<Widget> _quickRebookExperience(CarelinkPalette p) {
    return [
      _rebookProviderHeader(p),
      const SizedBox(height: 12),
      Text(
        _t('Previous Appointment', 'Previous Appointment'),
        style: TextStyle(
          color: p.inkDark,
          fontSize: 18,
          height: 1.08,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 8),
      _previousAppointmentCard(p),
      const SizedBox(height: 14),
      _rebookPrimaryActions(p),
      const SizedBox(height: 12),
      _reviewsLink(p),
      if (_loadingDetails) ...[
        const SizedBox(height: 14),
        const LinearProgressIndicator(color: AppColors.primary, minHeight: 2),
      ],
    ];
  }

  Widget _rebookProviderHeader(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke.withValues(alpha: 0.68)),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor(p.isDark ? 0.12 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _compactAvatar(p),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 16,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 17,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _specialtyLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB020).withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB020),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _ratingValue,
                            style: TextStyle(
                              color: p.inkDark,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _t('Verified', 'Verified'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previousAppointmentCard(CarelinkPalette p) {
    final request = widget.draftBookingRequest!;
    final service = _cleanDisplay(request.serviceType).isNotEmpty
        ? _cleanDisplay(request.serviceType)
        : _specialtyLabel;
    final date = request.appointmentDate.trim().isNotEmpty
        ? _formatRebookDate(request.appointmentDate)
        : _t('Date unavailable', 'Date unavailable');
    final time = request.appointmentTime.trim().isNotEmpty
        ? _formatRebookTime(request.appointmentTime)
        : _t('Time unavailable', 'Time unavailable');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: p.isDark ? const Color(0xFF0E2C29) : const Color(0xFFEFFBF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: p.isDark ? 0.34 : 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor(p.isDark ? 0.10 : 0.025),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medical_services_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '•',
                  style: TextStyle(color: p.inkMuted, fontSize: 13),
                ),
              ),
              const Icon(
                Icons.schedule_rounded,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactAvatar(CarelinkPalette p) {
    final url = _imageUrl(
      _provider.profileImageUrl ?? widget.draftBookingRequest?.providerImageUrl,
    );
    final initials = _displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: p.isDark ? 0.34 : 0.16),
            AppColors.primary.withValues(alpha: p.isDark ? 0.14 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? 'CL' : initials,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.surfaceSoft,
        border: Border.all(color: p.stroke.withValues(alpha: 0.72), width: 1),
      ),
      child: ClipOval(
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }

  Widget _reviewsLink(CarelinkPalette p) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openProviderReviews,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.stroke.withValues(alpha: 0.65)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _t('Reviews ($_reviewCount)', 'Reviews ($_reviewCount)'),
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProviderReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProviderReviewsScreen(
          providerName: _displayName,
          averageRating: _reviewAverage,
          reviewCount: _reviewCount,
          reviews: _reviews,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _summaryRow(CarelinkPalette p, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.inkDark,
              fontSize: 15,
              height: 1.22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _rebookPrimaryActions(CarelinkPalette p) {
    final providerHasSlots = ProviderBookingEligibility.canBook(_provider);
    final hasOriginalSlot =
        providerHasSlots &&
        widget.draftBookingRequest!.appointmentDate.trim().isNotEmpty &&
        widget.draftBookingRequest!.appointmentTime.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileRebookButton(
          label: _t('Rebook Same Appointment', 'Rebook Same Appointment'),
          onPressed: hasOriginalSlot && !_rebookChecking
              ? _bookSameAppointmentDetails
              : null,
          isLoading: _rebookChecking,
          primary: true,
          palette: p,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Divider(color: p.stroke.withValues(alpha: 0.8))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _t('OR', 'OR'),
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(child: Divider(color: p.stroke.withValues(alpha: 0.8))),
          ],
        ),
        const SizedBox(height: 10),
        _MobileRebookButton(
          label: _t('Choose Different Time', 'Choose Different Time'),
          onPressed: !_rebookChecking && providerHasSlots
              ? _changeRebookTime
              : null,
          primary: false,
          palette: p,
        ),
      ],
    );
  }

  PreferredSizeWidget _appBar() {
    return PatientAppBar(
      titleWidget: Text(
        _displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.patientTx.headline.copyWith(color: AppColors.primary),
      ),
      showLanguage: true,
      showTheme: true,
    );
  }

  Widget _heroSection(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.stroke.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor(p.isDark ? 0.20 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatar(p),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.inkDark,
                              fontSize: 21,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.primary,
                          size: 19,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _specialtyLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _t('CareLink verified', 'موثّق من كيرلينك'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _essentialStatsRow(p),
        ],
      ),
    );
  }

  Widget _avatar(CarelinkPalette p) {
    final url = _imageUrl(_provider.profileImageUrl);
    final initials = _displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: p.isDark ? 0.38 : 0.18),
            AppColors.primary.withValues(alpha: p.isDark ? 0.16 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? 'CL' : initials,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.surfaceSoft,
        border: Border.all(color: p.stroke.withValues(alpha: 0.72), width: 1),
      ),
      child: ClipOval(
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }

  Widget _actionRow(CarelinkPalette p) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            p,
            Icons.chat_bubble_outline_rounded,
            _t('Message', 'مراسلة'),
            _messageProvider,
            isLoading: _isCheckingRelationship,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            p,
            _favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            _t('Favorite', 'المفضلة'),
            _toggleFavorite,
            active: _favorite,
            accentColor: const Color(0xFFE85D75),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    CarelinkPalette p,
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool active = false,
    Color? accentColor,
    bool isLoading = false,
  }) {
    final color = accentColor ?? AppColors.primary;
    return _PressableScale(
      child: Material(
        color: active ? color.withValues(alpha: 0.13) : p.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          splashColor: color.withValues(alpha: 0.16),
          highlightColor: color.withValues(alpha: 0.08),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: active
                    ? color.withValues(alpha: 0.45)
                    : p.stroke.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        active ? color : AppColors.primary,
                      ),
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 17,
                    color: active ? color : AppColors.primary,
                  ),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? color : p.inkDark,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _essentialStatsRow(CarelinkPalette p) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            p,
            Icons.star_rounded,
            _ratingValue,
            _t('Rating', 'Rating'),
          ),
        ),
        _statDivider(p),
        Expanded(
          child: _statTile(
            p,
            Icons.location_on_outlined,
            _resolvingDistance
                ? '...'
                : _distance.isEmpty
                ? _t('Not set', 'Not set')
                : _distance,
            _t('Away', 'Away'),
          ),
        ),
        _statDivider(p),
        Expanded(
          child: _statTile(
            p,
            Icons.schedule_rounded,
            _availabilityShortLabel,
            _availabilityHintLabel,
          ),
        ),
      ],
    );
  }

  Widget _statDivider(CarelinkPalette p) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: p.stroke.withValues(alpha: 0.8),
    );
  }

  Widget _statTile(
    CarelinkPalette p,
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.primary, size: 21),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 13.5,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 11.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _statsRow(CarelinkPalette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: p.isDark ? 0.13 : 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 7,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _statInline(
            Icons.star_rounded,
            '$_ratingValue ${_t('Rating', 'التقييم')}',
          ),
          Text('•', style: TextStyle(color: p.inkMuted, fontSize: 12)),
          _statInline(
            Icons.location_on_outlined,
            _resolvingDistance
                ? '…'
                : _distance.isEmpty
                ? _t('Not set', 'غير محددة')
                : _distance,
          ),
          Text('•', style: TextStyle(color: p.inkMuted, fontSize: 12)),
          _statInline(Icons.bolt_rounded, _availabilityLabel),
        ],
      ),
    );
  }

  Widget _statInline(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 15),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _aboutSection(CarelinkPalette p) {
    return _section(
      p,
      title: _t('About', 'نبذة'),
      child: Text(
        _aboutText!,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: p.inkMuted, fontSize: 13, height: 1.45),
      ),
    );
  }

  // ignore: unused_element
  Widget _focusedRebookSection(CarelinkPalette p) {
    final request = widget.draftBookingRequest!;
    final providerHasSlots = ProviderBookingEligibility.canBook(_provider);
    final hasOriginalSlot =
        providerHasSlots &&
        request.appointmentDate.trim().isNotEmpty &&
        request.appointmentTime.trim().isNotEmpty;
    final service = _cleanDisplay(request.serviceType).isNotEmpty
        ? _cleanDisplay(request.serviceType)
        : _specialtyLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Book Again', 'Book Again'),
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 24,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'Quickly create a new appointment with the same provider.',
                      'Quickly create a new appointment with the same provider.',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _t('Rebook', 'Rebook'),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _RebookOptionCard(
          palette: p,
          highlighted: true,
          enabled: hasOriginalSlot,
          title: _t('Book with same appointment', 'Book with same appointment'),
          description: _t(
            'Use your previous appointment details.',
            'Use your previous appointment details.',
          ),
          facts: [
            _RebookCardFact(
              icon: Icons.calendar_today_rounded,
              text: hasOriginalSlot
                  ? _formatRebookDate(request.appointmentDate)
                  : _t('Date unavailable', 'Date unavailable'),
            ),
            _RebookCardFact(
              icon: Icons.schedule_rounded,
              text: hasOriginalSlot
                  ? _formatRebookTime(request.appointmentTime)
                  : _t('Time unavailable', 'Time unavailable'),
            ),
            _RebookCardFact(icon: Icons.local_offer_outlined, text: service),
          ],
          buttonLabel: _t('Continue', 'Continue'),
          onPressed: hasOriginalSlot ? _bookSameAppointmentDetails : null,
        ),
        const SizedBox(height: 14),
        _RebookOptionCard(
          palette: p,
          title: _t('Change appointment time', 'Change appointment time'),
          description: _t(
            'Keep the same provider and service.',
            'Keep the same provider and service.',
          ),
          facts: [
            _RebookCardFact(icon: Icons.local_offer_outlined, text: service),
          ],
          buttonLabel: _t('Choose New Time', 'Choose New Time'),
          outlinedButton: true,
          onPressed: _changeRebookTime,
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: p.isDark ? 0.13 : 0.07),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.primary,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t(
                    'We keep your data private and secure.',
                    'We keep your data private and secure.',
                  ),
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _premiumRebookSection(CarelinkPalette p) {
    final request = widget.draftBookingRequest!;
    final providerHasSlots = ProviderBookingEligibility.canBook(_provider);
    final hasOriginalSlot =
        providerHasSlots &&
        request.appointmentDate.trim().isNotEmpty &&
        request.appointmentTime.trim().isNotEmpty;
    final slotLabel = hasOriginalSlot
        ? _formatRebookSlot(request.appointmentDate, request.appointmentTime)
        : _t('Previous time unavailable', 'وقت الموعد السابق غير متاح');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: p.stroke.withValues(alpha: 0.5)),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _t('Book Again', 'احجز مرة أخرى'),
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: p.isDark ? 0.16 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      color: AppColors.primary,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _t(
                          'Based on your previous appointment',
                          'بناء على موعدك السابق',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            'Keep the same provider. You can reuse the previous details or choose a new time.',
            'احتفظ بنفس مقدم الرعاية. يمكنك استخدام التفاصيل السابقة أو اختيار وقت جديد.',
          ),
          style: TextStyle(
            color: p.inkMuted,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        _RebookOptionCard(
          palette: p,
          highlighted: true,
          enabled: hasOriginalSlot,
          icon: Icons.history_toggle_off_rounded,
          title: _t(
            'Book with same appointment details',
            'احجز بنفس تفاصيل الموعد',
          ),
          description: _t(
            'Use the same service, date, time and location as your previous booking.',
            'استخدم نفس الخدمة والتاريخ والوقت والموقع من الحجز السابق.',
          ),
          metaIcon: Icons.calendar_today_rounded,
          metaText: slotLabel,
          buttonLabel: _t('Continue', 'متابعة'),
          onPressed: hasOriginalSlot ? _bookSameAppointmentDetails : null,
        ),
        const SizedBox(height: 14),
        _RebookOptionCard(
          palette: p,
          icon: Icons.calendar_month_rounded,
          title: _t('Change appointment time', 'تغيير وقت الموعد'),
          description: _t(
            'Keep the same provider and service, but choose a new date and time.',
            'احتفظ بنفس مقدم الرعاية والخدمة، واختر تاريخا ووقتا جديدين.',
          ),
          buttonLabel: _t('Choose New Time', 'اختر وقتا جديدا'),
          outlinedButton: true,
          onPressed: _changeRebookTime,
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: p.isDark ? const Color(0xFF112A35) : const Color(0xFFEAF6FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: p.isDark
                  ? const Color(0xFF1E4B5C)
                  : const Color(0xFFD4ECF5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: p.isDark
                    ? const Color(0xFF7DC8E1)
                    : const Color(0xFF2C6B86),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t(
                    'You will review all details before confirming the new booking.',
                    'ستراجع كل التفاصيل قبل تأكيد الحجز الجديد.',
                  ),
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _rebookSection(CarelinkPalette p) {
    final request = widget.draftBookingRequest!;
    final providerHasSlots = ProviderBookingEligibility.canBook(_provider);
    final hasOriginalSlot =
        providerHasSlots &&
        request.appointmentDate.trim().isNotEmpty &&
        request.appointmentTime.trim().isNotEmpty;
    return _section(
      p,
      title: _t('Book Again', 'احجز مرة أخرى'),
      subtitle: _t(
        'New booking based on your previous appointment',
        'حجز جديد بناء على موعدك السابق',
      ),
      showDivider: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t(
              'Keep the same provider. You can reuse the previous details or choose a new time.',
              'احتفظ بنفس مقدم الرعاية. يمكنك استخدام التفاصيل السابقة أو اختيار وقت جديد.',
            ),
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          PatientPrimaryButton(
            onPressed: hasOriginalSlot ? _bookSameAppointmentDetails : null,
            icon: Icons.replay_rounded,
            label: _t(
              'Book with same appointment details',
              'احجز بنفس تفاصيل الموعد',
            ),
          ),
          if (!hasOriginalSlot) ...[
            const SizedBox(height: 8),
            Text(
              _t(
                'The previous booking has no saved date/time, so please choose a time.',
                'لا يحتوي الحجز السابق على تاريخ ووقت محفوظين، يرجى اختيار وقت.',
              ),
              style: TextStyle(color: p.inkMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 10),
          PatientSecondaryButton(
            onPressed: providerHasSlots ? _changeRebookTime : null,
            icon: Icons.edit_calendar_rounded,
            label: _t('Change appointment time', 'تغيير وقت الموعد'),
          ),
        ],
      ),
    );
  }

  Future<void> _bookSameAppointmentDetails() async {
    final request = widget.draftBookingRequest;
    if (request == null || _rebookChecking) return;
    setState(() => _rebookChecking = true);
    final available = await _isDraftSlotAvailable(request);
    if (!mounted) return;
    setState(() => _rebookChecking = false);
    if (available) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingReviewScreen(request: request),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(
            'The previous date/time is no longer available. Please choose another time.',
            'وقت الموعد السابق لم يعد متاحا. يرجى اختيار وقت آخر.',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _changeRebookTime(previousTimeUnavailable: true);
  }

  void _changeRebookTime({bool previousTimeUnavailable = false}) {
    final request = widget.draftBookingRequest;
    if (request == null) return;
    if (!ProviderBookingEligibility.canBook(_provider)) {
      _notice(
        _t(
          'This provider has no available appointments right now.',
          'لا توجد مواعيد متاحة لهذا مقدم الرعاية حالياً.',
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          request: previousTimeUnavailable
              ? request.copyWith(appointmentTime: '')
              : request,
          previousTimeUnavailable: previousTimeUnavailable,
        ),
      ),
    );
  }

  Future<bool> _isDraftSlotAvailable(BookingRequestModel request) async {
    final date = request.appointmentDate.trim();
    final time = _normalizeTime(request.appointmentTime);
    if (date.isEmpty || time == null) return false;

    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) return false;
    final slotDateTime = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      int.tryParse(time.split(':').first) ?? 0,
      int.tryParse(time.split(':').last) ?? 0,
    );
    if (slotDateTime.isBefore(DateTime.now())) return false;

    try {
      final duplicate = await ApiService().checkDuplicateBooking(
        patientId: request.patientId,
        providerId: request.providerId,
        serviceType: request.serviceType,
        date: date,
        time: time,
      );
      if (duplicate) return false;

      final providerJson = await ApiService().getProviderById(
        request.providerId,
        realAvailability: true,
      );
      final blocked = (await ApiService().getProviderBlockedSlots(
        request.providerId,
      )).toSet();
      if (blocked.contains('$date $time') ||
          blocked.contains('$date $time:00')) {
        return false;
      }

      final slots =
          (providerJson['availableSlots'] as List?)
              ?.whereType<Map>()
              .map((slot) => Map<String, dynamic>.from(slot))
              .toList() ??
          const <Map<String, dynamic>>[];
      return slots.any((slot) {
        final slotTime = _normalizeTime((slot['startTime'] ?? '').toString());
        if (slotTime != time) return false;
        final slotDate = DateTime.tryParse((slot['date'] ?? '').toString());
        if (slotDate != null) {
          return slotDate.year == parsedDate.year &&
              slotDate.month == parsedDate.month &&
              slotDate.day == parsedDate.day;
        }
        final day = (slot['day'] ?? '').toString().trim().toLowerCase();
        const weekdays = {
          'monday': DateTime.monday,
          'tuesday': DateTime.tuesday,
          'wednesday': DateTime.wednesday,
          'thursday': DateTime.thursday,
          'friday': DateTime.friday,
          'saturday': DateTime.saturday,
          'sunday': DateTime.sunday,
        };
        return weekdays[day] == parsedDate.weekday;
      });
    } catch (_) {
      return false;
    }
  }

  String? _normalizeTime(String raw) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _formatRebookSlot(String rawDate, String rawTime) {
    final date = DateTime.tryParse(rawDate.trim());
    final normalizedTime = _normalizeTime(rawTime);
    if (date == null || normalizedTime == null) {
      return '$rawDate $rawTime'.trim();
    }

    final parts = normalizedTime.split(':');
    final hour24 = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final suffix = _isArabic
        ? (hour24 >= 12 ? 'م' : 'ص')
        : (hour24 >= 12 ? 'PM' : 'AM');
    final time = '$hour12:${minute.toString().padLeft(2, '0')} $suffix';

    final weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekdaysAr = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final monthsEn = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthsAr = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    final day = _isArabic
        ? weekdaysAr[date.weekday - 1]
        : weekdaysEn[date.weekday - 1];
    final month = _isArabic
        ? monthsAr[date.month - 1]
        : monthsEn[date.month - 1];
    return _isArabic
        ? '$day، ${date.day} $month الساعة $time'
        : '$day, $month ${date.day} at $time';
  }

  String _formatRebookDate(String rawDate) {
    final date = DateTime.tryParse(rawDate.trim());
    if (date == null) return rawDate.trim();
    final weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final monthsEn = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdaysEn[date.weekday - 1]}, ${monthsEn[date.month - 1]} ${date.day}';
  }

  String _formatRebookTime(String rawTime) {
    final normalizedTime = _normalizeTime(rawTime);
    if (normalizedTime == null) return rawTime.trim();
    final parts = normalizedTime.split(':');
    final hour24 = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  Widget _servicesSection(CarelinkPalette p) {
    final services = _services;
    final visibleServices = _showAllServices
        ? services
        : services.take(3).toList();
    return _section(
      p,
      title: _t('Services', 'الخدمات'),
      showDivider: false,
      trailing: services.length > 3
          ? TextButton(
              onPressed: () {
                setState(() => _showAllServices = !_showAllServices);
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _showAllServices
                    ? _t('Show less', 'عرض أقل')
                    : _t('View all', 'عرض الكل'),
              ),
            )
          : null,
      child: services.isEmpty
          ? Text(
              _t('General care service', 'خدمة رعاية عامة'),
              style: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w600),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...visibleServices.map(
                  (service) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      service,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _privateReviewsSection(CarelinkPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('Reviews', 'Reviews'),
          style: TextStyle(
            color: p.inkDark,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFB020), size: 25),
            const SizedBox(width: 6),
            Text(
              _reviewAverage.toStringAsFixed(1),
              style: TextStyle(
                color: p.inkDark,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _t('($_reviewCount reviews)', '($_reviewCount reviews)'),
              style: TextStyle(
                color: p.inkMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (_reviews.isNotEmpty) ...[
          const SizedBox(height: 14),
          ..._reviews.map((review) => _privateReviewTile(p, review)),
        ],
      ],
    );
  }

  Widget _privateReviewTile(CarelinkPalette p, Map<String, dynamic> review) {
    final comment = _clean(review['comment']);
    final rating = double.tryParse('${review['stars'] ?? ''}') ?? 0;
    final dateLabel = _formatReviewDate(review);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(maxHeight: 118),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor(p.isDark ? 0.13 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _anonymousAvatar(p, review),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _anonymousName(review),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (dateLabel.isNotEmpty)
                      Text(
                        dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating.round()
                          ? Icons.star_rounded
                          : Icons.star_rounded,
                      color: index < rating.round()
                          ? const Color(0xFFFFB020)
                          : p.stroke,
                      size: 17,
                    );
                  }),
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    comment,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 13,
                      height: 1.28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _anonymousAvatar(CarelinkPalette p, Map<String, dynamic> review) {
    final initial = _anonymousName(review).characters.first;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: p.isDark ? 0.22 : 0.10),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  String _anonymousName(Map<String, dynamic> review) {
    final raw = _clean(review['patientName']);
    final first = raw.isEmpty ? 'P' : raw.characters.first.toUpperCase();
    return '$first*****';
  }

  String _formatReviewDate(Map<String, dynamic> review) {
    final raw = _clean(review['createdAt']).isNotEmpty
        ? _clean(review['createdAt'])
        : _clean(review['date']);
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  // ignore: unused_element
  Widget _reviewsSection(CarelinkPalette p) {
    return _section(
      p,
      title: _t('Reviews', 'التقييمات'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFB020),
                size: 21,
              ),
              const SizedBox(width: 5),
              Text(
                _reviewAverage.toStringAsFixed(1),
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _t('$_reviewCount reviews', '$_reviewCount تقييم'),
                style: TextStyle(color: p.inkMuted, fontSize: 12),
              ),
            ],
          ),
          if (_reviews.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._reviews.map((review) => _reviewTile(p, review)),
          ],
        ],
      ),
    );
  }

  Widget _reviewTile(CarelinkPalette p, Map<String, dynamic> review) {
    final comment = _clean(review['comment']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _clean(review['patientName']).isEmpty
                      ? _t('Patient', 'مريض')
                      : review['patientName'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFB020),
                size: 14,
              ),
              Text(
                '${review['stars'] ?? ''}',
                style: TextStyle(color: p.inkMuted, fontSize: 11),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              comment,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 11.5, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(
    CarelinkPalette p, {
    required String title,
    required Widget child,
    String? subtitle,
    Widget? trailing,
    bool showDivider = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ...?(trailing == null ? null : [trailing]),
          ],
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
        if (showDivider) ...[
          const SizedBox(height: 16),
          Divider(color: p.stroke.withValues(alpha: 0.5)),
        ],
      ],
    );
  }

  Widget _bookingBar(CarelinkPalette p) {
    final patientId = widget.patientUserId?.trim() ?? '';
    final hasSlots = ProviderBookingEligibility.canBook(_provider);
    final enabled = patientId.isNotEmpty && hasSlots;
    final label = patientId.isEmpty
        ? _t('Login First', 'سجل الدخول أولاً')
        : !hasSlots
        ? _t('No available slots', 'لا توجد مواعيد متاحة')
        : _t('Book Now', 'احجز الآن');
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (patientId.isNotEmpty && !hasSlots) ...[
            Text(
              _t(
                'This provider has no available appointments right now.',
                'لا توجد مواعيد متاحة لهذا مقدم الرعاية حالياً.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.inkMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 52,
            width: double.infinity,
            child: Align(
              alignment: Alignment.center,
              child: _PressableScale(
                enabled: enabled,
                child: Material(
                  color: enabled
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(28),
                  elevation: enabled ? 8 : 0,
                  shadowColor: AppColors.primary.withValues(alpha: 0.28),
                  child: InkWell(
                    onTap: enabled ? _book : null,
                    borderRadius: BorderRadius.circular(28),
                    splashColor: Colors.white.withValues(alpha: 0.16),
                    highlightColor: Colors.white.withValues(alpha: 0.08),
                    child: Container(
                      height: 52,
                      constraints: const BoxConstraints(
                        minWidth: 154,
                        maxWidth: 260,
                      ),
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        18,
                        0,
                        16,
                        0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                            textDirection: Directionality.of(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _book() {
    final patientId = widget.patientUserId?.trim() ?? '';
    if (patientId.isEmpty) return;
    if (!ProviderBookingEligibility.canBook(_provider)) {
      _notice(
        _t(
          'This provider has no available appointments right now.',
          'لا توجد مواعيد متاحة لهذا مقدم الرعاية حالياً.',
        ),
      );
      return;
    }
    final request = BookingServiceHelper.createRequestForProvider(
      provider: _provider,
      patientId: patientId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          request: widget.isRebook && widget.existingBooking != null
              ? request.copyWith(
                  isRebook: true,
                  previousAppointmentId: widget.existingBooking!['requestId']?.toString() ?? '',
                  serviceType: widget.existingBooking!['serviceType']?.toString() ?? request.serviceType,
                )
              : request,
        ),
      ),
    );
  }

  bool _isCheckingRelationship = false;

  Future<void> _messageProvider() async {
    final patientId = widget.patientUserId?.trim() ?? '';
    if (patientId.isEmpty) {
      _notice(_t('Please sign in first.', 'يرجى تسجيل الدخول أولاً.'));
      return;
    }

    if (_isCheckingRelationship) return;

    setState(() {
      _isCheckingRelationship = true;
    });

    try {
      final appointments = await ApiService().getAppointments(patientId);
      final history = await ApiService().getAppointmentHistory(patientId);

      final allAppointments = [...appointments, ...history];

      final hasRelationship = allAppointments.any((apt) {
        return apt['providerUserId'] == _provider.userId ||
            apt['providerId'] == _provider.userId;
      });

      if (!hasRelationship) {
        _notice(
          _t(
            'You can message a provider after sending a booking request or having an appointment with them.',
            'يمكنك مراسلة مقدم الرعاية بعد إرسال طلب حجز أو وجود موعد معه.',
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            name: _provider.fullName,
            userId: patientId,
            doctorId: _provider.userId,
          ),
        ),
      );
    } catch (e) {
      _notice(
        _t(
          'Error checking relationship. Please try again.',
          'حدث خطأ. يرجى المحاولة مرة أخرى.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingRelationship = false;
        });
      }
    }
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        ),
      );
  }

  String get _displayName {
    final name = _cleanDisplay(_provider.fullName);
    return name.isEmpty ? _t('Care Provider', 'مقدم رعاية') : name;
  }

  String get _specialtyLabel {
    final specialty = _cleanDisplay(_provider.specialization);
    return specialty.isEmpty
        ? _t('General Care Provider', 'مقدم رعاية عامة')
        : specialty;
  }

  String get _ratingValue {
    final value = _reviewAverage > 0 ? _reviewAverage : _provider.overallRating;
    return value > 0 ? value.toStringAsFixed(1) : '—';
  }

  String get _availabilityLabel {
    if (!ProviderBookingEligibility.canBook(_provider)) {
      return _t('Availability not set', 'التوفر غير محدد');
    }
    return _availableDayLabel == _t('Available today', 'متاح اليوم')
        ? _t('Available Today', 'متاح اليوم')
        : _t('Available', 'متاح');
  }

  String get _availabilityShortLabel {
    if (!ProviderBookingEligibility.canBook(_provider)) {
      return _t('Not set', 'Not set');
    }
    return _t('Available', 'Available');
  }

  String get _availabilityHintLabel {
    if (!ProviderBookingEligibility.canBook(_provider)) {
      return _t('No slots', 'No slots');
    }
    return _availableDayLabel.toLowerCase().contains('today')
        ? _t('Today', 'Today')
        : _t('Now', 'Now');
  }

  String? get _aboutText {
    final bio = _clean(_profile?.bio);
    return bio.isEmpty ? null : bio;
  }

  List<String> get _services => _clean(_provider.serviceType)
      .split(RegExp(r'[,;]'))
      .map(_cleanDisplay)
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  List<AvailabilitySlot> get _todayOrNextSlots {
    final slots = _orderedSlots;
    if (slots.isEmpty) return const [];
    const names = {
      DateTime.monday: 'monday',
      DateTime.tuesday: 'tuesday',
      DateTime.wednesday: 'wednesday',
      DateTime.thursday: 'thursday',
      DateTime.friday: 'friday',
      DateTime.saturday: 'saturday',
      DateTime.sunday: 'sunday',
    };
    final today = names[DateTime.now().weekday];
    final todaySlots = slots
        .where((slot) => slot.day.trim().toLowerCase() == today)
        .take(6)
        .toList();
    return todaySlots.isNotEmpty ? todaySlots : slots.take(6).toList();
  }

  String get _availableDayLabel {
    final slots = _todayOrNextSlots;
    if (slots.isEmpty) return '';
    final isToday =
        _nextDate(slots.first.day).difference(_nextDate('invalid')).inDays == 0;
    return isToday ? _t('Available today', 'متاح اليوم') : slots.first.day;
  }

  String? _imageUrl(String? raw) {
    final value = _clean(raw);
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return value.startsWith('/')
        ? '${ApiService.baseUrl}$value'
        : '${ApiService.baseUrl}/$value';
  }

  String _clean(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.toLowerCase() == 'null' || text.toLowerCase() == 'undefined') {
      return '';
    }
    return text;
  }

  String _cleanDisplay(Object? value) {
    final text = _clean(value);
    final normalized = text.toLowerCase();
    if (const {
      'user',
      'carid',
      'careid',
      'unknown',
      'n/a',
      '-',
    }.contains(normalized)) {
      return '';
    }
    return text;
  }
}

class _MobileRebookButton extends StatefulWidget {
  const _MobileRebookButton({
    required this.label,
    required this.palette,
    required this.primary,
    this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final CarelinkPalette palette;
  final bool? primary;
  final VoidCallback? onPressed;
  final bool? isLoading;

  @override
  State<_MobileRebookButton> createState() => _MobileRebookButtonState();
}

class _MobileRebookButtonState extends State<_MobileRebookButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary ?? false;
    final isLoading = widget.isLoading ?? false;
    final enabled = widget.onPressed != null && !isLoading;
    final bg = primary ? AppColors.primary : Colors.transparent;
    final fg = primary ? Colors.white : AppColors.primary;
    final disabledBg = primary
        ? AppColors.primary.withValues(alpha: 0.36)
        : Colors.transparent;

    return Listener(
      onPointerDown: enabled ? (_) => _setPressed(true) : null,
      onPointerUp: enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Material(
          color: enabled ? bg : disabledBg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: enabled ? widget.onPressed : null,
            borderRadius: BorderRadius.circular(16),
            splashColor: (primary ? Colors.white : AppColors.primary)
                .withValues(alpha: 0.16),
            highlightColor: (primary ? Colors.white : AppColors.primary)
                .withValues(alpha: 0.08),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primary
                      ? Colors.transparent
                      : enabled
                      ? AppColors.primary
                      : widget.palette.stroke,
                  width: 1.35,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          valueColor: AlwaysStoppedAnimation<Color>(fg),
                        ),
                      )
                    : Text(
                        widget.label,
                        key: ValueKey(widget.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: enabled ? fg : widget.palette.inkMuted,
                          fontSize: primary ? 15 : 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderReviewsScreen extends StatelessWidget {
  const _ProviderReviewsScreen({
    required this.providerName,
    required this.averageRating,
    required this.reviewCount,
    required this.reviews,
  });

  final String providerName;
  final double averageRating;
  final int reviewCount;
  final List<Map<String, dynamic>> reviews;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(
        titleWidget: Text(
          'Reviews',
          style: context.patientTx.headline.copyWith(color: AppColors.primary),
        ),
        showLanguage: false,
        showTheme: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFB020),
                  size: 26,
                ),
                const SizedBox(width: 8),
                Text(
                  averageRating.toStringAsFixed(1),
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$reviewCount reviews',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (reviews.isEmpty)
              Text(
                'No reviews yet.',
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              ...reviews.map((review) => _reviewTile(context, p, review)),
          ],
        ),
      ),
    );
  }

  Widget _reviewTile(
    BuildContext context,
    CarelinkPalette p,
    Map<String, dynamic> review,
  ) {
    final comment = _clean(review['comment']);
    final rating = double.tryParse('${review['stars'] ?? ''}') ?? 0;
    final date = _formatDate(review);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star_rounded,
                      color: index < rating.round()
                          ? const Color(0xFFFFB020)
                          : p.stroke,
                      size: 17,
                    );
                  }),
                ),
              ),
              if (date.isNotEmpty)
                Text(
                  date,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.inkDark,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _anonymousName(review),
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _anonymousName(Map<String, dynamic> review) {
    final raw = _clean(review['patientName']);
    final first = raw.isEmpty ? 'P' : raw.characters.first.toUpperCase();
    return '$first*****';
  }

  String _formatDate(Map<String, dynamic> review) {
    final raw = _clean(review['createdAt']).isNotEmpty
        ? _clean(review['createdAt'])
        : _clean(review['date']);
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  String _clean(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.toLowerCase() == 'null' || text.toLowerCase() == 'undefined') {
      return '';
    }
    return text;
  }
}

class _RebookCardFact {
  const _RebookCardFact({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class _RebookOptionCard extends StatelessWidget {
  const _RebookOptionCard({
    required this.palette,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    this.icon,
    this.facts = const [],
    this.highlighted = false,
    this.outlinedButton = false,
    this.enabled = true,
    this.metaIcon,
    this.metaText,
  });

  final CarelinkPalette palette;
  final IconData? icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final List<_RebookCardFact> facts;
  final bool highlighted;
  final bool outlinedButton;
  final bool enabled;
  final IconData? metaIcon;
  final String? metaText;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && onPressed != null;
    final bg = highlighted
        ? (palette.isDark ? const Color(0xFF0D2C28) : const Color(0xFFEFFBF8))
        : palette.surface;
    final borderColor = highlighted
        ? AppColors.primary.withValues(alpha: palette.isDark ? 0.42 : 0.26)
        : palette.stroke;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canTap ? onPressed : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: palette.cardShadowColor(palette.isDark ? 0.13 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 430;
              final copy = _copy();
              final button = _button();
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    const SizedBox(height: 10),
                    button,
                    if ((metaText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _metaRow(),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 130,
                      maxWidth: 170,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        button,
                        if ((metaText ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _metaRow(),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _copy() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(
                alpha: palette.isDark ? 0.18 : 0.10,
              ),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.5,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.inkMuted,
                  fontSize: 12.4,
                  height: 1.32,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 9),
                Wrap(
                  spacing: 11,
                  runSpacing: 6,
                  children: facts.map(_factChip).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _factChip(_RebookCardFact fact) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(fact.icon, color: AppColors.primary, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              fact.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.inkMuted,
                fontSize: 11.6,
                height: 1.22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button() {
    final disabled = !enabled || onPressed == null;
    if (outlinedButton) {
      return OutlinedButton(
        onPressed: disabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: AppColors.primary,
          disabledForegroundColor: palette.inkMuted,
          side: BorderSide(
            color: disabled ? palette.stroke : AppColors.primary,
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                buttonLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
      );
    }

    return FilledButton(
      onPressed: disabled ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.36),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.8),
      ),
      child: Text(buttonLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _metaRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          metaIcon ?? Icons.event_available_rounded,
          color: AppColors.primary,
          size: 17,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            metaText ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (!widget.enabled || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : (_hovered ? 1.01 : 1),
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

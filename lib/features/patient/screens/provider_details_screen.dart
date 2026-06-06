import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/models/provider_profile.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/location_service.dart';
import 'package:carelink/shared/services/patient_favorites_service.dart';
import 'package:carelink/shared/services/provider_profile_service.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'chat_screen.dart';
import 'select_service_screen.dart';

class ProviderDetailsScreen extends StatefulWidget {
  const ProviderDetailsScreen({
    super.key,
    required this.provider,
    this.patientUserId,
    this.distanceKm,
    this.recommendation,
  });

  final ProviderModel provider;
  final String? patientUserId;
  final double? distanceKm;

  /// Existing backend recommendation payload. When absent, the AI section is
  /// intentionally hidden.
  final Map<String, dynamic>? recommendation;

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  late ProviderModel _provider;
  ProviderProfile? _profile;
  bool _loadingDetails = false;
  bool _favorite = false;
  bool _resolvingDistance = false;
  String _distance = '';
  int? _selectedTimeIndex;
  double _reviewAverage = 0;
  int _reviewCount = 0;
  List<Map<String, dynamic>> _reviews = const [];

  bool get _isArabic => context.l10n.isArabic;
  String _t(String en, String ar) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _distance = widget.distanceKm == null
        ? ''
        : '${widget.distanceKm!.toStringAsFixed(1)} km';
    _syncSelection();
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
      final data = await ApiService().getProviderById(widget.provider.userId);
      data['profileImageUrl'] ??= _provider.profileImageUrl;
      final numericId = int.tryParse(widget.provider.userId);
      final profile = numericId == null
          ? null
          : await ProviderProfileService.getProfileLegacy(numericId);
      if (!mounted) return;
      setState(() {
        _provider = ProviderModel.fromJson(data);
        _profile = profile;
        _syncSelection();
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
    if (patientId.isEmpty) return;
    try {
      await PatientFavoritesService.toggleFavorite(patientId, _provider.userId);
      await _loadFavorite();
    } catch (_) {}
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

  void _syncSelection() {
    final slots = _orderedSlots;
    _selectedTimeIndex = slots.isEmpty
        ? null
        : _provider.availableSlots.indexOf(slots.first);
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
      bottomNavigationBar: _bookingBar(p),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
          children: [
            _profileCard(p),
            const SizedBox(height: 12),
            _actionRow(p),
            if (_hasRecommendationData) ...[
              const SizedBox(height: 14),
              _recommendationCard(p),
            ],
            const SizedBox(height: 14),
            _statsRow(p),
            if (_aboutText != null) ...[
              const SizedBox(height: 14),
              _aboutSection(p),
            ],
            if (_services.isNotEmpty) ...[
              const SizedBox(height: 14),
              _servicesSection(p),
            ],
            if (_orderedSlots.isNotEmpty) ...[
              const SizedBox(height: 14),
              _timesSection(p),
            ],
            if (_reviewCount > 0 || _reviews.isNotEmpty) ...[
              const SizedBox(height: 14),
              _reviewsSection(p),
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

  PreferredSizeWidget _appBar() {
    final title = _clean(_provider.fullName);
    return PatientAppBar(
      title: title.isEmpty
          ? _t('Provider Details', 'تفاصيل مقدم الرعاية')
          : title,
      actions: [
        IconButton(
          onPressed: _toggleFavorite,
          icon: Icon(
            _favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _favorite ? const Color(0xFFE85D75) : AppColors.primary,
          ),
        ),
        IconButton(
          onPressed: _shareProvider,
          icon: const Icon(Icons.ios_share_rounded),
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _profileCard(CarelinkPalette p) {
    final specialty = _clean(_provider.specialization);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(p),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(p),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _clean(_provider.fullName).isEmpty
                            ? _t('Care Provider', 'مقدم رعاية')
                            : _provider.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 20,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  specialty.isNotEmpty ? specialty : _roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.health_and_safety_outlined,
                        color: AppColors.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _t('CareLink verified', 'موثّق من كيرلينك'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(CarelinkPalette p) {
    final url = _imageUrl(_provider.profileImageUrl);
    final fallback = ColoredBox(
      color: AppColors.primary.withValues(alpha: p.isDark ? 0.22 : 0.10),
      child: const Center(
        child: Icon(
          Icons.medical_services_outlined,
          color: AppColors.primary,
          size: 32,
        ),
      ),
    );
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 2,
        ),
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
        _actionButton(
          p,
          Icons.call_outlined,
          _t('Call', 'اتصال'),
          _callProvider,
        ),
        const SizedBox(width: 8),
        _actionButton(
          p,
          Icons.chat_bubble_outline_rounded,
          _t('Message', 'مراسلة'),
          _messageProvider,
        ),
        const SizedBox(width: 8),
        _actionButton(
          p,
          _favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          _t('Favorite', 'المفضلة'),
          _toggleFavorite,
          active: _favorite,
        ),
        const SizedBox(width: 8),
        _actionButton(
          p,
          Icons.more_horiz_rounded,
          _t('More', 'المزيد'),
          _showMore,
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
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: active ? Colors.white : AppColors.primary,
          backgroundColor: active ? AppColors.primary : p.surface,
          side: BorderSide(
            color: active
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendationCard(CarelinkPalette p) {
    final medical = _medicalMatch;
    final overall = _overallMatch;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: p.isDark ? 0.12 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _t('Match information', 'معلومات التوافق'),
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (medical != null || overall != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (medical != null)
                  Expanded(
                    child: _matchStat(
                      p,
                      _t('Medical Match', 'التوافق الطبي'),
                      medical,
                    ),
                  ),
                if (medical != null && overall != null)
                  const SizedBox(width: 8),
                if (overall != null)
                  Expanded(
                    child: _matchStat(
                      p,
                      _t('Overall Match', 'التوافق العام'),
                      overall,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _matchStat(CarelinkPalette p, String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value%',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(CarelinkPalette p) {
    final stats = <({IconData icon, String value, String label})>[
      (
        icon: Icons.star_rounded,
        value: _provider.overallRating > 0
            ? _provider.overallRating.toStringAsFixed(1)
            : '—',
        label: _t('Rating', 'التقييم'),
      ),
      if (_distance.isNotEmpty || _resolvingDistance)
        (
          icon: Icons.location_on_outlined,
          value: _resolvingDistance ? '…' : _distance,
          label: _t('Distance', 'المسافة'),
        ),
      (
        icon: Icons.bolt_rounded,
        value: _provider.isAvailable
            ? _t('Available', 'متاح')
            : _t('Away', 'غير متاح'),
        label: _t('Status', 'الحالة'),
      ),
      if ((_provider.experienceYears ?? 0) > 0)
        (
          icon: Icons.workspace_premium_outlined,
          value: '${_provider.experienceYears}',
          label: _t('Years', 'سنوات'),
        ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: _cardDecoration(p),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            Expanded(child: _stat(p, stats[i])),
            if (i != stats.length - 1)
              Container(width: 1, height: 34, color: p.stroke),
          ],
        ],
      ),
    );
  }

  Widget _stat(
    CarelinkPalette p,
    ({IconData icon, String value, String label}) stat,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(stat.icon, color: AppColors.primary, size: 17),
        const SizedBox(height: 4),
        Text(
          stat.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: p.inkDark,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: p.inkMuted, fontSize: 9.5),
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

  Widget _servicesSection(CarelinkPalette p) {
    return _section(
      p,
      title: _t('Services', 'الخدمات'),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: _services
            .map(
              (service) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  service,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _timesSection(CarelinkPalette p) {
    final slots = _todayOrNextSlots;
    return _section(
      p,
      title: _t('Available Times', 'الأوقات المتاحة'),
      subtitle: _availableDayLabel,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: slots.map((slot) {
          final index = _provider.availableSlots.indexOf(slot);
          final selected = index >= 0 && index == _selectedTimeIndex;
          return ChoiceChip(
            showCheckmark: false,
            selected: selected,
            selectedColor: AppColors.primary,
            backgroundColor: p.surface,
            side: BorderSide(color: selected ? AppColors.primary : p.stroke),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            label: Text(
              slot.formattedTime.split(' - ').first,
              style: TextStyle(
                color: selected ? Colors.white : p.inkDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            onSelected: (_) => setState(() => _selectedTimeIndex = index),
          );
        }).toList(),
      ),
    );
  }

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
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: p.inkDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _bookingBar(CarelinkPalette p) {
    final patientId = widget.patientUserId?.trim() ?? '';
    final fee = _provider.consultationFee;
    final selected = _selectedSlot;
    final hasSlots = _orderedSlots.isNotEmpty;
    final suffix = selected != null
        ? selected.formattedTime.split(' - ').first
        : fee != null && fee > 0
        ? '${fee.toStringAsFixed(0)} ILS'
        : '';
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.stroke)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.isDark ? 0.24 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: patientId.isEmpty || !hasSlots ? null : _book,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              patientId.isEmpty
                  ? _t('Login First', 'سجل الدخول أولاً')
                  : !hasSlots
                  ? _t(
                      'No available slots for this provider.',
                      'لا توجد مواعيد متاحة لهذا مقدم الرعاية.',
                    )
                  : '${_t('Book Appointment', 'احجز موعداً')}${suffix.isEmpty ? '' : ' · $suffix'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  void _book() {
    final patientId = widget.patientUserId?.trim() ?? '';
    if (patientId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectServiceScreen(
          request: BookingRequestModel(
            patientId: patientId,
            providerId: _provider.userId,
            providerName: _provider.fullName,
            providerRole: _provider.role,
            providerImageUrl: _provider.profileImageUrl ?? '',
            specialization: _provider.specialization,
            serviceType: _provider.serviceType,
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
            price: _provider.consultationFee ?? 0,
            extraFees: 0,
            paymentMethod: '',
            paymentStatus: '',
            bookingStatus: 'pending',
          ),
        ),
      ),
    );
  }

  Future<void> _callProvider() async {
    final phone = _clean(_profile?.phone).isNotEmpty
        ? _clean(_profile?.phone)
        : _clean(_provider.phone);
    if (phone.isEmpty) {
      _notice(
        _t(
          'Provider phone number is not available.',
          'رقم هاتف مقدم الرعاية غير متوفر.',
        ),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      _notice(_t('Could not open the dialer.', 'تعذر فتح تطبيق الاتصال.'));
    }
  }

  void _messageProvider() {
    final patientId = widget.patientUserId?.trim() ?? '';
    if (patientId.isEmpty) {
      _notice(_t('Please sign in first.', 'يرجى تسجيل الدخول أولاً.'));
      return;
    }
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
  }

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CarelinkPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.ios_share_rounded,
                  color: AppColors.primary,
                ),
                title: Text(_t('Share provider', 'مشاركة مقدم الرعاية')),
                onTap: () {
                  Navigator.pop(context);
                  _shareProvider();
                },
              ),
              ListTile(
                leading: Icon(
                  _favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: AppColors.primary,
                ),
                title: Text(_t('Toggle favorite', 'تبديل المفضلة')),
                onTap: () {
                  Navigator.pop(context);
                  _toggleFavorite();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareProvider() async {
    final text =
        '${_provider.fullName} · ${_provider.specialization} · CareLink';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      _notice(_t('Provider details copied.', 'تم نسخ تفاصيل مقدم الرعاية.'));
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

  BoxDecoration _cardDecoration(CarelinkPalette p) {
    return BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: p.stroke.withValues(alpha: 0.85)),
      boxShadow: [
        BoxShadow(
          color: p.cardShadowColor(p.isDark ? 0.20 : 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  String get _roleLabel {
    final role = _clean(_provider.role).toLowerCase();
    if (role == 'nurse') return _t('Nurse', 'ممرض');
    return _t('Physician', 'طبيب');
  }

  String? get _aboutText {
    final bio = _clean(_profile?.bio);
    return bio.isEmpty ? null : bio;
  }

  List<String> get _services => _clean(
    _provider.serviceType,
  ).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();

  AvailabilitySlot? get _selectedSlot {
    final index = _selectedTimeIndex;
    if (index == null ||
        index < 0 ||
        index >= _provider.availableSlots.length) {
      return null;
    }
    return _provider.availableSlots[index];
  }

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

  bool get _hasRecommendationData {
    final recommendation = widget.recommendation;
    if (recommendation == null || recommendation.isEmpty) return false;
    return _medicalMatch != null || _overallMatch != null;
  }

  int? get _medicalMatch {
    final raw = widget.recommendation?['medicalMatchScore'];
    if (raw is num) return (raw.toDouble() * 100).round().clamp(0, 99);
    final breakdown = widget.recommendation?['scoreBreakdown'];
    if (breakdown is Map) {
      final score = breakdown['medicalCompatibility'];
      if (score is num) return (score.toDouble() * 100).round().clamp(0, 99);
    }
    return null;
  }

  int? get _overallMatch {
    final raw = widget.recommendation?['matchPercentage'];
    if (raw is num) return raw.round().clamp(0, 99);
    final score = widget.recommendation?['finalScore'];
    if (score is num) return (score.toDouble() * 100).round().clamp(0, 99);
    return null;
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
}

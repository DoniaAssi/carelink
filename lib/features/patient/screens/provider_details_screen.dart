import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/patient_typography.dart';
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

  /// Accepted for route compatibility; recommendation details are not shown on
  /// this simplified provider profile.
  final Map<String, dynamic>? recommendation;

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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            _heroSection(p),
            const SizedBox(height: 12),
            _actionRow(p),
            const SizedBox(height: 14),
            _servicesSection(p),
            const SizedBox(height: 16),
            _bookingBar(p),
            if (_aboutText != null) ...[
              const SizedBox(height: 18),
              _aboutSection(p),
            ],
            if (_reviewCount > 0 || _reviews.isNotEmpty) ...[
              const SizedBox(height: 18),
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor(p.isDark ? 0.18 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatar(p),
              const SizedBox(width: 13),
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
                              fontSize: 20,
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
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
          _statsRow(p),
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
          size: 42,
        ),
      ),
    );
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(shape: BoxShape.circle, color: p.surfaceSoft),
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
                      valueColor: AlwaysStoppedAnimation<Color>(active ? color : AppColors.primary),
                    ),
                  )
                else
                  Icon(icon, size: 17, color: active ? color : AppColors.primary),
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
    final hasSlots = _orderedSlots.isNotEmpty;
    final enabled = patientId.isNotEmpty && hasSlots;
    final label = patientId.isEmpty
        ? _t('Login First', 'سجل الدخول أولاً')
        : !hasSlots
        ? _t('No available slots', 'لا توجد مواعيد متاحة')
        : _t('Book Now', 'احجز الآن');
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: SizedBox(
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
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 16, 0),
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
        return apt['providerUserId'] == _provider.userId || apt['providerId'] == _provider.userId;
      });

      if (!hasRelationship) {
        _notice(_t(
          'You can message a provider after sending a booking request or having an appointment with them.',
          'يمكنك مراسلة مقدم الرعاية بعد إرسال طلب حجز أو وجود موعد معه.',
        ));
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
      _notice(_t('Error checking relationship. Please try again.', 'حدث خطأ. يرجى المحاولة مرة أخرى.'));
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
    if (!_provider.isAvailable || _orderedSlots.isEmpty) {
      return _t('Availability not set', 'التوفر غير محدد');
    }
    return _availableDayLabel == _t('Available today', 'متاح اليوم')
        ? _t('Available Today', 'متاح اليوم')
        : _t('Available', 'متاح');
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

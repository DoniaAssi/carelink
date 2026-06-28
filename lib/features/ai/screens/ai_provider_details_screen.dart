import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder;
import 'package:carelink/core/theme_controller.dart';
import '../ai_slot_utils.dart';
import 'package:carelink/features/ai/provider_booking_eligibility.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/patient/screens/booking_screen.dart';
import 'package:carelink/features/patient/screens/chat_screen.dart';
import 'package:carelink/features/patient/utils/booking_service_helper.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/patient_favorites_service.dart';

/// Why-this-provider view and bridge into the standard booking flow.
class AiProviderDetailsScreen extends StatefulWidget {
  const AiProviderDetailsScreen({
    super.key,
    this.result,
    this.patientUserId,
    this.distanceKm,
    this.caseReason = '',
  });

  final AIRecommendationResult? result;
  final String? patientUserId;
  final double? distanceKm;
  final String caseReason;

  @override
  State<AiProviderDetailsScreen> createState() =>
      _AiProviderDetailsScreenState();
}

class _AiProviderDetailsScreenState extends State<AiProviderDetailsScreen> {
  AvailabilitySlot? _slot;
  AIRecommendationResult? _activeResult;
  ProviderModel? _freshProvider;
  String? _activePatientUserId;
  String _activeCaseReason = '';
  bool _bootstrapped = false;
  bool _isContinuing = false;
  bool _favorite = false;
  bool _favoriteBusy = false;
  bool _isCheckingRelationship = false;
  double _reviewAverage = 0;
  int _reviewCount = 0;
  final Map<int, int> _ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

  ProviderModel? get _p => _freshProvider ?? _activeResult?.provider;
  bool get _ar => Directionality.of(context) == TextDirection.rtl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      final routeArgs =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final res =
          widget.result ?? routeArgs?['result'] as AIRecommendationResult?;
      String patientId =
          widget.patientUserId ?? routeArgs?['patientUserId'] as String? ?? '';
      if (patientId == 'guest') patientId = '';
      final reason = widget.caseReason.isEmpty
          ? (routeArgs?['caseReason'] as String? ?? '')
          : widget.caseReason;

      if (patientId.isEmpty) {
        patientId = routeArgs?['userId'] as String? ?? '';
      }
      if (patientId == 'guest') patientId = '';

      setState(() {
        _activeResult = res;
        _activePatientUserId = patientId;
        _activeCaseReason = reason;

        if (res != null) {
          final slots = AiSlotUtils.sortedSlots(res.provider.availableSlots);
          _slot = slots.isNotEmpty ? slots.first : null;
        }
        _bootstrapped = true;
      });

      _loadSessionIfNeeded();
      if (res != null) {
        _loadProviderProfile(res.provider.userId);
        _loadRatings(res.provider.userId);
        _loadFavorite();
      }
    }
  }

  Future<void> _loadProviderProfile(String providerId) async {
    try {
      final data = await ApiService().getProviderById(
        providerId,
        realAvailability: true,
      );
      final provider = ProviderModel.fromJson(data);
      final slots = AiSlotUtils.sortedSlots(provider.availableSlots);
      if (!mounted) return;
      setState(() {
        _freshProvider = provider;
        _slot = slots.isNotEmpty ? slots.first : null;
      });
    } catch (_) {
      // Keep the provider supplied by the recommendation response.
    }
  }

  Future<void> _loadSessionIfNeeded() async {
    if (_activePatientUserId == null ||
        _activePatientUserId!.isEmpty ||
        _activePatientUserId == 'guest') {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('session_user_id') ?? '';
      if (savedId.isNotEmpty && mounted) {
        setState(() {
          _activePatientUserId = savedId;
        });
        await _loadFavorite();
      }
    }
  }

  Future<void> _loadFavorite() async {
    final patientId = _activePatientUserId?.trim() ?? '';
    final providerId = _p?.userId.trim() ?? '';
    if (patientId.isEmpty || providerId.isEmpty) return;
    final favorite = await PatientFavoritesService.isFavorite(
      patientId,
      providerId,
    );
    if (mounted) setState(() => _favorite = favorite);
  }

  Future<void> _toggleFavorite() async {
    final patientId = _activePatientUserId?.trim() ?? '';
    final providerId = _p?.userId.trim() ?? '';
    if (patientId.isEmpty || providerId.isEmpty || _favoriteBusy) return;
    final next = !_favorite;
    setState(() {
      _favorite = next;
      _favoriteBusy = true;
    });
    try {
      if (next) {
        await PatientFavoritesService.addFavorite(patientId, providerId);
      } else {
        await PatientFavoritesService.removeFavorite(patientId, providerId);
      }
    } catch (_) {
      if (mounted) setState(() => _favorite = !next);
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _loadRatings(String providerId) async {
    try {
      final data = await ApiService().getProviderRatingsAggregate(
        providerId,
        limit: 100,
      );
      final distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      final items = data['items'];
      if (items is List) {
        for (final item in items.whereType<Map>()) {
          final stars = (item['stars'] as num?)?.round();
          if (stars != null && distribution.containsKey(stars)) {
            distribution[stars] = distribution[stars]! + 1;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _reviewAverage =
            (data['averageRating'] as num?)?.toDouble() ??
            _p?.overallRating ??
            0;
        _reviewCount =
            (data['ratingsCount'] as num?)?.round() ?? _p?.ratingsCount ?? 0;
        _ratingDistribution
          ..clear()
          ..addAll(distribution);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviewAverage = _p?.overallRating ?? 0;
        _reviewCount = _p?.ratingsCount ?? 0;
      });
    }
  }

  Future<void> _continueBooking() async {
    final res = _activeResult;
    final p = _p;
    if (res == null || p == null || _isContinuing) return;

    final id = _activePatientUserId?.trim() ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('signIn'))));
      return;
    }
    if (_slot == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('noSlots'))));
      return;
    }

    final reason = _activeCaseReason.trim();

    setState(() => _isContinuing = true);
    try {
      final freshProvider = ProviderModel.fromJson(
        await ApiService().getProviderById(p.userId, realAvailability: true),
      );
      if (!ProviderBookingEligibility.canBook(freshProvider)) {
        if (mounted) Navigator.pop(context, true);
        return;
      }

      if (!mounted) return;
      final request =
          BookingServiceHelper.createRequestForProvider(
            provider: freshProvider,
            patientId: id,
          ).copyWith(
            patientReason: reason,
            symptoms: reason,
            bookingStatus: 'pending_payment',
          );

      final becameUnavailable = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => BookingScreen(request: request)),
      );
      if (becameUnavailable == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      final unavailable =
          message.contains('Status: 409') ||
          message.toLowerCase().contains('no longer available') ||
          message.toLowerCase().contains('already booked');
      if (unavailable) {
        Navigator.pop(context, true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? _t('bookingFailed') : message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }

  Future<void> _messageProvider() async {
    final patientId = _activePatientUserId?.trim() ?? '';
    final provider = _p;
    if (patientId.isEmpty || provider == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('signIn'))));
      return;
    }
    if (_isCheckingRelationship) return;
    setState(() => _isCheckingRelationship = true);
    try {
      final appointments = await ApiService().getAppointments(patientId);
      final history = await ApiService().getAppointmentHistory(patientId);
      final hasRelationship = [...appointments, ...history].any(
        (appointment) =>
            appointment['providerUserId'] == provider.userId ||
            appointment['providerId'] == provider.userId,
      );
      if (!hasRelationship) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_t('chatRequiresBooking'))));
        return;
      }
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            name: provider.fullName,
            userId: patientId,
            doctorId: provider.userId,
            currentUserId: patientId,
            patientUserId: patientId,
            providerUserId: provider.userId,
            peerImageUrl: provider.profileImageUrl,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('chatFailed'))));
    } finally {
      if (mounted) setState(() => _isCheckingRelationship = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        final palette = CarelinkPalette.of(context);
        final themeColor = palette.inkDark;
        final pageBgColor = palette.pageBg;
        final cardBgColor = palette.surface;
        final strokeColor = palette.stroke;
        const primaryColor = AppColors.primary;

        if (_bootstrapped && _activeResult == null) {
          return Directionality(
            textDirection: localeController.isArabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: PatientScaffold(
              backgroundColor: pageBgColor,
              appBar: PatientAppBar(title: _t('title')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _t('dataMissing'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(_t('goBack')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final p = _p!;
        final isDoctor = p.role.toLowerCase() == 'doctor';
        final specialty = _providerSpecialty(p);
        final distLabel = _distanceLabel(widget.distanceKm);
        final slotHint = _slot != null
            ? '${_day(_slot!.day)} ${_clock(_slot!.startTime)}'
            : (p.isAvailable
                  ? (_ar ? 'متاح اليوم' : 'Open today')
                  : (_ar ? 'مواعيد محدودة' : 'Limited slots'));

        return Directionality(
          textDirection: localeController.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: PatientScaffold(
            backgroundColor: pageBgColor,
            appBar: _detailsAppBar(palette),
            bottomNavigationBar: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isContinuing ? null : _continueBooking,
                        icon: _isContinuing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.calendar_month_rounded,
                                size: 19,
                              ),
                        label: Text(
                          _t('bookAppointment'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isCheckingRelationship
                          ? null
                          : _messageProvider,
                      icon: _isCheckingRelationship
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chat_bubble_rounded, size: 18),
                      label: Text(
                        _t('chat'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // Provider profile hero
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: palette.cardShadowColor(0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 104,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.primary.withValues(alpha: 0.09),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: profileAvatarOrPlaceholder(
                              imageUrl: p.profileImageUrl,
                              size: 140,
                              placeholderColor: AppColors.primary,
                              placeholderIcon: isDoctor
                                  ? Icons.medical_services_outlined
                                  : Icons.local_hospital_outlined,
                              iconSize: 42,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: themeColor,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: AppColors.primary,
                                    size: 19,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                specialty,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  Text(
                                    p.overallRating.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: themeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  ...List.generate(
                                    5,
                                    (index) => Icon(
                                      index < p.overallRating.round()
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: const Color(0xFFF2B036),
                                      size: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _profilePill(
                                    palette,
                                    Icons.circle,
                                    slotHint,
                                    p.isAvailable
                                        ? Colors.green
                                        : Colors.orange,
                                    smallIcon: true,
                                  ),
                                  _profilePill(
                                    palette,
                                    Icons.location_on_rounded,
                                    distLabel,
                                    AppColors.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Overall match
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.cardShadowColor(0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('aboutProvider'),
                          style: TextStyle(
                            color: themeColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _providerAbout(p, specialty),
                          style: TextStyle(
                            color: themeColor,
                            fontSize: 13,
                            height: 1.65,
                          ),
                        ),
                        if (_serviceTiles(p, palette).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(children: _serviceTiles(p, palette)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Three clear reasons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: strokeColor),
                      boxShadow: [
                        BoxShadow(
                          color: palette.cardShadowColor(0.045),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('mainReasons'),
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._recommendationReasonRows(palette),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ratingsCard(palette),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _detailsAppBar(CarelinkPalette palette) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: ColoredBox(
        color: palette.pageBg,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  _t('title'),
                  style: TextStyle(
                    color: palette.inkDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Positioned(
                  left: 4,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  child: IconButton(
                    onPressed: _favoriteBusy ? null : _toggleFavorite,
                    icon: Icon(
                      _favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profilePill(
    CarelinkPalette palette,
    IconData icon,
    String label,
    Color color, {
    bool smallIcon = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF5F7F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: smallIcon ? 8 : 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: palette.inkDark,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _providerAbout(ProviderModel provider, String specialty) {
    final facts = <String>[];
    if (specialty.trim().isNotEmpty) {
      facts.add(_ar ? 'التخصص: $specialty' : 'Specialty: $specialty');
    }
    final service = provider.serviceType.trim();
    if (service.isNotEmpty &&
        service.toLowerCase() != provider.specialization.trim().toLowerCase()) {
      facts.add(
        _ar ? 'الخدمة: ${_localizedSpecialty(service)}' : 'Service: $service',
      );
    }
    final years = provider.experienceYears;
    if (years != null && years >= 0) {
      facts.add(_ar ? 'سنوات الخبرة: $years' : 'Years of experience: $years');
    }
    if (facts.isEmpty) {
      return _ar
          ? 'لا تتوفر معلومات إضافية في ملف مقدم الرعاية حالياً.'
          : 'No additional profile information is currently available.';
    }
    return facts.join(_ar ? '، ' : ' • ');
  }

  List<Widget> _serviceTiles(ProviderModel provider, CarelinkPalette palette) {
    final services = provider.serviceType
        .split(RegExp(r'[,;|]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(4)
        .toList();
    return services
        .map(
          (service) => Expanded(
            child: _serviceTile(
              palette,
              _serviceIcon(service),
              _ar ? _localizedSpecialty(service) : service,
            ),
          ),
        )
        .toList();
  }

  IconData _serviceIcon(String service) {
    final value = service.toLowerCase();
    if (value.contains('wound') || value.contains('جرح')) {
      return Icons.healing_rounded;
    }
    if (value.contains('medic') || value.contains('دواء')) {
      return Icons.medication_rounded;
    }
    if (value.contains('heart') || value.contains('cardio')) {
      return Icons.monitor_heart_rounded;
    }
    if (value.contains('nurs') || value.contains('تمريض')) {
      return Icons.health_and_safety_rounded;
    }
    return Icons.medical_services_rounded;
  }

  Widget _serviceTile(CarelinkPalette palette, IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.inkDark,
            fontSize: 9.5,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _ratingsCard(CarelinkPalette palette) {
    final count = _reviewCount > 0 ? _reviewCount : (_p?.ratingsCount ?? 0);
    final average = _reviewAverage > 0
        ? _reviewAverage
        : (_p?.overallRating ?? 0);
    final maxCount = _ratingDistribution.values.fold<int>(
      0,
      (current, value) => value > current ? value : current,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.stroke),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadowColor(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                _t('ratings'),
                style: TextStyle(
                  color: palette.inkDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                average.toStringAsFixed(1),
                style: TextStyle(
                  color: palette.inkDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              ...List.generate(
                5,
                (index) => Icon(
                  index < average.round()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: const Color(0xFFF2B036),
                  size: 15,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '($count)',
                style: TextStyle(color: palette.inkMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var stars = 5; stars >= 1; stars--)
            _ratingBar(
              palette,
              stars,
              _ratingDistribution[stars] ?? 0,
              maxCount,
            ),
        ],
      ),
    );
  }

  Widget _ratingBar(
    CarelinkPalette palette,
    int stars,
    int count,
    int maxCount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              '$stars',
              style: TextStyle(
                color: stars == 1 ? Colors.red : palette.inkDark,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: maxCount == 0 ? 0 : count / maxCount,
                minHeight: 6,
                backgroundColor: palette.stroke.withValues(alpha: 0.7),
                valueColor: AlwaysStoppedAnimation<Color>(
                  stars == 1 ? Colors.red : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: TextStyle(color: palette.inkMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _recommendationReasonRows(CarelinkPalette palette) {
    final breakdown = _activeResult!.breakdown;
    final metrics = <(IconData, String, double)>[
      (
        Icons.health_and_safety_outlined,
        _ar ? 'التوافق الطبي' : 'Medical compatibility',
        breakdown.medicalCompatibility,
      ),
      (
        Icons.medical_services_outlined,
        _ar ? 'توافق التخصص' : 'Specialty match',
        breakdown.specialization,
      ),
      (
        Icons.schedule_rounded,
        _ar ? 'التوفر' : 'Availability',
        breakdown.availability,
      ),
      (
        Icons.location_on_outlined,
        _ar ? 'ملاءمة الموقع' : 'Location fit',
        breakdown.location,
      ),
      (
        Icons.star_outline_rounded,
        _ar ? 'التقييم' : 'Rating score',
        breakdown.rating,
      ),
    ];
    final rows = <Widget>[];
    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      rows.add(
        _reasonRow(
          palette,
          metric.$1,
          '${metric.$2}: ${(metric.$3 * 100).round()}%',
        ),
      );
      if (index != metrics.length - 1) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return rows;
  }

  Widget _reasonRow(CarelinkPalette palette, IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: Icon(icon, size: 19, color: AppColors.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.inkDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.primary,
          size: 20,
        ),
      ],
    );
  }

  String _providerSpecialty(ProviderModel provider) {
    final specialty = provider.specialization.trim();
    final invalid = {
      '',
      'doctor',
      'nurse',
      'provider',
      'null',
      'unknown',
      'carid',
    };
    if (!invalid.contains(specialty.toLowerCase())) {
      return _localizedSpecialty(specialty);
    }

    final service = provider.serviceType.trim();
    if (!invalid.contains(service.toLowerCase())) {
      return _localizedSpecialty(service);
    }
    return _ar ? 'مقدم رعاية عامة' : 'General Care Provider';
  }

  String _localizedSpecialty(String value) {
    if (!_ar) return value;
    const values = <String, String>{
      'home nursing': 'تمريض منزلي',
      'wound care': 'رعاية جروح',
      'general doctor': 'طب عام',
      'general care': 'رعاية عامة',
      'cardiology': 'أمراض القلب',
      'physiotherapy': 'علاج طبيعي',
      'elderly care': 'رعاية كبار السن',
    };
    return values[value.trim().toLowerCase()] ?? value;
  }

  String _distanceLabel(double? value) {
    if (value == null) return _ar ? 'غير محدد' : 'Unavailable';
    if (value < 1) {
      final meters = (value * 1000).round();
      return _ar ? '$meters م' : '$meters m';
    }
    final km = value.toStringAsFixed(1);
    return _ar ? '$km كم' : '$km km';
  }

  String _day(String day) {
    if (!_ar) return day.isEmpty ? 'Available' : day;
    const days = {
      'monday': 'الإثنين',
      'tuesday': 'الثلاثاء',
      'wednesday': 'الأربعاء',
      'thursday': 'الخميس',
      'friday': 'الجمعة',
      'saturday': 'السبت',
      'sunday': 'الأحد',
    };
    return days[day.trim().toLowerCase()] ?? 'متاح';
  }

  String _clock(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;
    final h = hour % 12 == 0 ? 12 : hour % 12;
    if (!_ar) {
      final period = hour >= 12 ? 'PM' : 'AM';
      return '$h:${minute.toString().padLeft(2, '0')} $period';
    }
    final period = hour >= 12 ? 'م' : 'ص';
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }

  String _t(String key) {
    final strings = _ar ? _arStrings : _enStrings;
    return strings[key] ?? _enStrings[key] ?? key;
  }
}

const _enStrings = <String, String>{
  'title': 'Care Provider Details',
  'match': 'match',
  'continue': 'Continue Booking',
  'privacy':
      'Your privacy is protected. We do not share your data with external parties.',
  'signIn': 'Please sign in as a patient to book.',
  'noSlots': 'No available slots for this provider.',
  'bookingFailed': 'Unable to start booking. Please try again.',
  'language': 'Change language',
  'theme': 'Change theme',
  'dataMissing': 'Provider recommendation details are missing or unavailable.',
  'goBack': 'Go Back',
  'overallMatch': 'Overall match',
  'shortExplanation': 'A strong choice for your care needs.',
  'showMore': 'Show more',
  'showLess': 'Show less',
  'matchScore': 'Match score',
  'mainReasons': 'Why we recommend this provider',
  'reasonCondition': 'Suitable for your condition',
  'reasonArea': 'Available in your area',
  'reasonRating': 'Well rated by patients',
  'reasonAvailability': 'Available at a suitable time',
  'aboutProvider': 'About the provider',
  'ratings': 'Ratings',
  'bookAppointment': 'Book appointment',
  'chat': 'Chat',
  'chatRequiresBooking':
      'You can message this provider after sending a booking request or having an appointment.',
  'chatFailed': 'Unable to open chat. Please try again.',
  'serviceConsultation': 'Consultation',
  'serviceFollowUp': 'Follow-up',
  'serviceDiagnosis': 'Assessment',
  'serviceMedication': 'Medication',
  'serviceDressings': 'Dressings',
  'servicePostOp': 'Post-op care',
  'serviceWounds': 'Wound care',
};

const _arStrings = <String, String>{
  'title': 'تفاصيل مقدم الرعاية',
  'match': 'توافق',
  'continue': 'متابعة الحجز',
  'privacy': 'خصوصيتك محمية، ولا نشارك بياناتك مع أي طرف خارجي.',
  'signIn': 'يرجى تسجيل الدخول كمريض لإتمام الحجز.',
  'noSlots': 'لا توجد مواعيد متاحة لهذا المقدم.',
  'bookingFailed': 'تعذر بدء الحجز. يرجى المحاولة مرة أخرى.',
  'language': 'تغيير اللغة',
  'theme': 'تغيير المظهر',
  'dataMissing': 'تفاصيل توصية مقدم الخدمة مفقودة أو غير متوفرة.',
  'goBack': 'العودة للخلف',
  'overallMatch': 'التوافق العام',
  'shortExplanation': 'خيار مناسب لاحتياجاتك الصحية.',
  'showMore': 'عرض المزيد',
  'showLess': 'عرض أقل',
  'matchScore': 'نسبة التوافق',
  'mainReasons': 'لماذا نوصي بهذا المقدم؟',
  'reasonCondition': 'مناسب لحالتك',
  'reasonArea': 'متاح في منطقتك',
  'reasonRating': 'تقييمه جيد',
  'reasonAvailability': 'متاح في الوقت المناسب',
  'aboutProvider': 'عن مقدم الرعاية',
  'ratings': 'التقييمات',
  'bookAppointment': 'احجز موعد',
  'chat': 'محادثة',
  'chatRequiresBooking':
      'يمكنك مراسلة مقدم الرعاية بعد إرسال طلب حجز أو وجود موعد معه.',
  'chatFailed': 'تعذر فتح المحادثة. حاول مرة أخرى.',
  'serviceConsultation': 'استشارة طبية',
  'serviceFollowUp': 'متابعة الحالة',
  'serviceDiagnosis': 'تقييم الحالة',
  'serviceMedication': 'إعطاء الأدوية',
  'serviceDressings': 'تغيير الضمادات',
  'servicePostOp': 'العناية بعد العمليات',
  'serviceWounds': 'رعاية الجروح',
};

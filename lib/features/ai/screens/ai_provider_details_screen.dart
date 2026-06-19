import 'package:flutter/material.dart';
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
import 'package:carelink/features/ai/widgets/ai_score_breakdown.dart';
import 'package:carelink/features/patient/utils/booking_service_helper.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';

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
  String? _activePatientUserId;
  String _activeCaseReason = '';
  bool _bootstrapped = false;
  bool _isContinuing = false;
  bool _showMore = false;

  ProviderModel? get _p => _activeResult?.provider;
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
      }
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
      final request = BookingServiceHelper.createRequestForProvider(
        provider: freshProvider,
        patientId: id,
      ).copyWith(
        patientReason: reason,
        symptoms: reason,
        bookingStatus: 'pending_payment',
      );

      final becameUnavailable = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => BookingScreen(
            request: request,
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        final palette = CarelinkPalette.of(context);
        final themeColor = palette.inkDark;
        final helperColor = palette.inkMuted;
        final pageBgColor = palette.pageBg;
        final cardBgColor = palette.surface;
        final strokeColor = palette.stroke;
        const primaryColor = AppColors.primary;

        if (_bootstrapped && _activeResult == null) {
          return Directionality(
            textDirection: localeController.isArabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Scaffold(
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
          child: Scaffold(
            backgroundColor: pageBgColor,
            appBar: PatientAppBar(title: _t('title')),
            bottomNavigationBar: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: palette.isDark ? 0.24 : 0.2,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.65,
                      ),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isContinuing ? null : _continueBooking,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _t('continue'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 9),
                        if (_isContinuing)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(
                            _ar
                                ? Icons.arrow_back_rounded
                                : Icons.arrow_forward_rounded,
                            size: 19,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // 1. Compact Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: strokeColor),
                      boxShadow: [
                        BoxShadow(
                          color: palette.cardShadowColor(0.055),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.09),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.24),
                            ),
                          ),
                          child: ClipOval(
                            child: profileAvatarOrPlaceholder(
                              imageUrl: p.profileImageUrl,
                              size: 68,
                              placeholderColor: AppColors.primary,
                              placeholderIcon: isDoctor
                                  ? Icons.medical_services_outlined
                                  : Icons.local_hospital_outlined,
                              iconSize: 31,
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _ar ? 'موصى به' : 'Recommended',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                specialty,
                                style: TextStyle(
                                  color: helperColor,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFF2B036),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    p.overallRating.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: themeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: primaryColor,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    distLabel,
                                    style: TextStyle(
                                      color: helperColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.event_available_rounded,
                                    color: primaryColor,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      slotHint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: helperColor,
                                        fontSize: 12,
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
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.1),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: AppColors.primary,
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _t('overallMatch'),
                                    style: TextStyle(
                                      color: helperColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _overallMatchLabel(
                                      _activeResult!.matchPercentage,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _t('shortExplanation'),
                                    style: TextStyle(
                                      color: themeColor,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() => _showMore = !_showMore);
                              },
                              child: Text(
                                _t(_showMore ? 'showLess' : 'showMore'),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 200),
                          crossFadeState: _showMore
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: const SizedBox(width: double.infinity),
                          secondChild: Column(
                            children: [
                              Divider(height: 24, color: strokeColor),
                              Row(
                                children: [
                                  Text(
                                    _t('matchScore'),
                                    style: TextStyle(
                                      color: helperColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_activeResult!.matchPercentage}%',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              AiScoreBreakdown(
                                breakdown: _activeResult!.breakdown,
                                isArabic: _ar,
                              ),
                            ],
                          ),
                        ),
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
                        _reasonRow(
                          palette,
                          Icons.health_and_safety_outlined,
                          _t('reasonCondition'),
                        ),
                        const SizedBox(height: 10),
                        _reasonRow(
                          palette,
                          Icons.location_on_outlined,
                          _t('reasonArea'),
                        ),
                        const SizedBox(height: 10),
                        _reasonRow(
                          palette,
                          Icons.star_outline_rounded,
                          _t('reasonRating'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
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

  String _overallMatchLabel(int score) {
    if (score >= 85) return _ar ? 'توافق ممتاز' : 'Excellent Match';
    if (score >= 70) return _ar ? 'توافق جيد جداً' : 'Very Good Match';
    if (score >= 50) return _ar ? 'توافق جيد' : 'Good Match';
    return _ar ? 'توافق متوسط' : 'Moderate Match';
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
    if (!invalid.contains(specialty.toLowerCase())) return specialty;

    final service = provider.serviceType.trim();
    if (!invalid.contains(service.toLowerCase())) return service;
    return _ar ? 'مقدم رعاية عامة' : 'General Care Provider';
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
  'title': 'Why this provider?',
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
};

const _arStrings = <String, String>{
  'title': 'لماذا هذا المقدم؟',
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
};

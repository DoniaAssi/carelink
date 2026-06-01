import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/ai/ai_slot_utils.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/widgets/ai_score_breakdown.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';

/// Why-this-provider view and bridge into the existing AI booking flow.
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

  ProviderModel? get _p => _activeResult?.provider;
  bool get _ar => Directionality.of(context) == TextDirection.rtl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      final routeArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final res = widget.result ?? routeArgs?['result'] as AIRecommendationResult?;
      String patientId = widget.patientUserId ?? routeArgs?['patientUserId'] as String? ?? '';
      final reason = widget.caseReason.isEmpty ? (routeArgs?['caseReason'] as String? ?? '') : widget.caseReason;

      if (patientId.isEmpty) {
        patientId = routeArgs?['userId'] as String? ?? '';
      }

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
    if (_activePatientUserId == null || _activePatientUserId!.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('session_user_id') ?? '';
      if (savedId.isNotEmpty && mounted) {
        setState(() {
          _activePatientUserId = savedId;
        });
      }
    }
  }

  void _continueBooking() {
    final res = _activeResult;
    final p = _p;
    if (res == null || p == null) return;

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

    final slotDate = AiSlotUtils.nextOccurrence(_slot!.day);
    final dateStr = slotDate.toIso8601String().split('T').first;
    final reason = _activeCaseReason.trim();

    Navigator.pushNamed(
      context,
      '/ai-appointment',
      arguments: {
        'request': BookingRequestModel(
          patientId: id,
          providerId: p.userId,
          providerName: p.fullName,
          providerRole: p.role,
          specialization: p.specialization,
          serviceType: p.serviceType.isNotEmpty
              ? p.serviceType.split(',').first.trim()
              : (_ar ? 'استشارة طبية' : 'Doctor consultation'),
          appointmentDate: dateStr,
          appointmentTime: _slot!.startTime,
          visitLatitude: p.gpsLat ?? 0,
          visitLongitude: p.gpsLng ?? 0,
          visitAddress: '',
          locationNote: '',
          patientReason: reason,
          symptoms: reason,
          isUrgent: false,
          additionalNotes: '',
          price: p.consultationFee ?? 65,
          paymentMethod: '',
          paymentStatus: 'unpaid',
          bookingStatus: 'pending',
        ),
        'aiResult': res,
        'displayDate': _readableDate(slotDate),
        'displayTime': _timeRange(_slot!.startTime, _slot!.endTime),
        'selectedProvider': p,
        'patientRequest': reason,
        'recommendedSpecialization': p.specialization,
        'userId': id,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final themeColor = colorScheme.onSurface;
        final helperColor = colorScheme.onSurfaceVariant;
        final pageBgColor = colorScheme.surface;
        final cardBgColor = colorScheme.surfaceContainer;
        final strokeColor = colorScheme.outlineVariant;
        final primaryColor = colorScheme.primary;

        if (_bootstrapped && _activeResult == null) {
          return Directionality(
            textDirection: localeController.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              backgroundColor: pageBgColor,
              appBar: PatientAppBar(
                title: _t('title'),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _t('dataMissing'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColor),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        final specialty = p.specialization.isEmpty ? p.role : p.specialization;
        final distLabel = _distanceLabel(widget.distanceKm);
        final slotHint = _slot != null ? '${_day(_slot!.day)} ${_clock(_slot!.startTime)}' : (p.isAvailable ? (_ar ? 'متاح اليوم' : 'Open today') : (_ar ? 'مواعيد محدودة' : 'Limited slots'));

        return Directionality(
          textDirection: localeController.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: pageBgColor,
            appBar: PatientAppBar(
              title: _t('title'),
            ),
            bottomNavigationBar: Container(
              color: pageBgColor,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: SafeArea(
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal, // Primary teal as requested
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _continueBooking,
                    icon: const Icon(Icons.calendar_month_rounded, size: 20),
                    label: Text(
                      _t('continue'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // 1. Compact Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: strokeColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipOval(
                          child: Image.asset(
                            isDoctor
                                ? 'assets/images/doctorportrait.jpg'
                                : 'assets/images/nursemedical.jpg',
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 72,
                                height: 72,
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  isDoctor ? Icons.person_rounded : Icons.medical_services_rounded,
                                  color: helperColor,
                                  size: 36,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2BB673).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_activeResult!.matchPercentage}% ${_ar ? 'توافق' : 'match'}',
                                      style: const TextStyle(
                                        color: Color(0xFF259c60),
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
                                  const Icon(Icons.star_rounded, color: Color(0xFFF2B036), size: 16),
                                  const SizedBox(width: 2),
                                  Text(
                                    p.overallRating.toStringAsFixed(1),
                                    style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.location_on_outlined, color: primaryColor, size: 15),
                                  const SizedBox(width: 2),
                                  Text(
                                    distLabel,
                                    style: TextStyle(color: helperColor, fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.event_available_rounded, color: primaryColor, size: 15),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      slotHint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: helperColor, fontSize: 12),
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
                  const SizedBox(height: 20),

                  // 2. Explanation Title Section
                  Text(
                    _t('explanationTitle'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('explanationSubtitle'),
                    style: TextStyle(
                      fontSize: 13,
                      color: helperColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Score Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: strokeColor),
                    ),
                    child: AiScoreBreakdown(
                      breakdown: _activeResult!.breakdown,
                      isArabic: _ar,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Privacy Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: Colors.teal,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _t('privacy'),
                            style: TextStyle(
                              color: themeColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
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

  String _distanceLabel(double? value) {
    if (value == null) return _ar ? 'غير محدد' : 'Unknown';
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

  String _timeRange(String start, String end) {
    return '${_clock(start)} - ${_clock(end)}';
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

  String _readableDate(DateTime d) {
    if (!_ar) return AiSlotUtils.formatReadable(d);
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يونيو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    const days = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return '${days[d.weekday - 1]}، ${d.day} ${months[d.month - 1]} ${d.year}';
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
  'privacy': 'Your privacy is protected. We do not share your data with external parties.',
  'signIn': 'Please sign in as a patient to book.',
  'noSlots': 'No available slots for this provider.',
  'language': 'Change language',
  'theme': 'Change theme',
  'dataMissing': 'Provider recommendation details are missing or unavailable.',
  'goBack': 'Go Back',
  'explanationTitle': 'Why did we recommend this provider?',
  'explanationSubtitle': 'Compatibility score calculated based on your condition, location, and health profile.',
};

const _arStrings = <String, String>{
  'title': 'لماذا هذا المقدم؟',
  'match': 'توافق',
  'continue': 'متابعة الحجز',
  'privacy': 'خصوصيتك محمية، ولا نشارك بياناتك مع أي طرف خارجي.',
  'signIn': 'يرجى تسجيل الدخول كمريض لإتمام الحجز.',
  'noSlots': 'لا توجد مواعيد متاحة لهذا المقدم.',
  'language': 'تغيير اللغة',
  'theme': 'تغيير المظهر',
  'dataMissing': 'تفاصيل توصية مقدم الخدمة مفقودة أو غير متوفرة.',
  'goBack': 'العودة للخلف',
  'explanationTitle': 'لماذا رشحنا هذا المقدم؟',
  'explanationSubtitle': 'تم حساب التوافق بناءً على حالتك وموقعك واحتياجاتك الصحية',
};

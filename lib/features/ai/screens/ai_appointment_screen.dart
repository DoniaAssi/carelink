import 'package:flutter/material.dart';

import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';
import 'package:carelink/features/ai/widgets/appointment_summary_card.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';

/// Review visit reason, fee, and confirm booking + payment state for the AI flow.
class AiAppointmentScreen extends StatefulWidget {
  const AiAppointmentScreen({
    super.key,
    this.request,
    this.aiResult,
    this.displayDate = '',
    this.displayTime = '',
  });

  final BookingRequestModel? request;
  final AIRecommendationResult? aiResult;
  final String displayDate;
  final String displayTime;

  @override
  State<AiAppointmentScreen> createState() => _AiAppointmentScreenState();
}

class _AiAppointmentScreenState extends State<AiAppointmentScreen> {
  bool _busy = false;
  final _api = ApiService();

  BookingRequestModel? _activeRequest;
  AIRecommendationResult? _activeAiResult;
  String _activeDisplayDate = '';
  String _activeDisplayTime = '';
  bool _bootstrapped = false;

  bool get _ar => Directionality.of(context) == TextDirection.rtl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      final routeArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final req = widget.request ?? routeArgs?['request'] as BookingRequestModel?;
      final res = widget.aiResult ?? routeArgs?['aiResult'] as AIRecommendationResult?;
      final date = widget.displayDate.isEmpty ? (routeArgs?['displayDate'] as String? ?? '') : widget.displayDate;
      final time = widget.displayTime.isEmpty ? (routeArgs?['displayTime'] as String? ?? '') : widget.displayTime;

      setState(() {
        _activeRequest = req;
        _activeAiResult = res;
        _activeDisplayDate = date;
        _activeDisplayTime = time;
        _bootstrapped = true;
      });
    }
  }

  Future<void> _confirm() async {
    final r = _activeRequest;
    if (r == null) return;

    setState(() => _busy = true);
    try {
      final booking = await _api.createBooking(
        patientId: r.patientId,
        providerId: r.providerId,
        date: r.appointmentDate,
        time: r.appointmentTime,
        notes: r.composedNotes,
        serviceType: r.serviceType,
        visitLatitude: r.visitLatitude,
        visitLongitude: r.visitLongitude,
        visitAddress: r.visitAddress,
        locationNote: r.locationNote,
        symptoms: r.symptoms,
        isUrgent: r.isUrgent,
        additionalNotes: r.additionalNotes,
        paymentMethod: 'card',
        paymentStatus: 'paid',
      );
      final appointmentId = (booking['appointmentId'] ?? '').toString();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(_t('successTitle')),
            content: Text(
              appointmentId.isEmpty
                  ? _t('storedDemo')
                  : _t('confirmedMsg').replaceAll('{id}', appointmentId),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/ai-booking-confirmed',
        arguments: {
          'request': r,
          'appointmentId': appointmentId.isEmpty ? 'demo_${DateTime.now().millisecondsSinceEpoch}' : appointmentId,
          'displayDate': _activeDisplayDate,
          'displayTime': _activeDisplayTime,
          'patientUserId': r.patientId,
          'selectedProvider': _activeAiResult?.provider,
          'userId': r.patientId,
        },
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(_t('offlineTitle')),
            content: Text(_t('offlineDesc')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_t('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
                  Navigator.pushReplacementNamed(
                    context,
                    '/ai-booking-confirmed',
                    arguments: {
                      'request': _activeRequest,
                      'appointmentId': id,
                      'displayDate': _activeDisplayDate,
                      'displayTime': _activeDisplayTime,
                      'patientUserId': _activeRequest!.patientId,
                      'selectedProvider': _activeAiResult?.provider,
                      'userId': _activeRequest!.patientId,
                    },
                  );
                },
                child: Text(_t('demoConfirm')),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        final dark = themeController.isDark;
        final themeColor = dark ? Colors.white : AiFlowTheme.ink;
        final pageBgColor = dark ? Colors.grey[900]! : AiFlowTheme.pageBg;
        final cardBgColor = dark ? Colors.grey[850]! : Colors.white;
        final strokeColor = dark ? Colors.grey.shade700 : AiFlowTheme.cardStroke;
        final helperColor = dark ? Colors.grey.shade400 : AiFlowTheme.inkMuted;

        // Defensive layout when necessary arguments are missing (such as direct web URLs)
        if (_bootstrapped && (_activeRequest == null || _activeAiResult == null)) {
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
                          backgroundColor: AiFlowTheme.primaryBlue,
                          foregroundColor: Colors.white,
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

        final r = _activeRequest!;
        final fee = r.totalAmount;

        return Directionality(
          textDirection: localeController.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: pageBgColor,
            appBar: PatientAppBar(
              title: _t('title'),
            ),
            bottomNavigationBar: Container(
              color: dark ? Colors.grey[850]! : Colors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AiFlowTheme.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _busy ? null : _confirm,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _t('confirmPay'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppointmentSummaryCard(
                  provider: _activeAiResult!.provider,
                  dateLabel: _activeDisplayDate,
                  timeLabel: _activeDisplayTime,
                  reason: r.patientReason.trim().isEmpty
                      ? (_ar ? 'استشارة عامة' : 'General consultation')
                      : r.patientReason.trim(),
                  priceLabel: '\$${fee.toStringAsFixed(0)}',
                ),
                const SizedBox(height: 18),
                Text(
                  _t('paymentDetails'),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: strokeColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('pspTitle'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t('pspDesc'),
                        style: TextStyle(
                          fontSize: 12,
                          color: helperColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _t(String key) {
    final strings = localeController.isArabic ? _arStrings : _enStrings;
    return strings[key] ?? _enStrings[key] ?? key;
  }
}

const _enStrings = <String, String>{
  'title': 'Appointment Details',
  'paymentDetails': 'Payment details',
  'confirmPay': 'Confirm & pay',
  'pspTitle': 'CareLink secure checkout (demo)',
  'pspDesc': 'We record a paid status for prototyping. Integrate your PSP in production.',
  'successTitle': 'Payment successful',
  'storedDemo': 'Booking stored locally for demo.',
  'confirmedMsg': 'Appointment {id} confirmed.',
  'offlineTitle': 'Offline / server unavailable',
  'offlineDesc': 'Proceed with a local demo confirmation so your graduation flow stays usable without the API.',
  'cancel': 'Cancel',
  'demoConfirm': 'Demo confirm',
  'dataMissing': 'Booking request details are missing or unavailable.',
  'goBack': 'Go Back',
};

const _arStrings = <String, String>{
  'title': 'تفاصيل الحجز',
  'paymentDetails': 'تفاصيل الدفع',
  'confirmPay': 'تأكيد ودفع',
  'pspTitle': 'بوابة دفع كيرلينك الآمنة (تجريبي)',
  'pspDesc': 'نقوم بتسجيل حالة الدفع لأغراض العرض التوضيحي. قم بدمج بوابة الدفع الخاصة بك في الإنتاج.',
  'successTitle': 'تم الدفع بنجاح',
  'storedDemo': 'تم حفظ الحجز محليًا للعرض.',
  'confirmedMsg': 'تم تأكيد الموعد {id}.',
  'offlineTitle': 'غير متصل / الخادم غير متاح',
  'offlineDesc': 'تابع بتأكيد محلي تجريبي لتجربة التدفق بدون الاتصال بالخادم.',
  'cancel': 'إلغاء',
  'demoConfirm': 'تأكيد تجريبي',
  'dataMissing': 'تفاصيل طلب الحجز مفقودة أو غير متوفرة.',
  'goBack': 'العودة للخلف',
};

import 'package:flutter/material.dart';

import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/ai/recommendation/ai_recommendation_repository.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';

import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';
import 'package:carelink/features/patient/screens/medical_records_screen.dart';
import 'package:carelink/features/patient/widgets/patient_navigation_shell.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/booking_request_model.dart';

/// Success step with navigation into the longitudinal medical record.
class AiBookingConfirmedScreen extends StatelessWidget {
  const AiBookingConfirmedScreen({
    super.key,
    this.request,
    this.appointmentId = '',
    this.displayDate = '',
    this.displayTime = '',
    this.patientUserId = '',
  });

  final BookingRequestModel? request;
  final String appointmentId;
  final String displayDate;
  final String displayTime;
  final String patientUserId;

  Future<void> _simulateVisitReport(BuildContext context, String patientId, String apptId, String providerName) async {
    final store = AiMedicalRecordLocalStore();
    final entry = MedicalRecordEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientId,
      appointmentId: apptId,
      uploadedBy: 'doctor',
      type: MedicalRecordEntryType.visitReport,
      title: 'Visit summary — $providerName',
      description: 'Home / telehealth encounter completed (demo).',
      diagnosis: 'Stable angina — continue cardiology follow-up',
      notes:
          'Vitals reviewed. Patient educated on symptoms. See attached ECG image in production.',
      prescription: 'Continue existing cardiac meds — no change today.',
      attachments: const [],
      createdAt: DateTime.now(),
      usedByAi: true,
      privateLabel: true,
      uploadedAfterVisit: true,
    );
    await store.add(patientId, entry);
    await store.appendProfileBoost(
      patientId,
      'follow-up cardiology chest pain stable visit report',
    );
    if (context.mounted) {
      final isArabic = localeController.isArabic;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم حفظ تقرير الزيارة — سيأخذ ترتيب الذكاء الاصطناعي مستقبلاً هذا السجل بعين الاعتبار.'
                : 'Visit report stored — future AI ranking will weigh this continuity.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final r = request ?? routeArgs?['request'] as BookingRequestModel?;
    final activeAppointmentId = appointmentId.isEmpty ? (routeArgs?['appointmentId'] as String? ?? '') : appointmentId;
    final activeDisplayDate = displayDate.isEmpty ? (routeArgs?['displayDate'] as String? ?? '') : displayDate;
    final activeDisplayTime = displayTime.isEmpty ? (routeArgs?['displayTime'] as String? ?? '') : displayTime;
    final activePatientUserId = patientUserId.isEmpty ? (routeArgs?['patientUserId'] as String? ?? routeArgs?['userId'] as String? ?? '') : patientUserId;

    return AnimatedBuilder(
      animation: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        final dark = themeController.isDark;
        final themeColor = dark ? Colors.white : AiFlowTheme.ink;
        final pageBgColor = dark ? Colors.grey[900]! : AiFlowTheme.pageBg;
        final cardBgColor = dark ? Colors.grey[850]! : Colors.white;
        final strokeColor = dark ? Colors.grey.shade700 : AiFlowTheme.cardStroke;
        final helperColor = dark ? Colors.grey.shade400 : AiFlowTheme.inkMuted;
        final isArabic = localeController.isArabic;

        // Defensive state check for missing request objects
        if (r == null || activePatientUserId.isEmpty) {
          return Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              backgroundColor: pageBgColor,
              appBar: PatientAppBar(
                title: _t('title', isArabic),
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
                        isArabic ? 'تفاصيل التأكيد مفقودة أو غير متوفرة.' : 'Booking confirmation details are missing or unavailable.',
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
                        onPressed: () {
                          Navigator.pushAndRemoveUntil<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PatientNavigationShell(
                                userId: activePatientUserId.isNotEmpty ? activePatientUserId : '',
                                initialTab: 0,
                              ),
                            ),
                            (_) => false,
                          );
                        },
                        child: Text(isArabic ? 'الذهاب للرئيسية' : 'Go to Home'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              Navigator.pushAndRemoveUntil<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientNavigationShell(
                    userId: activePatientUserId,
                    initialTab: 0,
                  ),
                ),
                (_) => false,
              );
            },
            child: Scaffold(
              backgroundColor: pageBgColor,
              appBar: PatientAppBar(
                title: _t('title', isArabic),
                leading: IconButton(
                  icon: Icon(
                    Icons.home_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientNavigationShell(
                          userId: activePatientUserId,
                          initialTab: 0,
                        ),
                      ),
                      (_) => false,
                    );
                  },
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 56,
                    color: AiFlowTheme.primaryBlue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('confirmedHeadline', isArabic),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('ref', isArabic).replaceAll('{id}', activeAppointmentId),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: helperColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: strokeColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row(_t('provider', isArabic), r.providerName, themeColor, helperColor),
                        _row(_t('specialty', isArabic), r.specialization, themeColor, helperColor),
                        _row(_t('when', isArabic), '$activeDisplayDate · $activeDisplayTime', themeColor, helperColor),
                        _row(_t('locationType', isArabic), _t('locationVal', isArabic), themeColor, helperColor),
                        _row(
                          _t('visitLocation', isArabic),
                          r.visitAddress.trim().isEmpty
                              ? _t('visitLocationVal', isArabic)
                              : r.visitAddress,
                          themeColor,
                          helperColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => _simulateVisitReport(context, activePatientUserId, activeAppointmentId, r.providerName),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AiFlowTheme.primaryBlue,
                      side: const BorderSide(color: AiFlowTheme.primaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _t('simulateCTA', isArabic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AiFlowTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicalRecordsScreen(
                            patientId: activePatientUserId,
                          ),
                        ),
                      );
                    },
                    child: Text(_t('medicalRecordCTA', isArabic)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientNavigationShell(
                            userId: activePatientUserId,
                            initialTab: 0,
                          ),
                        ),
                        (_) => false,
                      );
                    },
                    child: Text(_t('homeCTA', isArabic)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/find-provider',
                        arguments: {'userId': activePatientUserId},
                      );
                    },
                    child: Text(_t('findAnotherCTA', isArabic)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(String k, String v, Color themeColor, Color helperColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              k,
              style: TextStyle(
                color: helperColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(fontWeight: FontWeight.w800, color: themeColor),
            ),
          ),
        ],
      ),
    );
  }

  String _t(String key, bool isArabic) {
    final strings = isArabic ? _arStrings : _enStrings;
    return strings[key] ?? _enStrings[key] ?? key;
  }
}

const _enStrings = <String, String>{
  'title': 'Booking confirmed',
  'confirmedHeadline': 'Your appointment is confirmed',
  'ref': 'Ref: {id}',
  'provider': 'Provider',
  'specialty': 'Specialty',
  'when': 'When',
  'locationType': 'Location type',
  'locationVal': 'Home visit (CareLink demo)',
  'visitLocation': 'Visit location',
  'visitLocationVal': 'Address collected in production flow',
  'simulateCTA': 'Simulate provider visit report (demo)',
  'medicalRecordCTA': 'Go to medical record',
  'homeCTA': 'Back to home',
  'findAnotherCTA': 'Find another provider',
};

const _arStrings = <String, String>{
  'title': 'تم تأكيد الحجز',
  'confirmedHeadline': 'تم تأكيد موعدك بنجاح',
  'ref': 'الرقم المرجعي: {id}',
  'provider': 'مقدم الرعاية',
  'specialty': 'التخصص',
  'when': 'الوقت',
  'locationType': 'نوع الموقع',
  'locationVal': 'زيارة منزلية (عرض كيرلينك)',
  'visitLocation': 'موقع الزيارة',
  'visitLocationVal': 'يتم جمع العنوان في تدفق الإنتاج',
  'simulateCTA': 'محاكاة تقرير مقدم الرعاية (تجريبي)',
  'medicalRecordCTA': 'الذهاب إلى السجل الطبي',
  'homeCTA': 'العودة للرئيسية',
  'findAnotherCTA': 'البحث عن مقدم آخر',
};

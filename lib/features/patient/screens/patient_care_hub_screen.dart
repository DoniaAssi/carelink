import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/features/patient/screens/chat_screen.dart';
import 'package:carelink/shared/services/patient_recent_chats_service.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/features/patient/widgets/patient_navigation_shell.dart';
import 'booking_details_screen.dart';

class PatientCareHubScreen extends StatefulWidget {
  const PatientCareHubScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<PatientCareHubScreen> createState() => _PatientCareHubScreenState();
}

class _PatientCareHubScreenState extends State<PatientCareHubScreen> {
  final ApiService _api = ApiService();
  final MedicalRecordService _recordService = MedicalRecordService();

  bool _loading = true;
  List<AppointmentModel> _activeBookings = [];
  List<Map<String, dynamic>> _latestRecords = [];
  List<Map<String, dynamic>> _recentChats = [];
  Map<String, dynamic>? _latestVisitReport;
  
  final Map<String, String> _providerPhones = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    try {
      if (widget.patientUserId.trim().isEmpty) {
        setState(() => _loading = false);
        return;
      }
      
      // 1. Active Bookings
      debugPrint('--- MY CARE DEBUG ---');
      debugPrint('Patient UID: ${widget.patientUserId}');
      
      final rawBookings = await _api.getAppointments(widget.patientUserId);
      final allBookings = rawBookings.map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>)).toList();
      debugPrint('Total appointments fetched: ${allBookings.length}');
      
      for (final b in allBookings) {
        debugPrint('Appt ID: ${b.appointmentId} | Status: ${b.status} | Provider: ${b.providerName} | Service: ${b.specialization} | Date: ${b.scheduledAt}');
      }
      
      final activeStatuses = ['accepted', 'confirmed', 'scheduled', 'in_progress'];
      final pendingStatuses = ['pending', 'request_sent'];
      
      var activeList = allBookings.where((b) => activeStatuses.contains(b.status.toLowerCase())).toList();
      
      if (activeList.isEmpty) {
        activeList = allBookings.where((b) => pendingStatuses.contains(b.status.toLowerCase())).toList();
      }
      
      _activeBookings = activeList;
      
      if (_activeBookings.isNotEmpty) {
        final b = _activeBookings.first;
        debugPrint('Selected Active Booking: ${b.appointmentId} (${b.status})');
      } else {
        debugPrint('No active or pending bookings found.');
      }
      
      // 2. Medical Records
      final rawRecords = await _recordService.listForPatient(
        widget.patientUserId, 
        requesterUserId: widget.patientUserId, 
        requesterRole: 'patient',
      );
      
      rawRecords.sort((a, b) {
        final ta = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      
      _latestRecords = rawRecords.take(3).toList();
      
      final visitReports = rawRecords.where((r) => r['type'] == 'visit_report' || r['type'] == 'visitReport' || (r['category']?.toString().toLowerCase().contains('report') ?? false)).toList();
      if (visitReports.isNotEmpty) {
        _latestVisitReport = visitReports.first;
      }
      
      // 3. Provider Phones
      for (final b in _activeBookings) {
        if (b.providerUserId.isNotEmpty && !_providerPhones.containsKey(b.providerUserId)) {
          try {
             final p = await _api.getProviderById(b.providerUserId);
             if (p['phone'] != null) {
               _providerPhones[b.providerUserId] = p['phone'].toString();
             }
          } catch (_) {}
        }
      }

      final chats = await PatientRecentChatsService.getRecentChats();

      if (mounted) {
        setState(() {
          _recentChats = chats;
          _loading = false;
        });
      }
    } catch (e) {
      // Allow UI to build with empty state on error
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool get _isArabic => localeController.isArabic;
  String _t(String en, String ar) => _isArabic ? ar : en;

  void _handleCallProvider(String providerId) async {
    final phone = _providerPhones[providerId];
    if (phone != null && phone.trim().isNotEmpty) {
      final Uri launchUri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t('Could not launch dialer.', 'تعذر فتح تطبيق الاتصال.'))),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Provider phone number is not available.', 'رقم هاتف مقدم الرعاية غير متوفر.'))),
        );
      }
    }
  }

  void _handleMessageProvider(String providerId, String providerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          userId: widget.patientUserId,
          doctorId: providerId,
          name: providerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBg,
      // SECTION 1: HEADER
      appBar: const PatientTopActions(
        showBack: false,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadData,
        child: _loading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SECTION 2: ACTIVE CARE CARD
                  _buildActiveCareCard(p),
                  const SizedBox(height: 20),
                  
                  // SECTION 2.5: MESSAGES
                  _buildMessagesSection(p),
                  const SizedBox(height: 20),
                  
                  // Only show plan & timeline if there's an active booking
                  if (_activeBookings.isNotEmpty) ...[
                    // SECTION 3: CARE PROGRESS TIMELINE
                    _buildCareProgressTimeline(p, _activeBookings.first),
                    const SizedBox(height: 20),
                    
                    // SECTION 4: CARE PLAN
                    _buildCarePlan(p, _activeBookings.first),
                    const SizedBox(height: 20),
                  ],

                  // SECTION 5: LATEST PROVIDER NOTE
                  _buildLatestProviderNote(p),
                  const SizedBox(height: 20),
                  
                  // SECTION 6: MEDICAL RECORDS SHORTCUT
                  _buildMedicalRecordsShortcut(p),
                  const SizedBox(height: 20),
                  
                  // SECTION 7: AI CARE INSIGHT
                  _buildCareInsight(p),
                  const SizedBox(height: 24),
                  
                  // SECTION 8: EMERGENCY HELP CARD
                  _buildEmergencyHelpCard(p),
                ],
              ),
            ),
      ),
    );
  }

  // ==========================================
  // SECTION 2: ACTIVE CARE CARD
  // ==========================================
  Widget _buildActiveCareCard(CarelinkPalette p) {
    if (_activeBookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardColor(p),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor(p)),
          boxShadow: [_cardShadow(p)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.health_and_safety_outlined, size: 48, color: p.inkMuted.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              _t('No active care currently', 'لا توجد رعاية نشطة حالياً'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: p.inkDark),
            ),
            const SizedBox(height: 8),
            Text(
              _t('Start by requesting care from Home or Smart Assistant', 'ابدأ بطلب رعاية من الصفحة الرئيسية أو من المساعد الذكي'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: p.inkMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => PatientNavigationShell.switchTab(context, 0),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
                elevation: 0,
              ),
              child: Text(_t('Request care now', 'طلب رعاية الآن'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // Display the first active booking (most relevant)
    final b = _activeBookings.first;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor(p),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor(p)),
        boxShadow: [_cardShadow(p)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: p.isDark ? const Color(0xFF0D3841) : const Color(0xFFE7F8F6),
                child: Icon(Icons.person, color: AppColors.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.providerName.isNotEmpty ? b.providerName : _t('Care Provider', 'مقدم الرعاية'),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: p.inkDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.specialization.isNotEmpty ? b.specialization : b.providerRole,
                      style: TextStyle(fontSize: 14, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoRow(p, Icons.medical_services_outlined, _t('Service Type', 'نوع الخدمة'), b.isUrgent ? _t('Urgent', 'عاجل') : _t('Routine', 'روتينية')),
          const SizedBox(height: 12),
          _infoRow(p, Icons.event_available_outlined, _t('Next Appointment', 'الموعد القادم'), _formatDate(b.scheduledAt)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoBadge(p, b.status.toUpperCase(), p.isDark ? const Color(0xFF0E323B) : const Color(0xFFE7F8F6), AppColors.primary),
              _infoBadge(p, b.paymentStatus.toUpperCase(), p.isDark ? const Color(0xFF3B2E0E) : const Color(0xFFFFF7E6), Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleMessageProvider(b.providerUserId, b.providerName),
                  icon: const Icon(Icons.message_outlined, size: 20),
                  label: Text(_t('Message', 'مراسلة')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.inkDark,
                    side: BorderSide(color: p.stroke),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleCallProvider(b.providerUserId),
                  icon: const Icon(Icons.call_outlined, size: 20),
                  label: Text(_t('Call', 'اتصال')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.inkDark,
                    side: BorderSide(color: p.stroke),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BookingDetailsScreen(appointmentId: b.appointmentId, patientUserId: widget.patientUserId)),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_t('View booking details', 'عرض تفاصيل الحجز'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(CarelinkPalette p, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: p.inkMuted),
        const SizedBox(width: 12),
        Text('$label:', style: TextStyle(fontSize: 14, color: p.inkMuted)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value, 
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: p.inkDark),
          ),
        ),
      ],
    );
  }

  Widget _infoBadge(CarelinkPalette p, String text, Color bgColor, Color textColor) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ==========================================
  // SECTION 3: CARE PROGRESS TIMELINE
  // ==========================================
  Widget _buildCareProgressTimeline(CarelinkPalette p, AppointmentModel b) {
    final status = b.status.toLowerCase();
    
    int currentStep = 0;
    if (status == 'scheduled' || status == 'confirmed') currentStep = 1;
    if (status == 'in_progress') currentStep = 2;
    if (status == 'completed') currentStep = 4; // Or 3 if waiting for report
    
    final steps = [
      _t('Booking Confirmed', 'تم تأكيد الحجز'),
      _t('Waiting for Visit', 'بانتظار موعد الزيارة'),
      _t('Care in Progress', 'الرعاية قيد التنفيذ'),
      _t('Visit Report', 'تقرير الزيارة'),
      _t('Completed', 'مكتملة'),
    ];

    return _sectionCard(p, _t('Care Progress', 'مسار الرعاية'), 
      Column(
        children: List.generate(steps.length, (index) {
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;
          return _timelineRow(p, steps[index], isCompleted, isCurrent, index == steps.length - 1);
        }),
      )
    );
  }

  Widget _timelineRow(CarelinkPalette p, String text, bool isCompleted, bool isCurrent, bool isLast) {
    final color = isCompleted || isCurrent ? AppColors.primary : p.stroke;
    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? AppColors.primary : (isCurrent ? p.isDark ? const Color(0xFF0D3841) : const Color(0xFFE7F8F6) : p.pageBg),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: isCompleted 
                    ? const Icon(Icons.check, size: 12, color: Colors.white) 
                    : (isCurrent ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary))) : null),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: color.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted || isCurrent ? p.inkDark : p.inkMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 4: CARE PLAN
  // ==========================================
  Widget _buildCarePlan(CarelinkPalette p, AppointmentModel b) {
    final spec = b.specialization.toLowerCase();
    List<String> checklist = [];

    if (spec.contains('nurs')) {
      checklist = _isArabic 
        ? ['متابعة الحالة', 'قياس العلامات الحيوية', 'تحديث التقرير']
        : ['Condition monitoring', 'Vitals measurement', 'Report update'];
    } else if (spec.contains('surg')) {
      checklist = _isArabic 
        ? ['متابعة الجرح', 'تغيير الضماد', 'مراقبة علامات الالتهاب']
        : ['Wound care', 'Dressing change', 'Infection monitoring'];
    } else if (spec.contains('elder')) {
      checklist = _isArabic 
        ? ['متابعة الأدوية', 'قياس الضغط', 'تقرير الحالة']
        : ['Medication adherence', 'Blood pressure check', 'Condition report'];
    } else if (spec.contains('physio')) {
      checklist = _isArabic 
        ? ['تمارين الجلسة', 'تقييم الحركة', 'ملاحظات التحسن']
        : ['Session exercises', 'Mobility assessment', 'Progress notes'];
    } else if (spec.contains('mental') || spec.contains('psych')) {
      checklist = _isArabic 
        ? ['جلسة متابعة', 'ملاحظات الحالة', 'توصيات الجلسة']
        : ['Follow-up session', 'Condition notes', 'Session recommendations'];
    } else {
      checklist = _isArabic 
        ? ['التقييم الأولي', 'تقديم الرعاية المطلوبة', 'تسجيل الملاحظات']
        : ['Initial assessment', 'Provide care', 'Record notes'];
    }

    return _sectionCard(p, _t('Care Plan', 'خطة الرعاية'), 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.isDark ? const Color(0xFF0D3841).withOpacity(0.5) : const Color(0xFFE7F8F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('Initial care checklist based on your appointment type.', 'خطة مبدئية بناءً على نوع الرعاية'),
                    style: TextStyle(fontSize: 12, color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...checklist.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle_outlined, size: 20, color: p.stroke),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item, style: TextStyle(fontSize: 14, color: p.inkDark)),
                ),
              ],
            ),
          )),
        ],
      )
    );
  }

  // ==========================================
  // SECTION 5: LATEST PROVIDER NOTE
  // ==========================================
  Widget _buildLatestProviderNote(CarelinkPalette p) {
    if (_latestVisitReport == null) {
      return _sectionCard(p, _t('Latest Provider Note', 'آخر ملاحظات مقدم الرعاية'), 
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            _t('No provider notes yet', 'لا توجد ملاحظات من مقدم الرعاية بعد'),
            style: TextStyle(color: p.inkMuted, fontSize: 14),
          ),
        )
      );
    }

    final note = _latestVisitReport!['notes']?.toString() ?? '';
    final recs = _latestVisitReport!['recommendations']?.toString() ?? '';
    final date = DateTime.tryParse(_latestVisitReport!['createdAt']?.toString() ?? '') ?? DateTime.now();

    return _sectionCard(p, _t('Latest Provider Note', 'آخر ملاحظات مقدم الرعاية'), 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _latestVisitReport!['uploadedBy']?.toString() ?? 'Provider',
                style: TextStyle(fontWeight: FontWeight.bold, color: p.inkDark),
              ),
              Text(
                '${date.day}/${date.month}/${date.year}',
                style: TextStyle(fontSize: 12, color: p.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (note.isNotEmpty) ...[
            Text(note, style: TextStyle(fontSize: 14, color: p.inkDark, height: 1.4)),
            const SizedBox(height: 12),
          ],
          if (recs.isNotEmpty) ...[
            Text(_t('Recommendations:', 'التوصيات:'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: p.inkMuted)),
            const SizedBox(height: 4),
            Text(recs, style: TextStyle(fontSize: 14, color: AppColors.primary, height: 1.4)),
          ],
        ],
      )
    );
  }

  // ==========================================
  // SECTION 6: MEDICAL RECORDS SHORTCUT
  // ==========================================
  Widget _buildMedicalRecordsShortcut(CarelinkPalette p) {
    return _sectionCard(p, _t('Medical Records', 'السجلات الطبية'), 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_latestRecords.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                _t('No medical records found', 'لا توجد سجلات طبية'),
                style: TextStyle(color: p.inkMuted, fontSize: 14),
              ),
            )
          else
            ..._latestRecords.map((r) {
              final date = DateTime.tryParse(r['createdAt']?.toString() ?? '') ?? DateTime.now();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: p.pageBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.description_outlined, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['title']?.toString() ?? 'Record', style: TextStyle(fontWeight: FontWeight.bold, color: p.inkDark, fontSize: 14)),
                          Text(r['category']?.toString() ?? '', style: TextStyle(fontSize: 12, color: p.inkMuted)),
                        ],
                      ),
                    ),
                    Text('${date.day}/${date.month}/${date.year}', style: TextStyle(fontSize: 12, color: p.inkMuted)),
                  ],
                ),
              );
            }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                PatientNavigationShell.switchTab(context, 3);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_t('View all medical records', 'عرض جميع السجلات الطبية'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      )
    );
  }

  // ==========================================
  // SECTION 6.5: MESSAGES SECTION
  // ==========================================
  Widget _buildMessagesSection(CarelinkPalette p) {
    return _sectionCard(
      p, 
      _t('Messages', 'الرسائل'), 
      _recentChats.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('No messages yet', 'لا توجد رسائل حتى الآن'),
                  style: TextStyle(color: p.inkMuted, fontSize: 14),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to home or search to find a provider
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: Text(_t('Start Conversation', 'ابدأ محادثة')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          )
        : Column(
            children: _recentChats.take(3).map((chat) {
              final name = chat['displayName'] ?? '';
              final imageUrl = chat['profilePictureUrl'];
              final providerId = chat['providerId'] ?? '';
              final lastMsg = chat['lastMessage'] ?? 'Tap to continue conversation';
              final time = chat['timestamp'] != null 
                  ? DateTime.tryParse(chat['timestamp'])?.toLocal().toString().substring(11, 16) ?? ''
                  : '';
              
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        name: name,
                        userId: widget.patientUserId,
                        doctorId: providerId,
                      ),
                    ),
                  ).then((_) => _loadData());
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: imageUrl != null && imageUrl.toString().isNotEmpty
                            ? NetworkImage(imageUrl)
                            : null,
                        child: imageUrl == null || imageUrl.toString().isEmpty
                            ? const Icon(Icons.person, color: AppColors.primary, size: 24)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: p.inkDark,
                                    ),
                                  ),
                                ),
                                if (time.isNotEmpty)
                                  Text(
                                    time,
                                    style: TextStyle(fontSize: 12, color: p.inkMuted),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lastMsg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: p.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
    );
  }

  // ==========================================
  // SECTION 7: AI CARE INSIGHT
  // ==========================================
  Widget _buildCareInsight(CarelinkPalette p) {
    final bool hasSufficientData = _activeBookings.isNotEmpty && _latestRecords.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: p.isDark 
            ? [const Color(0xFF0F3E48), const Color(0xFF0A2E36)]
            : [const Color(0xFFE8F6F5), const Color(0xFFF2FBFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.isDark ? const Color(0xFF1D5A68) : const Color(0xFFBBE5E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: p.isDark ? const Color(0xFF5BE1D4) : AppColors.primaryDark),
              const SizedBox(width: 8),
              Text(
                _t('Care Insight', 'توصيات الرعاية'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: p.isDark ? Colors.white : AppColors.primaryDark),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasSufficientData)
            Text(
              _t('Smart recommendations will appear when more care data is available.', 'سيتم عرض التوصيات الذكية بعد توفر معلومات كافية.'),
              style: TextStyle(fontSize: 14, color: p.isDark ? Colors.white70 : AppColors.primaryDark.withOpacity(0.7)),
            )
          else ...[
            _insightRow(p, _t('Priority:', 'الأولوية:'), _t('Routine Care', 'رعاية روتينية')),
            const SizedBox(height: 12),
            _insightRow(p, _t('Next Step:', 'الخطوة التالية:'), _t('Complete upcoming visit', 'إكمال الزيارة القادمة')),
            const SizedBox(height: 12),
            Text(
              _t('Based on your recent records, follow your initial care plan and keep your provider updated.', 'بناءً على سجلاتك الأخيرة، اتبع خطة الرعاية المبدئية وأبقِ مقدم الرعاية على اطلاع.'),
              style: TextStyle(fontSize: 14, height: 1.4, color: p.isDark ? Colors.white70 : AppColors.primaryDark.withOpacity(0.8)),
            ),
          ]
        ],
      ),
    );
  }
  
  Widget _insightRow(CarelinkPalette p, String label, String value) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: p.isDark ? Colors.white60 : AppColors.primaryDark.withOpacity(0.6))),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: p.isDark ? Colors.white : AppColors.primaryDark)),
      ],
    );
  }

  // ==========================================
  // SECTION 8: EMERGENCY HELP CARD
  // ==========================================
  Widget _buildEmergencyHelpCard(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.isDark ? const Color(0xFF3B1D1D) : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Text('🚨', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Need urgent help?', 'تحتاج مساعدة عاجلة؟'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: p.isDark ? Colors.white : Colors.red[900]),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t('Emergency contact activated.', 'تم تفعيل الاتصال بالطوارئ.'))),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_t('Request Help', 'طلب مساعدة'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for generic section cards
  Widget _sectionCard(CarelinkPalette p, String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor(p),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor(p)),
        boxShadow: [_cardShadow(p)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: p.inkDark),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Color _cardColor(CarelinkPalette p) => p.isDark ? const Color(0xFF08242D) : p.surface;
  Color _borderColor(CarelinkPalette p) => p.isDark ? const Color(0xFF25505A) : p.stroke;
  BoxShadow _cardShadow(CarelinkPalette p) => BoxShadow(
    color: Colors.black.withOpacity(p.isDark ? 0.28 : 0.05),
    blurRadius: p.isDark ? 18 : 12,
    offset: const Offset(0, 8),
  );
}

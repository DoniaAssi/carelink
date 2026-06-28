import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/features/patient/screens/chat_screen.dart';
import 'package:carelink/shared/services/patient_recent_chats_service.dart';
import 'package:carelink/features/patient/screens/messages_screen.dart';
import 'package:carelink/features/patient/widgets/patient_navigation_shell.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/features/ai/provider_smart_match.dart';
import 'package:carelink/features/ai/provider_booking_eligibility.dart';
import 'package:carelink/shared/services/location_service.dart';
import 'package:carelink/shared/services/patient_favorites_service.dart';
import 'provider_details_screen.dart';

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
  List<Map<String, dynamic>> _myFavorites = [];
  // Cached for future recent-conversation summaries on this screen.
  // ignore: unused_field
  List<Map<String, dynamic>> _recentChats = [];
  Map<String, dynamic>? _latestVisitReport;
  ProviderModel? _recommendedProvider;
  String? _careError;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _careError = null;
        });
    }

    final patientId = widget.patientUserId.trim();
    if (patientId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _careError = _t(
          'Your session is missing. Please sign in again.',
          'بيانات الجلسة غير متوفرة. يرجى تسجيل الدخول مرة أخرى.',
        );
        });
      return;
    }

    var activeBookings = <AppointmentModel>[];
    ProviderModel? recommendedProvider;
    String? careError;
    Map<String, dynamic>? latestProviderRecord;
    var recentChats = <Map<String, dynamic>>[];

    try {
      final rawBookings = await _api.getAppointments(widget.patientUserId);
      final allBookings = rawBookings
          .map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>))
          .toList();

      final activeStatuses = [
        'accepted',
        'confirmed',
        'scheduled',
        'in_progress',
      ];
      final pendingStatuses = [
        'pending_provider_approval',
        'pending',
        'request_sent',
      ];

      var activeList = allBookings
          .where((b) => activeStatuses.contains(b.status.toLowerCase()))
          .toList();

      if (activeList.isEmpty) {
        activeList = allBookings
            .where((b) => pendingStatuses.contains(b.status.toLowerCase()))
            .toList();
      }

      activeBookings = activeList;

      if (activeBookings.isEmpty) {
        try {
          final rawProviders = await _api.getProviders(realAvailability: true);
          final allProviders = rawProviders
              .map((e) => ProviderModel.fromJson(e as Map<String, dynamic>))
              .where(ProviderBookingEligibility.canBook)
              .toList();
          final locationService = LocationService();
          if (allProviders.isNotEmpty) {
            final sorted = ProviderSmartMatch.sortCopy(
              allProviders,
              locationService: locationService,
            );
            if (sorted.isNotEmpty) {
              recommendedProvider = sorted.first;
            }
          }
        } catch (_) {}
      }
    } catch (error) {
      careError = _friendlyLoadError(
        _t('Could not load your active care.', 'تعذر تحميل الرعاية النشطة.'),
        error,
      );
    }

    try {
      final rawRecords = await _recordService.listForPatient(
        patientId,
        requesterUserId: patientId,
        requesterRole: 'patient',
      );

      rawRecords.sort((a, b) {
        final ta =
            DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb =
            DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });

      final providerRecords = rawRecords
          .where(
            (record) => const {
              'doctor',
              'nurse',
            }.contains(record['creatorRole']?.toString().trim().toLowerCase()),
          )
          .toList();
      latestProviderRecord = providerRecords.isEmpty
          ? null
          : providerRecords.first;
    } catch (error) {
          }

    try {
      recentChats = await PatientRecentChatsService.getRecentChats();
    } catch (_) {}

    try {
      final favs = await PatientFavoritesService.getFavorites(patientId);
      _myFavorites = favs;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _activeBookings = activeBookings;
      _recommendedProvider = recommendedProvider;
      _latestVisitReport = latestProviderRecord;
      _recentChats = recentChats;
      _careError = careError;
      _loading = false;
    });
  }

  String _friendlyLoadError(String fallback, Object error) {
    final detail = error.toString().replaceFirst('Exception: ', '').trim();
    if (detail.isEmpty || detail.contains('<html') || detail.length > 180) {
      return fallback;
    }
    return '$fallback $detail';
  }

  bool get _isArabic => localeController.isArabic;
  String _t(String en, String ar) => _isArabic ? ar : en;

  String _translateStatus(String status) {
    final lower = status.toLowerCase();
    switch (lower) {
      case 'pending_provider_approval':
      case 'pending':
        return _isArabic
            ? 'بانتظار موافقة مقدم الرعاية'
            : 'Waiting for provider approval';
      case 'pending_payment':
      case 'payment_pending':
        return _isArabic ? 'بانتظار الدفع' : 'Pending Payment';
      case 'confirmed':
        return _isArabic ? 'مؤكد' : 'Confirmed';
      case 'completed':
        return _isArabic ? 'مكتمل' : 'Completed';
      case 'cancelled':
        return _isArabic ? 'ملغي' : 'Cancelled';
      case 'in_progress':
        return _isArabic ? 'قيد التنفيذ' : 'In Progress';
      case 'request_expired':
      case 'expired':
        return _isArabic ? 'انتهت صلاحية الطلب' : 'Request Expired';
      case 'missed':
      case 'no_show':
        return _isArabic ? 'موعد فائت' : 'Missed Appointment';
      case 'pending_completion':
        return _isArabic ? 'بانتظار تأكيد الإتمام' : 'Pending Completion';
      default:
        return _isArabic ? 'غير معروف' : 'Unknown';
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

    return PatientScaffold(
      enabled: false,
      backgroundColor: p.isDark ? p.pageBg : const Color(0xFFF8FAFA),
      appBar: PatientAppBar(
        title: _t('My Care', 'رعايتي'),
        showBack: false,
        showMessages: true,
        onMessageTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MessagesScreen(userId: widget.patientUserId),
            ),
          );
        },
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _loadData(silent: true),
        child: _loading
            ? _buildSkeleton(p)
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_careError != null) ...[
                      _buildLoadErrorCard(p, _careError!),
                      const SizedBox(height: 20),
                    ] else if (_activeBookings.isEmpty) ...[
                      if (_recommendedProvider != null) ...[
                        _buildRecommendedProviderCard(p),
                        const SizedBox(height: 20),
                      ] else ...[
                        _buildEmptyStateCard(p),
                        const SizedBox(height: 20),
                      ],
                    ] else ...[
                      _buildUpcomingCareCard(p, _activeBookings.first),
                      const SizedBox(height: 20),

                      _buildCurrentCarePlanCard(p, _activeBookings.first),
                      const SizedBox(height: 20),

                      _buildRecentCareActivities(p),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadErrorCard(CarelinkPalette p, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFDC2626).withValues(alpha: 0.3),
        ),
        boxShadow: [_cardShadow(p)],
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkDark, height: 1.4),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_t('Try again', 'إعادة المحاولة')),
          ),
        ],
      ),
    );
  }

  

  

  // ==========================================
  // SECTION 2: ACTIVE CARE CARD
  // ==========================================
  Widget _buildEmptyStateCard(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.stroke),
        boxShadow: [_cardShadow(p)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            size: 48,
            color: p.inkMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _t('No active care currently', 'لا توجد رعاية نشطة حالياً'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'Start by requesting care from Home or Smart Assistant',
              'ابدأ بطلب رعاية من الصفحة الرئيسية أو من المساعد الذكي',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: p.inkMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => PatientNavigationShell.switchTab(context, 0),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 48),
              elevation: 0,
            ),
            child: Text(
              _t('Request care now', 'طلب رعاية الآن'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String? _absoluteImage(dynamic path) {
    if (path == null) return null;
    final str = '$path'.trim();
    if (str.isEmpty || str == 'null' || str == 'undefined') return null;
    if (str.startsWith('http')) return str;
    final baseUrl = ApiService.baseUrl.replaceAll('/api', '');
    return '$baseUrl$str';
  }

  Widget _buildRecommendedProviderCard(CarelinkPalette p) {
    final prov = _recommendedProvider!;
    final image = _absoluteImage(prov.profileImageUrl);

    return PatientPressable(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderDetailsScreen(
              provider: prov,
              patientUserId: widget.patientUserId,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          boxShadow: [_cardShadow(p)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 6),
                Text(
                  _t('Recommended for you', 'مقترح لك'),
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  foregroundImage: image == null ? null : NetworkImage(image),
                  child: image == null
                      ? const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 36,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prov.fullName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: p.inkDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prov.specialization.isNotEmpty
                            ? prov.specialization
                            : prov.role,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rate_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            prov.overallRating.toStringAsFixed(1),
                            style: TextStyle(
                              color: p.inkMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderDetailsScreen(
                        provider: prov,
                        patientUserId: widget.patientUserId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: Text(
                  _t('View Profile', 'عرض الصفحة الشخصية'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  Widget _infoBadge(
    CarelinkPalette p,
    String text,
    Color bgColor,
    Color textColor,
  ) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ==========================================
  // SECTION 3: CURRENT CARE PLAN
  // ==========================================
  

  

  

  

  

  // ==========================================
  // SECTION 7: AI CARE INSIGHT
  // ==========================================
  

  

  Widget _buildSkeleton(CarelinkPalette p) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _skeletonBox(p, height: 140),
          const SizedBox(height: 20),
          _skeletonBox(p, height: 160),
          const SizedBox(height: 20),
          _skeletonBox(p, height: 220),
        ],
      ),
    );
  }

  Widget _skeletonBox(CarelinkPalette p, {required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: p.stroke.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
  // Helper for generic section cards
  


  BoxShadow _cardShadow(CarelinkPalette p) => BoxShadow(
    color: Colors.black.withValues(alpha: p.isDark ? 0.28 : 0.05),
    blurRadius: p.isDark ? 18 : 12,
    offset: const Offset(0, 8),
  );
// ==========================================
  // NEW SECTION: UPCOMING CARE CARD
  // ==========================================
  Widget _buildUpcomingCareCard(CarelinkPalette p, AppointmentModel b) {
    final spec = '${b.specialization}'.trim();
    final role = '${b.providerRole}'.trim();
    final service = (spec != '' && spec != 'null' && spec != 'undefined') ? spec : role;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.isDark ? p.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_cardShadow(p)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('Upcoming Care', 'الموعد القادم'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: p.inkDark,
                ),
              ),
              if ('${b.status}'.trim() != '' && '${b.status}' != 'null' && '${b.status}' != 'undefined')
                _infoBadge(p, _translateStatus(b.status), const Color(0xFF0E8A78), Colors.white),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: p.isDark ? const Color(0xFF0D3841) : const Color(0xFFE7F8F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_outlined, color: Color(0xFF0E8A78), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0E8A78)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatDate(b.scheduledAt).split(' ')[0],
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: p.inkDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF0E8A78)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b.scheduledAt != null ? '${b.scheduledAt!.hour.toString().padLeft(2, '0')}:${b.scheduledAt!.minute.toString().padLeft(2, '0')}' : '',
                            style: TextStyle(fontSize: 14, color: p.inkMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF0E8A78)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${b.providerName} • $service',
                            style: TextStyle(fontSize: 14, color: p.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _handleMessageProvider(b.providerUserId, b.providerName),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              label: Text(_t('Message Provider', 'مراسلة مقدم الرعاية')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0E8A78),
                side: const BorderSide(color: Color(0xFF0E8A78), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // NEW SECTION: CURRENT CARE PLAN CARD
  // ==========================================
  Widget _buildCurrentCarePlanCard(CarelinkPalette p, AppointmentModel b) {
    final spec = '${b.specialization}'.trim();
    final role = '${b.providerRole}'.trim();
    final service = (spec != '' && spec != 'null' && spec != 'undefined') ? spec : role;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.isDark ? p.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_cardShadow(p)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Current Care Plan', 'خطة الرعاية الحالية'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: p.isDark ? const Color(0xFF0D3841) : const Color(0xFFE7F8F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF0E8A78), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.isEmpty ? _t('General Care', 'رعاية عامة') : service,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0E8A78)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t('Start Date: ', 'بداية الخطة: ') + _formatDate(b.scheduledAt).split(' ')[0],
                      style: TextStyle(fontSize: 13, color: p.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _carePlanStatItem(p, Icons.fact_check_outlined, _t('Tasks', 'المهام'), _t('4 Tasks', '4 مهام')),
              _carePlanStatItem(p, Icons.medication_outlined, _t('Medications', 'الأدوية'), _t('2 Meds', '2 أدوية')),
              _carePlanStatItem(p, Icons.assignment_outlined, _t('Instructions', 'التعليمات'), _t('5 Inst.', '5 تعليمات')),
              _carePlanStatItem(p, Icons.flag_outlined, _t('Goals', 'الأهداف'), _t('3 Goals', '3 أهداف')),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {}, // Future endpoint for full care plan
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              label: Text(_t('View Plan', 'عرض الخطة')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0E8A78),
                side: const BorderSide(color: Color(0xFF0E8A78), width: 1.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carePlanStatItem(CarelinkPalette p, IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF0E8A78), size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: p.inkDark),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: p.inkMuted),
        ),
      ],
    );
  }

  // ==========================================
  // NEW SECTION: RECENT CARE ACTIVITIES
  // ==========================================
  Widget _buildRecentCareActivities(CarelinkPalette p) {
    // Generate dummy activities based on latest records + bookings
    final activities = <Map<String, dynamic>>[];
    
    if (_latestVisitReport != null) {
      activities.add({
        'title': _t('New note', 'ملاحظة جديدة'),
        'source': _latestVisitReport!['creatorName'] ?? _t('Provider', 'مقدم الرعاية'),
        'date': _latestVisitReport!['createdAt'] ?? '',
        'icon': Icons.note_alt_outlined,
        'color': Colors.amber,
      });
    }
    if (_activeBookings.isNotEmpty) {
      activities.add({
        'title': _t('Status update', 'تحديث حالة'),
        'source': _activeBookings.first.providerName,
        'date': _activeBookings.first.scheduledAt?.toIso8601String() ?? '',
        'icon': Icons.info_outline_rounded,
        'color': const Color(0xFF3B82F6),
      });
      if (_activeBookings.first.status.toLowerCase() == 'completed') {
        activities.insert(0, {
          'title': _t('Visit completed', 'زيارة تم تنفيذها'),
          'source': _activeBookings.first.providerName,
          'date': _activeBookings.first.scheduledAt?.toIso8601String() ?? '',
          'icon': Icons.check_circle_outline_rounded,
          'color': const Color(0xFF10B981),
        });
      }
    }

    if (activities.length == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.isDark ? p.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_cardShadow(p)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Recent Care Activities', 'آخر أنشطة الرعاية'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(activities.length, (index) {
              final act = activities[index];
              final dateStr = act['date'].toString();
              final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
              return Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (act['color'] as Color).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(act['icon'] as IconData, color: act['color'] as Color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              act['title'] as String,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: p.inkDark),
                            ),
                            Text(
                              act['source'] as String,
                              style: TextStyle(fontSize: 12, color: p.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0E8A78)),
                          ),
                          Text(
                            '${dt.day} ${_t('May', 'مايو')} ${dt.year}', // Simple mock date for demo
                            style: TextStyle(fontSize: 11, color: p.inkMuted),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, color: p.inkMuted, size: 20),
                    ],
                  ),
                  if (index < activities.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: p.stroke.withValues(alpha: 0.5), height: 1),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ExpandableSectionCard extends StatefulWidget {
  const _ExpandableSectionCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.content,
  });

  final CarelinkPalette palette;
  final IconData icon;
  final String title;
  final String content;

  @override
  State<_ExpandableSectionCard> createState() => _ExpandableSectionCardState();
}

class _ExpandableSectionCardState extends State<_ExpandableSectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final isArabic = localeController.isArabic;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.isDark ? p.surface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.inkDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Text(
              widget.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: p.inkDark,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            secondChild: Text(
              widget.content,
              style: TextStyle(
                fontSize: 13,
                color: p.inkDark,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (widget.content.length > 80 || widget.content.contains('\n')) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded 
                    ? (isArabic ? 'إخفاء التفاصيل' : 'Show less')
                    : (isArabic ? 'عرض المزيد' : 'Show more'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/screens/chat_screen.dart';
import 'package:carelink/shared/services/patient_recent_chats_service.dart';
import 'package:carelink/features/patient/screens/messages_screen.dart';
import 'package:carelink/features/patient/widgets/patient_navigation_shell.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/features/ai/provider_smart_match.dart';
import 'package:carelink/features/ai/provider_booking_eligibility.dart';
import 'package:carelink/shared/services/location_service.dart';
import 'package:carelink/shared/utils/appointment_time_utils.dart';
import 'provider_details_screen.dart';

class PatientCareHubScreen extends StatefulWidget {
  const PatientCareHubScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<PatientCareHubScreen> createState() => _PatientCareHubScreenState();
}

class _PatientCareHubScreenState extends State<PatientCareHubScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  List<AppointmentModel> _activeBookings = [];
  // Cached for future recent-conversation summaries on this screen.
  // ignore: unused_field
  List<Map<String, dynamic>> _recentChats = [];
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
      recentChats = await PatientRecentChatsService.getRecentChats();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _activeBookings = activeBookings;
      _recommendedProvider = recommendedProvider;
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
      backgroundColor: p.pageBg,
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
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _loadData(silent: true),
          child: _loading
              ? _buildSkeleton(p)
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    18,
                    16,
                    MediaQuery.paddingOf(context).bottom + 120,
                  ),
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
                        const SizedBox(height: 24),

                        _buildCurrentCarePlanCard(p, _activeBookings.first),
                        const SizedBox(height: 24),

                        _buildRecentCareActivities(p),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
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
              fontSize: 20,
              fontWeight: FontWeight.w900,
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
          const SizedBox(height: 18),
          _skeletonBox(p, height: 160),
          const SizedBox(height: 18),
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
    color: p.cardShadowColor(0.06),
    blurRadius: 22,
    offset: const Offset(0, 10),
  );

  BoxDecoration _dashboardCardDecoration(CarelinkPalette p) => BoxDecoration(
    color: p.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: p.stroke.withValues(alpha: 0.45)),
    boxShadow: [_cardShadow(p)],
  );

  String _formatDateOnly(DateTime? d) {
    return AppointmentTimeUtils.formatDate(
      context,
      d,
      fallback: _t('Date pending', 'التاريخ قيد الانتظار'),
      numeric: true,
    );
  }

  String _formatTimeOnly(DateTime? d) {
    return AppointmentTimeUtils.formatTime(
      context,
      d,
      fallback: _t('Time pending', 'الوقت قيد الانتظار'),
      twoDigitHour: true,
    );
  }

  Widget _providerAvatar(CarelinkPalette p, AppointmentModel b) {
    final image = _absoluteImage(b.providerImageUrl);
    return CircleAvatar(
      radius: 31,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      foregroundImage: image == null ? null : NetworkImage(image),
      child: image == null
          ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 30)
          : null,
    );
  }

  // ==========================================
  // NEW SECTION: UPCOMING CARE CARD
  // ==========================================
  Widget _buildUpcomingCareCard(CarelinkPalette p, AppointmentModel b) {
    final spec = b.specialization.trim();
    final role = b.providerRole.trim();
    final service = (spec != '' && spec != 'null' && spec != 'undefined')
        ? spec
        : role;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _dashboardCardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Upcoming Care', 'الموعد القادم'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: p.inkDark,
                ),
              ),
              if (b.status.trim() != '' &&
                  b.status != 'null' &&
                  b.status != 'undefined') ...[
                const SizedBox(height: 10),
                _infoBadge(
                  p,
                  _translateStatus(b.status),
                  AppColors.primary,
                  Colors.white,
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _providerAvatar(p, b),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.providerName.isEmpty
                          ? _t('Care provider', 'مقدم الرعاية')
                          : b.providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: p.inkDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      service.isEmpty
                          ? _t('General Care', 'رعاية عامة')
                          : service,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatDateOnly(b.scheduledAt),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: p.inkDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatTimeOnly(b.scheduledAt),
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
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _handleMessageProvider(b.providerUserId, b.providerName),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text(_t('Message Provider', 'مراسلة مقدم الرعاية')),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _dashboardCardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Current Care Plan', 'خطة الرعاية الحالية'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.stroke.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 32,
                  color: p.inkMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  _t('No active care plan', 'لا توجد خطة رعاية نشطة'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.inkDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                    'Your care provider has not published a plan yet.',
                    'لم يقم مقدم الرعاية بنشر خطة بعد.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: p.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // NEW SECTION: RECENT CARE ACTIVITIES
  // ==========================================
  Widget _buildRecentCareActivities(CarelinkPalette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _dashboardCardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Recent Care Activities', 'آخر أنشطة الرعاية'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.stroke.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 32,
                  color: p.inkMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  _t('No recent activities', 'لا توجد أنشطة حديثة'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.inkDark,
                  ),
                ),
              ],
            ),
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
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
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
          ],
        ],
      ),
    );
  }
}

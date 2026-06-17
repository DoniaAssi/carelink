import 'package:flutter/material.dart';

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
import 'package:carelink/shared/services/location_service.dart';
import 'booking_details_screen.dart';
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
  List<Map<String, dynamic>> _latestRecords = [];
  // Cached for future recent-conversation summaries on this screen.
  // ignore: unused_field
  List<Map<String, dynamic>> _recentChats = [];
  Map<String, dynamic>? _latestVisitReport;
  ProviderModel? _recommendedProvider;

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
      final allBookings = rawBookings
          .map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('Total appointments fetched: ${allBookings.length}');

      for (final b in allBookings) {
        debugPrint(
          'Appt ID: ${b.appointmentId} | Status: ${b.status} | Provider: ${b.providerName} | Service: ${b.specialization} | Date: ${b.scheduledAt}',
        );
      }

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

      _activeBookings = activeList;

      if (_activeBookings.isNotEmpty) {
        final b = _activeBookings.first;
        debugPrint('Selected Active Booking: ${b.appointmentId} (${b.status})');
      } else {
        debugPrint(
          'No active or pending bookings found. Fetching recommended provider.',
        );
        try {
          final rawProviders = await _api.getProviders();
          final allProviders = rawProviders
              .map((e) => ProviderModel.fromJson(e as Map<String, dynamic>))
              .toList();
          final locationService = LocationService();
          if (allProviders.isNotEmpty) {
            final sorted = ProviderSmartMatch.sortCopy(
              allProviders,
              locationService: locationService,
            );
            if (sorted.isNotEmpty) {
              _recommendedProvider = sorted.first;
            }
          }
        } catch (_) {}
      }

      // 2. Medical Records
      final rawRecords = await _recordService.listForPatient(
        widget.patientUserId,
        requesterUserId: widget.patientUserId,
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

      _latestRecords = rawRecords.take(3).toList();

      final visitReports = rawRecords
          .where(
            (r) =>
                r['type'] == 'visit_report' ||
                r['type'] == 'visitReport' ||
                (r['category']?.toString().toLowerCase().contains('report') ??
                    false),
          )
          .toList();
      if (visitReports.isNotEmpty) {
        _latestVisitReport = visitReports.first;
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
      default:
        return status.toUpperCase();
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
        onRefresh: _loadData,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_activeBookings.isEmpty) ...[
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

                      _buildCombinedCarePlan(p, _activeBookings.first),
                      const SizedBox(height: 20),

                      _buildCombinedCareInsight(p),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
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

  String? _absoluteImage(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final baseUrl = ApiService.baseUrl.replaceAll('/api', '');
    return '$baseUrl$path';
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

  Widget _buildUpcomingCareCard(CarelinkPalette p, AppointmentModel b) {
    final image = _absoluteImage(b.providerImageUrl);
    return PatientPressable(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailsScreen(
              appointmentId: b.appointmentId,
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
          border: Border.all(color: p.stroke),
          boxShadow: [_cardShadow(p)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: p.isDark
                      ? const Color(0xFF0D3841)
                      : const Color(0xFFE7F8F6),
                  foregroundImage: image == null ? null : NetworkImage(image),
                  child: image == null
                      ? const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 32,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.providerName.isNotEmpty
                            ? b.providerName
                            : _t('Care Provider', 'مقدم الرعاية'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: p.inkDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b.specialization.isNotEmpty
                            ? b.specialization
                            : b.providerRole,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.pageBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.stroke.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('Date & Time', 'التاريخ والوقت'),
                          style: TextStyle(color: p.inkMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(b.scheduledAt),
                          style: TextStyle(
                            color: p.inkDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: p.stroke),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('Status', 'الحالة'),
                          style: TextStyle(color: p.inkMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _infoBadge(
                              p,
                              _translateStatus(b.status),
                              p.isDark
                                  ? const Color(0xFF0E323B)
                                  : const Color(0xFFE7F8F6),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _handleMessageProvider(b.providerUserId, b.providerName),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                label: Text(_t('Message Provider', 'مراسلة مقدم الرعاية')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
  Widget _buildCombinedCarePlan(CarelinkPalette p, AppointmentModel b) {
    final service = b.specialization.trim().isNotEmpty
        ? b.specialization.trim()
        : b.providerRole.trim();
    final providerName = b.providerName.trim().isNotEmpty
        ? b.providerName.trim()
        : _t('Care provider', 'مقدم الرعاية');

    return _sectionCard(
      p,
      _t('Current Care Plan', 'خطة الرعاية الحالية'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _carePlanItem(
            p,
            icon: Icons.event_available_outlined,
            title: _t('Upcoming care', 'الرعاية القادمة'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _carePlanDetail(p, Icons.person_outline_rounded, providerName),
                const SizedBox(height: 7),
                _carePlanDetail(
                  p,
                  Icons.medical_services_outlined,
                  service.isEmpty
                      ? _t('Care service', 'خدمة الرعاية')
                      : service,
                ),
                const SizedBox(height: 7),
                _carePlanDetail(
                  p,
                  Icons.schedule_rounded,
                  _formatDate(b.scheduledAt),
                ),
                const SizedBox(height: 7),
                _carePlanDetail(
                  p,
                  Icons.info_outline_rounded,
                  _translateStatus(b.status),
                  valueColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _carePlanItem(
            p,
            icon: Icons.inventory_2_outlined,
            title: _t('Before the visit', 'قبل الزيارة'),
            text: _t(
              'Prepare any medical reports or medications you currently use before your appointment.',
              'حضّر أي تقارير أو أدوية تستخدمها حالياً قبل موعدك.',
            ),
          ),
          const SizedBox(height: 14),
          _carePlanItem(
            p,
            icon: Icons.fact_check_outlined,
            title: _t('After the visit', 'بعد الزيارة'),
            text: _t(
              'Provider notes and care recommendations will appear here after the visit.',
              'ستظهر هنا ملاحظات مقدم الرعاية وتوصياته بعد انتهاء الموعد.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _carePlanItem(
    CarelinkPalette p, {
    required IconData icon,
    required String title,
    String? text,
    Widget? child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.isDark
            ? AppColors.primary.withValues(alpha: 0.08)
            : const Color(0xFFF1FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: p.isDark ? 0.18 : 0.10,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                if (child != null)
                  child
                else
                  Text(
                    text ?? '',
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carePlanDetail(
    CarelinkPalette p,
    IconData icon,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            value.trim().isEmpty ? _t('Not available', 'غير متوفر') : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? p.inkMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SECTION 5: LATEST PROVIDER NOTE
  // ==========================================
  Widget _buildLatestProviderNote(CarelinkPalette p) {
    if (_latestVisitReport == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          _t('No provider notes yet', 'لا توجد ملاحظات من مقدم الرعاية بعد'),
          style: TextStyle(color: p.inkMuted, fontSize: 14),
        ),
      );
    }

    final note = _latestVisitReport!['notes']?.toString() ?? '';
    final recs = _latestVisitReport!['recommendations']?.toString() ?? '';
    final date =
        DateTime.tryParse(_latestVisitReport!['createdAt']?.toString() ?? '') ??
        DateTime.now();

    return Column(
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
          Text(
            note,
            style: TextStyle(fontSize: 14, color: p.inkDark, height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
        if (recs.isNotEmpty) ...[
          Text(
            _t('Recommendations:', 'التوصيات:'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: p.inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            recs,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCombinedCareInsight(CarelinkPalette p) {
    return _sectionCard(
      p,
      _t('Care Insights', 'رؤى الرعاية'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Latest Provider Note', 'آخر ملاحظات مقدم الرعاية'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: p.inkMuted,
            ),
          ),
          const SizedBox(height: 12),
          _buildLatestProviderNote(p),
          const SizedBox(height: 20),
          Divider(color: p.stroke),
          const SizedBox(height: 20),
          _buildCareInsight(p),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 7: AI CARE INSIGHT
  // ==========================================
  Widget _buildCareInsight(CarelinkPalette p) {
    final bool hasSufficientData =
        _activeBookings.isNotEmpty && _latestRecords.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: p.isDark ? const Color(0xFF5BE1D4) : AppColors.primaryDark,
            ),
            const SizedBox(width: 8),
            Text(
              _t('Care Insight', 'توصيات الرعاية'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: p.isDark ? Colors.white : AppColors.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!hasSufficientData)
          Text(
            _t(
              'Smart recommendations will appear when more care data is available.',
              'سيتم عرض التوصيات الذكية بعد توفر معلومات كافية.',
            ),
            style: TextStyle(
              fontSize: 14,
              color: p.isDark
                  ? Colors.white70
                  : AppColors.primaryDark.withValues(alpha: 0.7),
            ),
          )
        else ...[
          _insightRow(
            p,
            _t('Priority:', 'الأولوية:'),
            _t('Routine Care', 'رعاية روتينية'),
          ),
          const SizedBox(height: 12),
          _insightRow(
            p,
            _t('Next Step:', 'الخطوة التالية:'),
            _t('Complete upcoming visit', 'إكمال الزيارة القادمة'),
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              'Based on your recent records, follow your initial care plan and keep your provider updated.',
              'بناءً على سجلاتك الأخيرة، اتبع خطة الرعاية المبدئية وأبقِ مقدم الرعاية على اطلاع.',
            ),
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: p.isDark
                  ? Colors.white70
                  : AppColors.primaryDark.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }

  Widget _insightRow(CarelinkPalette p, String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: p.isDark
                ? Colors.white60
                : AppColors.primaryDark.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: p.isDark ? Colors.white : AppColors.primaryDark,
          ),
        ),
      ],
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Color _cardColor(CarelinkPalette p) =>
      p.isDark ? const Color(0xFF08242D) : p.surface;
  Color _borderColor(CarelinkPalette p) =>
      p.isDark ? const Color(0xFF25505A) : p.stroke;
  BoxShadow _cardShadow(CarelinkPalette p) => BoxShadow(
    color: Colors.black.withValues(alpha: p.isDark ? 0.28 : 0.05),
    blurRadius: p.isDark ? 18 : 12,
    offset: const Offset(0, 8),
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'booking_details_screen.dart';
import 'chat_screen.dart';

import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/features/patient/widgets/reschedule_modal.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

class ScheduleScreen extends StatefulWidget {
  final String patientUserId;

  const ScheduleScreen({
    super.key,
    required this.patientUserId,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

enum _ScheduleFilter { pending, upcoming, completed, cancelled }

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<Map<String, dynamic>> appointments = [];
  bool isLoading = true;
  String? errorMessage;
  _ScheduleFilter currentFilter = _ScheduleFilter.pending;

  void _dbg(String message) {
    if (kDebugMode) debugPrint('[CareLink Schedule] $message');
  }

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    if (widget.patientUserId.trim().isEmpty) {
      setState(() {
        appointments = [];
        isLoading = false;
        errorMessage = 'Patient account is missing. Please login again.';
      });
      return;
    }

    try {
      _dbg(
        'patientUserId sent to APIs: "${widget.patientUserId}"',
      );

      final all = await ApiService().getAppointments(widget.patientUserId);
      final upcoming = await ApiService().getUpcomingAppointments(
        widget.patientUserId,
      );
      final history = await ApiService().getAppointmentHistory(
        widget.patientUserId,
      );

      _dbg(
        'API row counts — all: ${all.length}, upcoming: ${upcoming.length}, history: ${history.length}',
      );

      final byId = <String, Map<String, dynamic>>{};
      void mergeIn(List<dynamic> list) {
        for (final raw in list) {
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw);
          final id =
              (m['appointmentId'] ?? m['requestId'] ?? '').toString().trim();
          if (id.isEmpty) continue;
          byId[id] = m;
        }
      }

      mergeIn(all);
      mergeIn(upcoming);
      mergeIn(history);

      final merged = byId.values.toList()
        ..sort((a, b) {
          final cb = _sortKey(b);
          final ca = _sortKey(a);
          return cb.compareTo(ca);
        });

      if (!mounted) return;

      setState(() {
        appointments = merged;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = _cleanErrorMessage(e);
      });
    }
  }

  String _cleanErrorMessage(dynamic e) {
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    if (raw.toLowerCase().contains('html') ||
        raw.contains('<!') ||
        raw.contains('<html') ||
        raw.contains('<body>')) {
      return context.l10n.isArabic
          ? 'تعذر جلب البيانات، يرجى المحاولة لاحقاً'
          : 'Server connection error, please try again later';
    }
    return raw;
  }

  int _sortKey(Map<String, dynamic> row) {
    final completed = _parseScheduledAt(row['completedAt']);
    final sched = _parseScheduledAt(row['scheduledAt']);
    final t = completed ?? sched;
    return t?.millisecondsSinceEpoch ?? 0;
  }

  String? _rawStatusFromItem(Map<String, dynamic> item) {
    final r = item['status'] ?? item['bookingStatus'];
    return r?.toString();
  }

  List<Map<String, dynamic>> get filteredAppointments {
    return appointments.where((item) {
      final status = _normalizedStatus(_rawStatusFromItem(item));
      switch (currentFilter) {
        case _ScheduleFilter.pending:
          return status == 'pending';
        case _ScheduleFilter.upcoming:
          return status == 'upcoming';
        case _ScheduleFilter.completed:
          return status == 'completed';
        case _ScheduleFilter.cancelled:
          return status == 'cancelled';
      }
    }).toList();
  }

  String _normalizedStatus(String? rawStatus) {
    final status = (rawStatus ?? '').toLowerCase().trim();
    if (status == 'pending' ||
        status == 'requested' ||
        status == 'request_sent' ||
        status == 'waiting_provider_response') {
      return 'pending';
    }
    if (status == 'accepted' ||
        status == 'confirmed' ||
        status == 'scheduled' ||
        status == 'approved') {
      return 'upcoming';
    }
    if (status == 'completed' || status == 'done') {
      return 'completed';
    }
    if (status == 'cancelled' ||
        status == 'canceled' ||
        status == 'rejected') {
      return 'cancelled';
    }
    return 'upcoming';
  }

  DateTime? _parseScheduledAt(dynamic rawValue) {
    final value = rawValue?.toString();
    if (value == null || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  bool _isFuture(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(DateTime.now());
  }

  String _formatDate(DateTime? date) {
    if (date == null) return context.l10n.isArabic ? 'التاريخ غير متوفر' : 'Date unavailable';
    if (context.l10n.isArabic) {
      final monthNames = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
    } else {
      final monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return context.l10n.isArabic ? 'الوقت غير متوفر' : 'Time unavailable';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = '${date.minute}'.padLeft(2, '0');
    if (context.l10n.isArabic) {
      final suffix = date.hour >= 12 ? 'م' : 'ص';
      return '$hour:$minute $suffix';
    } else {
      final suffix = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }
  }

  String _localizedProviderRole(BuildContext context, dynamic item) {
    final role = item['providerRole']?.toString().toLowerCase() ?? '';
    if (role.contains('doctor')) return context.l10n.isArabic ? 'طبيب' : 'Doctor';
    if (role.contains('nurse')) return context.l10n.isArabic ? 'ممرض' : 'Nurse';
    return context.l10n.isArabic ? 'مقدم رعاية' : 'Care Provider';
  }

  Color _statusColor(String status, bool isDark) {
    switch (status) {
      case 'pending':
        return AppColors.primary; // CareLink Teal (mint background via opacity)
      case 'completed':
        return isDark ? const Color(0xFF90A4AE) : const Color(0xFF78909C); // Blue-gray
      case 'cancelled':
        return isDark ? const Color(0xFFE57373) : const Color(0xFFC62828); // Red
      default:
        // Upcoming/Confirmed
        return isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32); // Green
    }
  }

  String _localizedServiceType(BuildContext context, String? rawService) {
    final s = (rawService ?? '').trim();
    final isAr = context.l10n.isArabic;
    if (s == 'Home Nursing Care' || s.toLowerCase() == 'home nursing') {
      return isAr ? 'تمريض منزلي' : 'Home Nursing Care';
    }
    if (s == 'General Doctor') {
      return isAr ? 'طبيب عام' : 'General Doctor';
    }
    if (s == 'Elderly Care') {
      return isAr ? 'رعاية كبار السن' : 'Elderly Care';
    }
    if (s == 'Post-surgery Care') {
      return isAr ? 'رعاية بعد العمليات' : 'Post-surgery Care';
    }
    if (s == 'Physiotherapy') {
      return isAr ? 'علاج طبيعي' : 'Physiotherapy';
    }
    if (s == 'Mental Support') {
      return isAr ? 'دعم نفسي' : 'Mental Support';
    }
    return s.isNotEmpty ? s : (isAr ? 'غير متوفر' : 'Not specified');
  }

  String _localizedPaymentStatus(BuildContext context, String? status) {
    final s = (status ?? '').toLowerCase().trim();
    final isAr = context.l10n.isArabic;
    if (s == 'paid') return isAr ? 'مدفوع' : 'Paid';
    if (s == 'refunded') return isAr ? 'مسترد' : 'Refunded';
    if (s == 'held' || s == 'reserved' || s == 'hold') return isAr ? 'محجوز' : 'Reserved';
    if (s == 'unpaid') return isAr ? 'غير مدفوع' : 'Unpaid';
    return isAr ? 'غير متوفر' : 'Not available';
  }

  String _localizedBookingStatus(BuildContext context, String? rawStatus) {
    final s = (rawStatus ?? '').toLowerCase().trim();
    final isAr = context.l10n.isArabic;
    if (s == 'pending' || s == 'requested' || s == 'request_sent' || s == 'waiting_provider_response') {
      return isAr ? 'بانتظار الرد' : 'Waiting';
    }
    if (s == 'accepted' || s == 'confirmed' || s == 'scheduled' || s == 'approved') {
      return isAr ? 'مؤكد' : 'Confirmed';
    }
    if (s == 'completed' || s == 'done') {
      return isAr ? 'مكتمل' : 'Completed';
    }
    if (s == 'cancelled' || s == 'canceled' || s == 'rejected') {
      return isAr ? 'ملغي' : 'Cancelled';
    }
    return isAr ? 'مؤكد' : 'Confirmed';
  }

  String _shortenAddress(String address) {
    if (address.isEmpty) return '';
    String cleaned = address
        .replaceAll(RegExp(r'Palestinian Territories', caseSensitive: false), 'Palestine')
        .replaceAll(RegExp(r'Palestinian Territory', caseSensitive: false), 'Palestine');
    cleaned = cleaned.replaceAll(RegExp(r'\bArea\s+[A-Z]\b', caseSensitive: false), '');
    
    final parts = cleaned
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .fold<List<String>>([], (list, e) {
          if (!list.contains(e)) list.add(e);
          return list;
        });

    if (parts.isEmpty) return '';
    if (parts.length <= 2) {
      return parts.join(', ');
    }

    final filteredParts = parts.where((p) {
      if (RegExp(r'^\d+$').hasMatch(p)) return false;
      return true;
    }).toList();

    if (filteredParts.isEmpty) return parts.first;

    final first = filteredParts.first;
    final hasWestBank = filteredParts.any((p) => p.toLowerCase() == 'west bank');
    final hasPalestine = filteredParts.any((p) => p.toLowerCase() == 'palestine');
    
    if (hasWestBank) {
      if (first.toLowerCase() != 'west bank') {
        return '$first, West Bank';
      }
    }
    if (hasPalestine) {
      if (first.toLowerCase() != 'palestine') {
        return '$first, Palestine';
      }
    }
    if (filteredParts.length >= 2) {
      return '${filteredParts[0]}, ${filteredParts[1]}';
    }
    return first;
  }



  Future<void> _openRescheduleSheet(Map<String, dynamic> item) async {
    final appointmentId = (item['appointmentId'] ?? item['requestId'] ?? '').toString();
    final providerId = (item['doctorUserId'] ?? item['providerUserId'] ?? '').toString();
    final scheduledAt = (item['scheduledAt'] ?? '').toString();
    if (providerId.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return RescheduleModal(
          appointmentId: appointmentId,
          providerUserId: providerId,
          oldDateTime: scheduledAt,
          onSuccess: () {
            Navigator.pop(sheetCtx);
            fetchAppointments();
          },
        );
      },
    );
  }

  Widget _avatarPlaceholder(String role) {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Icon(
        role.toLowerCase().contains('doctor')
            ? Icons.medical_services_rounded
            : Icons.local_hospital_rounded,
        color: AppColors.primaryDark,
        size: 26,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        final p = CarelinkPalette.of(context);
        final primaryColor = Theme.of(context).colorScheme.primary;

        return Directionality(
          textDirection: localeController.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: p.pageBg,
            body: SafeArea(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: fetchAppointments,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context, primaryColor, p),
                      const SizedBox(height: 16),
                      _buildFilterTabs(),
                      const SizedBox(height: 18),
                      _buildBody(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor, CarelinkPalette p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CarelinkThemeIconButton(color: primaryColor),
            CarelinkLocaleIconButton(color: primaryColor),
          ],
        ),
        const Spacer(),
        Text(
          context.tr('schedule.title'),
          style: TextStyle(
            color: p.inkDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _filterChip(
            label: context.tr('schedule.tabs.waiting'),
            filter: _ScheduleFilter.pending,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: context.tr('schedule.tabs.upcoming'),
            filter: _ScheduleFilter.upcoming,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: context.tr('schedule.tabs.completed'),
            filter: _ScheduleFilter.completed,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: context.tr('schedule.tabs.cancelled'),
            filter: _ScheduleFilter.cancelled,
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required _ScheduleFilter filter,
  }) {
    final p = CarelinkPalette.of(context);
    final isSelected = currentFilter == filter;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        debugPrint('[CareLink Debug] selected tab: ${filter.name}');
        setState(() {
          currentFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                )
              : null,
          color: isSelected ? null : p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : p.stroke,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : p.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final p = CarelinkPalette.of(context);
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.inkDark,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: fetchAppointments,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(context.tr('booking.tryAgain')),
            ),
          ],
        ),
      );
    }

    final filtered = filteredAppointments;

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                color: AppColors.primaryDark,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('schedule.noBookings'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: p.inkDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final isTabular = currentFilter == _ScheduleFilter.completed || currentFilter == _ScheduleFilter.cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(filtered.length, p),
        const SizedBox(height: 12),
        if (isTabular)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.stroke),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildTableHeader(p),
                ...filtered.map((item) => _buildTableRow(item, p)),
              ],
            ),
          )
        else
          Column(
            children: filtered.map((item) => _buildCardView(item, p)).toList(),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(int count, CarelinkPalette p) {
    final title = _getSectionTitleOnly();
    final sub = context.l10n.isArabic
        ? '$count ${count == 1 ? "موعد" : "مواعيد"}'
        : '$count ${count == 1 ? "appointment" : "appointments"}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: p.inkDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: p.inkMuted,
          ),
        ),
      ],
    );
  }

  String _getSectionTitleOnly() {
    final isAr = context.l10n.isArabic;
    switch (currentFilter) {
      case _ScheduleFilter.pending:
        return isAr ? 'المواعيد بانتظار الرد' : 'Waiting Appointments';
      case _ScheduleFilter.upcoming:
        return isAr ? 'المواعيد القادمة (المقبولة)' : 'Upcoming Appointments';
      case _ScheduleFilter.completed:
        return isAr ? 'المواعيد المكتملة' : 'Completed Appointments';
      case _ScheduleFilter.cancelled:
        return isAr ? 'المواعيد الملغاة' : 'Cancelled Appointments';
    }
  }

  String _getDayName(DateTime? date) {
    if (date == null) return '';
    const daysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const daysAr = ['الأثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final idx = date.weekday - 1;
    return context.l10n.isArabic ? daysAr[idx] : daysEn[idx];
  }

  Widget _mockupMetaItem(CarelinkPalette p, IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: p.inkDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView(Map<String, dynamic> item, CarelinkPalette p) {
    final scheduledAt = _parseScheduledAt(item['scheduledAt']);
    final rawStatusDisp = (_rawStatusFromItem(item) ?? '—').toString().trim();
    final status = _normalizedStatus(rawStatusDisp);
    final appointmentId = (item['appointmentId'] ?? item['requestId'] ?? '').toString().trim();
    final providerLabel = (item['providerName'] ?? item['doctorName'] ?? '').toString().trim();
    final providerId = (item['doctorUserId'] ?? item['providerUserId'] ?? '').toString().trim();
    final serviceRaw = (item['serviceType'] ?? '').toString().trim();
    final paymentRaw = (item['paymentStatus'] ?? '').toString().trim();
    final appType = (item['appointmentType'] ?? 'home').toString().toLowerCase().trim();
    final providerRole = item['providerRole']?.toString() ?? '';
    final specialization = (item['specialization'] ?? '').toString().trim();
    final address = (item['visitAddress'] ?? item['location'] ?? '').toString().trim();
    final isHomeVisit = appType != 'remote';
    final isAr = context.l10n.isArabic;

    final isUnpaid = paymentRaw == 'unpaid' || paymentRaw.isEmpty || paymentRaw == 'pending';
    final isAct = status == 'pending' || status == 'upcoming';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PatientCard(
        padding: const EdgeInsets.all(12),
        onTap: appointmentId.isEmpty
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingDetailsScreen(
                      appointmentId: appointmentId,
                      patientUserId: widget.patientUserId,
                    ),
                  ),
                ).then((_) => fetchAppointments());
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: item['profileImageUrl'] != null &&
                          item['profileImageUrl'].toString().isNotEmpty
                      ? Image.network(
                          item['profileImageUrl'].toString(),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => _avatarPlaceholder(providerRole),
                        )
                      : _avatarPlaceholder(providerRole),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        providerLabel.isNotEmpty
                            ? providerLabel
                            : (isAr ? 'مقدم الخدمة' : 'Provider'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: p.inkDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialization.isNotEmpty
                            ? specialization
                            : _localizedProviderRole(context, item),
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(status, p.isDark).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _localizedBookingStatus(context, rawStatusDisp),
                        style: TextStyle(
                          color: _statusColor(status, p.isDark),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: paymentRaw == 'paid'
                            ? const Color(0xFF2E7D32).withValues(alpha: 0.10)
                            : const Color(0xFFC62828).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _localizedPaymentStatus(context, paymentRaw),
                        style: TextStyle(
                          color: paymentRaw == 'paid' ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _mockupMetaItem(
                    p,
                    Icons.calendar_today_rounded,
                    scheduledAt == null
                        ? (isAr ? 'التاريخ غير متوفر' : 'Date unavailable')
                        : '${_formatDate(scheduledAt)} ${_getDayName(scheduledAt)}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _mockupMetaItem(
                    p,
                    Icons.access_time_rounded,
                    _formatTime(scheduledAt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _mockupMetaItem(
                    p,
                    appType == 'remote' ? Icons.videocam_rounded : Icons.home_rounded,
                    _localizedServiceType(context, serviceRaw),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _mockupMetaItem(
                    p,
                    Icons.location_on_rounded,
                    !isHomeVisit ? '—' : (address.isNotEmpty ? _shortenAddress(address) : '—'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isUnpaid && isAct && _isFuture(scheduledAt)) ...[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingDetailsScreen(
                            appointmentId: appointmentId,
                            patientUserId: widget.patientUserId,
                          ),
                        ),
                      ).then((_) => fetchAppointments());
                    },
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: Text(
                      context.tr('schedule.payNow'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    if (providerId.isNotEmpty && _isFuture(scheduledAt)) ...[
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  name: providerLabel,
                                  userId: widget.patientUserId,
                                  doctorId: providerId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                          label: Text(
                            isAr ? 'محادثة' : 'Chat',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        onPressed: appointmentId.isEmpty
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingDetailsScreen(
                                      appointmentId: appointmentId,
                                      patientUserId: widget.patientUserId,
                                    ),
                                  ),
                                ).then((_) => fetchAppointments());
                              },
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: Text(
                          isAr ? 'عرض التفاصيل' : 'Details',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ),
                    if (status == 'pending' && _isFuture(scheduledAt)) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: OutlinedButton.icon(
                          onPressed: () => _openRescheduleSheet(item),
                          icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                          label: Text(
                            context.tr('schedule.edit'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(CarelinkPalette p) {
    final isAr = context.l10n.isArabic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        border: Border(
          bottom: BorderSide(color: p.stroke),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              isAr ? 'مقدم الرعاية' : 'Provider',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: p.inkMuted),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              isAr ? 'التاريخ والوقت' : 'Date & Time',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: p.inkMuted),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isAr ? 'الخدمة' : 'Service',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: p.inkMuted),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isAr ? 'الحالة' : 'Status',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: p.inkMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> item, CarelinkPalette p) {
    final scheduledAt = _parseScheduledAt(item['scheduledAt']);
    final rawStatusDisp = (_rawStatusFromItem(item) ?? '—').toString().trim();
    final status = _normalizedStatus(rawStatusDisp);
    final appointmentId = (item['appointmentId'] ?? item['requestId'] ?? '').toString().trim();
    final providerLabel = (item['providerName'] ?? item['doctorName'] ?? '').toString().trim();
    final providerRole = item['providerRole']?.toString() ?? '';
    final appType = (item['appointmentType'] ?? 'home').toString().toLowerCase().trim();
    final isAr = context.l10n.isArabic;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: appointmentId.isEmpty
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingDetailsScreen(
                      appointmentId: appointmentId,
                      patientUserId: widget.patientUserId,
                    ),
                  ),
                ).then((_) => fetchAppointments());
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(
              bottom: BorderSide(color: p.stroke),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    ClipOval(
                      child: item['profileImageUrl'] != null &&
                              item['profileImageUrl'].toString().isNotEmpty
                          ? Image.network(
                              item['profileImageUrl'].toString(),
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => _avatarPlaceholderSmall(providerRole),
                            )
                          : _avatarPlaceholderSmall(providerRole),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            providerLabel.isNotEmpty ? providerLabel : (isAr ? 'مقدم الخدمة' : 'Provider'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: p.inkDark,
                            ),
                          ),
                          Text(
                            _localizedProviderRole(context, item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: p.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(scheduledAt),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: p.inkDark,
                      ),
                    ),
                    Text(
                      _formatTime(scheduledAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: p.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  appType == 'remote'
                      ? (isAr ? 'استشارة عن بعد' : 'Remote')
                      : (isAr ? 'زيارة منزلية' : 'Home Visit'),
                  style: TextStyle(
                    fontSize: 11,
                    color: p.inkDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status, p.isDark).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _localizedBookingStatus(context, rawStatusDisp),
                      style: TextStyle(
                        color: _statusColor(status, p.isDark),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholderSmall(String role) {
    return Container(
      width: 32,
      height: 32,
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Icon(
        role.toLowerCase().contains('doctor')
            ? Icons.medical_services_rounded
            : Icons.local_hospital_rounded,
        color: AppColors.primaryDark,
        size: 16,
      ),
    );
  }
}

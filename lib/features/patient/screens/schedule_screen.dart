import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart' show DateFormat;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/features/patient/widgets/carelink_patient_app_bar.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'booking_details_screen.dart';

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
  bool _missingPatientAccount = false;
  _ScheduleFilter currentFilter = _ScheduleFilter.pending;
  final ApiService _api = ApiService();

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
        _missingPatientAccount = true;
        errorMessage = null;
      });
      return;
    }

    try {
      _dbg(
        'patientUserId sent to APIs (must match servicerequest.patientUserId): "${widget.patientUserId}"',
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

      final completedAfterFilter = merged
          .where(
            (row) => _normalizedStatus(_rawStatusFromItem(row)) == 'completed',
          )
          .length;
      _dbg(
        'merged unique appointments: ${merged.length}; completed (normalized): $completedAfterFilter',
      );
      if (kDebugMode && merged.isNotEmpty) {
        final sample = merged
            .take(6)
            .map(
              (m) =>
                  '${m['appointmentId']}: status=${m['status']}, pay=${m['paymentStatus']}',
            )
            .join(' | ');
        _dbg('sample merged: $sample');
      }

      if (!mounted) return;

      setState(() {
        appointments = merged;
        isLoading = false;
        errorMessage = null;
        _missingPatientAccount = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        _missingPatientAccount = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
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
    if (status == 'pending' || status == 'requested' || status == 'request_sent') {
      return 'pending';
    }
    if (status == 'approved' || status == 'confirmed' || status == 'scheduled') {
      return 'upcoming';
    }
    if (status == 'complete' || status == 'completed') return 'completed';
    if (status == 'cancelled' || status == 'canceled') return 'cancelled';
    return 'upcoming';
  }

  bool _paymentAllowsRating(Map<String, dynamic> item) {
    final p = (item['paymentStatus'] ?? '').toString().toLowerCase().trim();
    if (p.isEmpty) return true;
    return p == 'paid';
  }

  bool _alreadyRated(Map<String, dynamic> item) {
    final hp = item['hasPatientRating'];
    if (hp == true || hp == 1 || hp == '1') return true;
    final stars = item['patientRatingStars'];
    final n = stars is num
        ? stars.round()
        : int.tryParse(stars?.toString() ?? '') ?? 0;
    return n >= 1;
  }

  bool _shouldShowRateButton(Map<String, dynamic> item, String normStatus) {
    if (normStatus != 'completed') return false;
    if (!_paymentAllowsRating(item)) return false;
    if (_alreadyRated(item)) return false;
    return true;
  }

  Future<void> _openRateSheet({
    required String appointmentId,
    required String providerLabel,
  }) async {
    final comment = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        int stars = 5;
        var busy = false;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            Future<void> submit() async {
              if (busy || stars < 1) return;
              setModalState(() => busy = true);
              try {
                await _api.rateCompletedVisit(
                  appointmentId: appointmentId,
                  patientUserId: widget.patientUserId,
                  stars: stars,
                  comment: comment.text.trim().isEmpty
                      ? null
                      : comment.text.trim(),
                );
                if (!sheetCtx.mounted) return;
                Navigator.pop(sheetCtx);
                await fetchAppointments();
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr('patient.schedule.ratingSavedThanks'),
                    ),
                  ),
                );
              } catch (e) {
                setModalState(() => busy = false);
                if (!sheetCtx.mounted) return;
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString().replaceFirst('Exception: ', ''),
                    ),
                  ),
                );
              }
            }

            final bottomInset = MediaQuery.viewInsetsOf(modalCtx).bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sheetCtx.tr(
                      'patient.visitRating.sheetTitleNamed',
                      args: {'name': providerLabel},
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sheetCtx.tr('patient.visitRating.shortScaleHint'),
                    style:
                        const TextStyle(color: AppColors.textLight, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final n = i + 1;
                      final selected = stars >= n;
                      return IconButton(
                        onPressed:
                            busy ? null : () => setModalState(() => stars = n),
                        icon: Icon(
                          selected ? Icons.star_rounded : Icons.star_border_rounded,
                          color: selected
                              ? const Color(0xFFF59E0B)
                              : AppColors.textLight,
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: comment,
                    enabled: !busy,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: sheetCtx.tr('patient.visitRating.optionalComment'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(sheetCtx.tr('patient.visitRating.submitBtn')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    } finally {
      comment.dispose();
    }
  }

  DateTime? _parseScheduledAt(dynamic rawValue) {
    final value = rawValue?.toString();
    if (value == null || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  String _formatDate(BuildContext context, DateTime? date) {
    if (date == null) return context.tr('patient.dateUnavailable');
    final locTag = localeController.locale.toLanguageTag();
    try {
      return DateFormat.yMMMd(locTag).format(date.toLocal());
    } catch (_) {
      return DateFormat.yMMMd('en').format(date.toLocal());
    }
  }

  String _formatTime(BuildContext context, DateTime? date) {
    if (date == null) return context.tr('patient.timeUnavailable');
    final locTag = localeController.locale.toLanguageTag();
    try {
      return DateFormat.jm(locTag).format(date.toLocal());
    } catch (_) {
      return DateFormat.jm('en').format(date.toLocal());
    }
  }

  String _providerRoleLabel(BuildContext context, dynamic item) {
    final role = item['providerRole']?.toString().toLowerCase();
    if (role == 'doctor') return context.tr('patient.role.doctor');
    if (role == 'nurse') return context.tr('patient.role.nurse');
    return context.tr('patient.careProviderGeneric');
  }

  String _displayProviderName(BuildContext context, Map<String, dynamic> item) {
    final raw =
        (item['providerName'] ?? item['doctorName'] ?? '').toString().trim();
    if (raw.isEmpty) return '';

    final role = item['providerRole']?.toString().toLowerCase();
    final lower = raw.toLowerCase();
    final hasDoctorPrefix =
        lower.startsWith('dr.') ||
        lower.startsWith('dr ') ||
        lower.startsWith('doctor ');

    if (role == 'doctor' &&
        !hasDoctorPrefix &&
        !lower.startsWith('د.')) {
      return '${context.tr('patient.namePrefixDoctor')} $raw';
    }
    return raw;
  }

  String _paymentDisplayLabel(String paymentRaw) {
    final r = paymentRaw.trim();
    if (r.isEmpty) return '\u2014';
    final lower = r.toLowerCase();
    if (lower == 'paid' || lower == 'unpaid') return lower;
    return r;
  }

  /// Uses optional `paymentCardLast4` from appointment list joins.
  String _schedulePaymentSummary(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final st =
        (item['paymentStatus'] ?? '').toString().toLowerCase().trim();
    final last4 = (item['paymentCardLast4'] ?? '').toString().trim();
    if (st == 'paid') {
      if (last4.length == 4) {
        return context.tr(
          'patient.pay.paidByVisaMasked',
          args: {'last4': last4},
        );
      }
      return context.tr('patient.pay.paidByVisa');
    }
    if (st.isEmpty || st == 'unpaid') return context.tr('patient.pay.unpaid');
    if (st == 'pending') return context.tr('patient.pay.pending');
    if (st == 'failed') return context.tr('patient.pay.failed');
    if (st == 'declined') return context.tr('patient.pay.declined');
    return _paymentDisplayLabel(st);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFEA580C);
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'cancelled':
        return const Color(0xFFC62828);
      default:
        return AppColors.primaryDark;
    }
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'pending':
        return context.tr('patient.schedule.badge.pendingApproval');
      case 'completed':
        return context.tr('patient.status.completed');
      case 'cancelled':
        return context.tr('patient.status.cancelled');
      default:
        return context.tr('patient.schedule.badge.upcoming');
    }
  }

  String _emptyHeadline(BuildContext context) {
    switch (currentFilter) {
      case _ScheduleFilter.pending:
        return context.tr('patient.schedule.empty.pending');
      case _ScheduleFilter.upcoming:
        return context.tr('patient.schedule.empty.upcoming');
      case _ScheduleFilter.completed:
        return context.tr('patient.schedule.empty.completed');
      case _ScheduleFilter.cancelled:
        return context.tr('patient.schedule.empty.cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: carelinkPatientAppBar(
        context,
        title:
            CarelinkAppBarTitle.forPatient(context, context.tr('patient.title.schedule')),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: fetchAppointments,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(context),
              const SizedBox(height: 18),
              _buildFilterTabs(context),
              const SizedBox(height: 18),
              _buildBody(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('patient.schedule.heroTitle'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('patient.schedule.heroSubtitle'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _filterChip(
            label: context.tr('patient.schedule.filterPending'),
            filter: _ScheduleFilter.pending,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _filterChip(
            label: context.tr('patient.schedule.filterUpcoming'),
            filter: _ScheduleFilter.upcoming,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _filterChip(
            label: context.tr('patient.schedule.filterCompleted'),
            filter: _ScheduleFilter.completed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _filterChip(
            label: context.tr('patient.schedule.filterCancelled'),
            filter: _ScheduleFilter.cancelled,
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required _ScheduleFilter filter,
  }) {
    final isSelected = currentFilter == filter;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          currentFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryDark
                : AppColors.primaryDark.withValues(alpha: 0.45),
            width: 1.25,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_missingPatientAccount || errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
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
              _missingPatientAccount
                  ? context.tr('patient.error.accountMissing')
                  : errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
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
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(context.tr('patient.action.tryAgain')),
            ),
          ],
        ),
      );
    }

    if (filteredAppointments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                color: AppColors.primaryDark,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _emptyHeadline(context),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('patient.schedule.emptyHint'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: filteredAppointments.map((item) {
        final scheduledAt = _parseScheduledAt(item['scheduledAt']);
        final completedAt = _parseScheduledAt(item['completedAt']);
        final rawStatusDisp = (_rawStatusFromItem(item) ?? '—').toString().trim();
        final status = _normalizedStatus(rawStatusDisp);
        final appointmentId = (item['appointmentId'] ?? item['requestId'] ?? '')
            .toString()
            .trim();
        final providerLabel = _displayProviderName(context, item);
        final providerId = (item['doctorUserId'] ?? item['providerUserId'] ?? '')
            .toString()
            .trim();
        final serviceRaw =
            (item['serviceType'] ?? '').toString().trim();
        final paymentSummary = _schedulePaymentSummary(context, item);

        final ratedShown =
            status == 'completed' && _alreadyRated(item);

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
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
                          );
                        },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    providerLabel.isNotEmpty
                                        ? providerLabel
                                        : (providerId.isNotEmpty
                                            ? context.tr(
                                                'patient.schedule.providerIdFallback',
                                              )
                                            : context.tr(
                                                'patient.providerFallback',
                                              )),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  if (providerLabel.isEmpty &&
                                      providerId.isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        providerId,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    '${_providerRoleLabel(context, item)} · ${item['specialization']?.toString().trim().isNotEmpty == true ? item['specialization']!.toString().trim() : context.tr('patient.schedule.specialtyUnavailable')}',
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: status == 'pending'
                                    ? const Color(0xFFFFECDD)
                                    : _statusColor(status)
                                        .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _statusLabel(context, status),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${context.tr('patient.schedule.serviceLabel')}: ${serviceRaw.isEmpty ? '\u2014' : serviceRaw}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (status == 'completed') ...[
                          const SizedBox(height: 6),
                          Text(
                            context.tr(
                              'patient.schedule.completedAt',
                              args: {
                                'date': _formatDate(context, completedAt),
                                'time': _formatTime(context, completedAt),
                              },
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          context.tr(
                            'patient.schedule.paymentPrefix',
                            args: {'detail': paymentSummary},
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr(
                            'patient.schedule.apiStatusRow',
                            args: {'status': rawStatusDisp},
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _scheduleMeta(
                                icon: Icons.event_rounded,
                                title: context.tr(
                                  'patient.schedule.scheduledDate',
                                ),
                                value: _formatDate(context, scheduledAt),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _scheduleMeta(
                                icon: Icons.access_time_rounded,
                                title: context.tr(
                                  'patient.schedule.scheduledTime',
                                ),
                                value: _formatTime(context, scheduledAt),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_shouldShowRateButton(item, status))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.star_outline_rounded),
                    label: Text(context.tr('patient.schedule.rateProvider')),
                    onPressed: () => _openRateSheet(
                      appointmentId: appointmentId,
                      providerLabel: providerLabel.isEmpty
                          ? context.tr('patient.providerFallback')
                          : providerLabel,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (ratedShown)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green.shade700,
                        size: 18,
                      ),
                      label: Text(
                        context.tr('patient.schedule.ratedBadge'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      backgroundColor: const Color(0xFFE8F5E9),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _scheduleMeta({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
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

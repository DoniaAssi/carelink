import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/screens/provider_details_screen.dart';
import 'package:carelink/features/patient/screens/chat_screen.dart';
import 'package:carelink/features/patient/utils/appointment_action_helper.dart';
import 'package:carelink/features/patient/utils/rebook_flow_helper.dart';
import 'package:carelink/shared/services/patient_recent_chats_service.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/features/patient/widgets/reschedule_modal.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String appointmentId;
  final String patientUserId;

  const BookingDetailsScreen({
    super.key,
    required this.appointmentId,
    required this.patientUserId,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final ApiService _api = ApiService();
  final MapController _mapController = MapController();
  final TextEditingController _ratingComment = TextEditingController();

  bool isLoading = true;
  bool isCancelling = false;
  String? errorMessage;

  AppointmentModel? appointment;
  ProviderModel? provider;
  Map<String, dynamic>? _paymentOverview;
  Map<String, dynamic>? _refundRequest;

  Timer? _pollTimer;
  int _draftStars = 0;
  bool _ratingBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ratingComment.dispose();
    super.dispose();
  }

  void _setPolling() {
    _pollTimer?.cancel();
    final s = appointment?.status.toLowerCase() ?? '';
    if (s == 'confirmed') {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _load(silent: true),
      );
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final data = await _api.getAppointmentDetails(widget.appointmentId);
      final apt = AppointmentModel.fromJson(data);

      ProviderModel? prov;
      try {
        final provData = await _api.getProviderById(
          apt.providerUserId,
          realAvailability: true,
        );
        prov = ProviderModel.fromJson(provData);
      } catch (_) {
        // Fallback or mute if provider fetch fails
      }

      if (!mounted) return;
      setState(() {
        appointment = apt;
        provider = prov;
        isLoading = false;
      });
      await _refreshPaymentOverview();
      await _refreshRefundRequest();
      _setPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = context.l10n.userMessage(e);
        isLoading = false;
      });
    }
  }

  Future<void> _refreshPaymentOverview() async {
    try {
      final data = await _api.getAppointmentPayment(
        appointmentId: widget.appointmentId,
        patientUserId: widget.patientUserId,
      );
      if (!mounted) return;
      setState(() => _paymentOverview = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _paymentOverview = null);
    }
  }

  Future<void> _refreshRefundRequest() async {
    try {
      final data = await _api.getRefundRequest(
        appointmentId: widget.appointmentId,
        patientUserId: widget.patientUserId,
      );
      if (!mounted) return;
      setState(
        () => _refundRequest = data['request'] is Map
            ? Map<String, dynamic>.from(data['request'] as Map)
            : null,
      );
    } catch (_) {
      if (mounted) setState(() => _refundRequest = null);
    }
  }

  double? _hintAmountFromOverview() {
    final o = _paymentOverview;
    if (o == null) return null;
    for (final k in ['expectedAmount', 'amount']) {
      final v = o[k];
      if (v == null) continue;
      final n = double.tryParse(v.toString());
      if (n != null && n > 0) return n;
    }
    return null;
  }

  String _ledgerPaymentStatus(AppointmentModel a) {
    final fromApi = (_paymentOverview?['paymentStatus'] ?? '')
        .toString()
        .trim();
    if (fromApi.isNotEmpty) return fromApi;
    return a.paymentStatus;
  }

  bool get _canCancel {
    final status = appointment?.status.toLowerCase().trim() ?? '';
    final scheduledAt = appointment?.scheduledAt;
    if (scheduledAt == null || !scheduledAt.isAfter(DateTime.now())) {
      return false;
    }
    return const {
      'pending_provider_approval',
      'waiting_for_approval',
      'waiting for approval',
      'waiting',
      'pending',
      'awaiting_provider_approval',
      'waiting_provider_response',
      'waiting response',
      'requested',
      'request_sent',
      'new',
      'pending_payment',
      'payment_pending',
      'accepted',
      'provider_accepted',
      'confirmed',
      'paid',
      'in_progress',
      'provider_approved',
      'approved',
      'scheduled',
    }.contains(status);
  }

  Future<void> _cancel() async {
    setState(() => isCancelling = true);
    final isAr = localeController.isArabic;
    unawaited(
      _showPremiumCancellationModal<void>(
        barrierDismissible: false,
        builder: (_) => _cancellationStateDialog(
          icon: Icons.hourglass_top_rounded,
          color: const Color(0xFFD93636),
          title: isAr ? 'جارٍ إلغاء الحجز...' : 'Cancelling booking...',
          loading: true,
        ),
      ),
    );
    try {
      final result = await _api.cancelAppointment(
        appointmentId: widget.appointmentId,
        patientUserId: widget.patientUserId,
        reason: 'Cancelled from mobile app',
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final refundAmount = double.tryParse(
        (result['refundAmount'] ?? '').toString(),
      );
      final currency = (result['currency'] ?? 'ILS').toString();
      await _showPremiumCancellationModal<void>(
        barrierDismissible: false,
        builder: (dialogContext) => _cancellationStateDialog(
          icon: Icons.check_rounded,
          color: const Color(0xFF22A06B),
          title: isAr ? 'تم إرسال طلب الإلغاء' : 'Cancellation submitted',
          subtitle: isAr
              ? 'تم إلغاء الحجز. طلب الاسترداد قيد مراجعة الإدارة.'
              : 'Cancellation submitted. Your refund request is pending admin review.',
          details: result['refundRequest'] != null && refundAmount != null
              ? [
                  (
                    isAr ? 'المبلغ المطلوب' : 'Requested refund',
                    '${refundAmount.toStringAsFixed(2)} $currency',
                  ),
                ]
              : null,
          buttonLabel: isAr ? 'تم' : 'Done',
          onPressed: () => Navigator.pop(dialogContext),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final reason = _cancellationFailureReason(e, isAr);
      await _showPremiumCancellationModal<void>(
        barrierDismissible: false,
        builder: (dialogContext) => _cancellationStateDialog(
          icon: Icons.close_rounded,
          color: const Color(0xFFD93636),
          title: isAr ? 'فشل الإلغاء' : 'Cancellation Failed',
          subtitle: reason,
          secondaryLabel: isAr ? 'إغلاق' : 'Close',
          onSecondary: () => Navigator.pop(dialogContext),
          buttonLabel: isAr ? 'إعادة المحاولة' : 'Retry',
          onPressed: () {
            Navigator.pop(dialogContext);
            _cancel();
          },
        ),
      );
    } finally {
      if (mounted) setState(() => isCancelling = false);
    }
  }

  void _openRescheduleModal() {
    if (appointment == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return RescheduleModal(
          appointment: appointment!,
          onSuccess: () {
            Navigator.pop(sheetCtx);
            _load();
          },
        );
      },
    );
  }

  Future<void> _showRebookChoices() async {
    final apt = appointment;
    if (apt == null) return;
    await RebookFlowHelper.startFromAppointment(
      context: context,
      appointment: apt,
      patientUserId: widget.patientUserId,
      priceHint: _hintAmountFromOverview(),
    );
  }

  String _formatUpdated(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours} hr ago';
  }

  bool get _showLiveMap {
    final s = appointment?.status.toLowerCase() ?? '';
    if (s != 'confirmed') return false;
    final a = appointment;
    if (a == null) return false;
    final hasVisit = a.visitLatitude != null && a.visitLongitude != null;
    final hasProv =
        a.providerCurrentLat != null && a.providerCurrentLng != null;
    return hasVisit || hasProv;
  }

  String _roleHeroAsset(String role) {
    final r = role.toLowerCase();
    if (r.contains('nurse')) return 'assets/images/nursemedical.jpg';
    if (r.contains('doctor')) return 'assets/images/doctorportrait.jpg';
    return 'assets/images/healthcare.jpg';
  }

  Map<String, String> _parseNotes(String rawNotes) {
    final result = <String, String>{};
    if (rawNotes.isEmpty) return result;

    if (rawNotes.contains('|')) {
      final parts = rawNotes.split('|');
      result['service'] = parts[0].trim();
      for (int i = 1; i < parts.length; i++) {
        final part = parts[i].trim();
        final colonIndex = part.indexOf(':');
        if (colonIndex != -1) {
          final key = part.substring(0, colonIndex).trim().toLowerCase();
          final value = part.substring(colonIndex + 1).trim();
          if ([
            'service',
            'address',
            'currentcase',
            'reason',
            'visitgps',
            'location',
            'visit gps',
            'current case',
            'reason for visit',
          ].contains(key)) {
            var normalizedKey = key;
            if (key == 'visit gps') normalizedKey = 'visitgps';
            if (key == 'current case') normalizedKey = 'currentcase';
            if (key == 'reason for visit') normalizedKey = 'reason';
            result[normalizedKey] = value;
          }
        }
      }
    } else {
      final lines = rawNotes.split(RegExp(r'[\n\r]'));
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final colonIndex = trimmed.indexOf(':');
        if (colonIndex != -1) {
          final key = trimmed.substring(0, colonIndex).trim().toLowerCase();
          final value = trimmed.substring(colonIndex + 1).trim();

          if ([
            'service',
            'address',
            'currentcase',
            'reason',
            'visitgps',
            'location',
            'visit gps',
            'current case',
            'reason for visit',
          ].contains(key)) {
            var normalizedKey = key;
            if (key == 'visit gps') normalizedKey = 'visitgps';
            if (key == 'current case') normalizedKey = 'currentcase';
            if (key == 'reason for visit') normalizedKey = 'reason';
            result[normalizedKey] = value;
          }
        }
      }
    }
    return result;
  }

  String _cleanNotes(String rawNotes) {
    if (rawNotes.isEmpty) return '';
    if (rawNotes.contains('|')) {
      return '';
    }
    final lines = rawNotes.split(RegExp(r'[\n\r]'));
    final cleanLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final colonIndex = trimmed.indexOf(':');
      if (colonIndex != -1) {
        final key = trimmed.substring(0, colonIndex).trim().toLowerCase();
        if ([
          'service',
          'address',
          'currentcase',
          'reason',
          'visitgps',
          'location',
          'visit gps',
          'current case',
          'reason for visit',
        ].contains(key)) {
          continue;
        }
      }
      cleanLines.add(trimmed);
    }
    return cleanLines.join('\n').trim();
  }

  String _shortenAddress(String address) {
    if (address.isEmpty) return '';
    String cleaned = address
        .replaceAll(
          RegExp(r'Palestinian Territories', caseSensitive: false),
          'Palestine',
        )
        .replaceAll(
          RegExp(r'Palestinian Territory', caseSensitive: false),
          'Palestine',
        );
    cleaned = cleaned.replaceAll(
      RegExp(r'\bArea\s+[A-Z]\b', caseSensitive: false),
      '',
    );

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
    final hasWestBank = filteredParts.any(
      (p) => p.toLowerCase() == 'west bank',
    );
    final hasPalestine = filteredParts.any(
      (p) => p.toLowerCase() == 'palestine',
    );

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        final p = CarelinkPalette.of(context);
        final isAr = localeController.isArabic;
        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: PatientScaffold(
            backgroundColor: p.pageBg,
            appBar: PatientAppBar(
              title: isAr ? 'تفاصيل الحجز' : 'Booking Details',
              onBack: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/patient-home',
                    (route) => false,
                  );
                }
              },
            ),
            body: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : errorMessage != null
                ? Center(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : appointment == null
                ? const SizedBox.shrink()
                : SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                if (_showLiveMap)
                                  _buildMapCard(p, appointment!),

                                _buildNurseProviderCard(p),
                                const SizedBox(height: 16),

                                _buildReferenceAppointmentInfoCard(p),
                                const SizedBox(height: 12),

                                _buildStatusBannerSection(p),
                                const SizedBox(height: 12),

                                if (_refundRequest != null) ...[
                                  _buildRefundRequestStatusCard(p),
                                  const SizedBox(height: 12),
                                ],

                                _buildVisitRatingSection(p, appointment!),
                              ],
                            ),
                          ),
                        ),
                        _buildStickyBottomActions(p),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBannerSection(CarelinkPalette p) {
    var status = appointment!.status.toLowerCase().trim();
    final scheduledAt = appointment!.scheduledAt;
    if (scheduledAt != null && scheduledAt.isBefore(DateTime.now())) {
      if (status == 'in_progress' || status == 'waiting_report') {
        status = 'pending_completion';
      } else if (const {
        'pending_provider_approval',
        'pending',
        'waiting',
        'requested',
        'request_sent',
      }.contains(status)) {
        status = 'expired';
      } else if (const {
        'pending_payment',
        'payment_pending',
        'confirmed',
        'accepted',
        'approved',
        'scheduled',
      }.contains(status)) {
        status = 'missed';
      }
    }
    final subStatus = appointment!.subStatus.toLowerCase().trim();
    final isAr = localeController.isArabic;

    Color bg;
    Color textCol;
    String title;
    String subtitle;

    if (subStatus == 'reschedule_requested') {
      bg = AppColors.warning.withValues(alpha: 0.12);
      textCol = AppColors.warning;
      title = isAr
          ? 'طلب تغيير الموعد بانتظار الموافقة'
          : 'Reschedule request pending approval';
      final requested = appointment!.requestedRescheduleAt;
      subtitle = requested == null
          ? (isAr
                ? 'موعدك الأصلي ما زال مؤكداً حتى يوافق مقدم الرعاية.'
                : 'Your original appointment remains confirmed until the provider approves.')
          : (isAr
                ? 'موعدك الأصلي ما زال مؤكداً. الموعد المطلوب: ${_formatDateOnly(requested)} ${_formatTimeOnly(requested)}'
                : 'Your original appointment remains confirmed. Requested time: ${_formatDateOnly(requested)} ${_formatTimeOnly(requested)}');
    } else if (appointment!.rescheduleRejectedAt != null &&
        status == 'confirmed') {
      bg = Colors.redAccent.withValues(alpha: 0.10);
      textCol = Colors.redAccent;
      title = isAr ? 'تم رفض طلب تغيير الموعد' : 'Reschedule request rejected';
      subtitle = isAr
          ? 'تم رفض طلب تغيير الموعد، وبقي موعدك الأصلي كما هو.'
          : 'Your reschedule request was rejected, and your original appointment remains unchanged.';
    } else if (status == 'pending_payment' || status == 'payment_pending') {
      bg = Colors.orange.withValues(alpha: 0.12);
      textCol = const Color(0xFFE56B16);
      title = isAr ? 'بانتظار الدفع' : 'Waiting Payment';
      subtitle = isAr
          ? 'يرجى إكمال الدفع قبل تأكيد الموعد.'
          : 'Please complete payment before your appointment is confirmed.';
    } else if (status == 'confirmed' || status == 'accepted') {
      bg = Colors.green.withValues(alpha: 0.12);
      textCol = const Color(0xFF15803D);
      title = isAr ? 'تم قبول الطلب' : 'Accepted — visit on schedule';
      subtitle = isAr
          ? 'يمكنك متابعة مقدم الخدمة على الخريطة عندما يشارك موقعه المباشر.'
          : 'You can follow the care provider on the map when they share live location.';
    } else if (status == 'pending_provider_approval' ||
        status == 'pending' ||
        status == 'request_sent' ||
        status == 'requested' ||
        status == 'waiting') {
      bg = AppColors.primary.withValues(alpha: 0.12);
      textCol = AppColors.primary;
      title = isAr ? 'بانتظار رد مقدم الخدمة' : 'Waiting for provider response';
      subtitle = isAr
          ? 'سنخبرك عند قبول أو رفض الطلب'
          : 'The provider can accept or decline. We will notify you here.';
    } else if (status == 'expired' || status == 'request_expired') {
      bg = const Color(0xFF64748B).withValues(alpha: 0.1);
      textCol = const Color(0xFF64748B);
      title = isAr ? 'انتهت صلاحية الطلب' : 'Request Expired';
      subtitle = isAr
          ? 'لم يوافق مقدم الخدمة قبل وقت الموعد، وسيُسترد المبلغ كاملاً.'
          : 'The provider did not approve in time. A full refund applies.';
    } else if (status == 'missed' || status == 'no_show') {
      bg = const Color(0xFF9A5B45).withValues(alpha: 0.1);
      textCol = const Color(0xFF9A5B45);
      title = isAr ? 'موعد فائت' : 'Missed Appointment';
      subtitle = isAr
          ? 'لا يمكن إلغاء الموعد الآن. يبقى الدفع قيد المراجعة دون استرداد تلقائي.'
          : 'This can no longer be cancelled. Payment remains held for review.';
    } else if (status == 'pending_completion') {
      bg = const Color(0xFF7C6FA8).withValues(alpha: 0.1);
      textCol = const Color(0xFF7C6FA8);
      title = isAr ? 'بانتظار تأكيد الإتمام' : 'Pending Completion';
      subtitle = isAr
          ? 'بدأت الخدمة ولم يتم تأكيد اكتمالها بعد.'
          : 'The service started but completion has not been confirmed yet.';
    } else if (status == 'completed') {
      bg = p.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      textCol = p.inkMuted;
      title = isAr ? 'اكتملت الزيارة' : 'Visit completed';
      subtitle = isAr
          ? 'قيم مقدم الخدمة بعد الخدمة — يساعدنا ذلك في تحسين المطابقة.'
          : 'Rate your provider after the service to help future smart matches.';
    } else if (status == 'cancelled' ||
        status == 'canceled' ||
        status == 'rejected') {
      bg = Colors.red.withValues(alpha: 0.1);
      textCol = Colors.redAccent;
      title = isAr ? 'ملغي' : 'Booking Cancelled';
      subtitle = isAr
          ? 'تم إلغاء هذا الموعد.'
          : 'This appointment has been cancelled.';
    } else {
      bg = p.surfaceSoft;
      textCol = p.inkDark;
      title = isAr ? 'غير معروف' : 'Unknown';
      subtitle = '';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textCol.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: textCol, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textCol,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: textCol.withValues(alpha: 0.85),
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRefundRequestStatusCard(CarelinkPalette p) {
    final isAr = localeController.isArabic;
    final status = (_refundRequest?['status'] ?? 'pending').toString();
    final color = status == 'rejected'
        ? const Color(0xFFD93636)
        : status == 'processed' || status == 'approved'
        ? const Color(0xFF15803D)
        : const Color(0xFFF59E0B);
    final label = status == 'rejected'
        ? (isAr ? 'تم رفض طلب الاسترداد' : 'Refund Rejected')
        : status == 'processed' || status == 'approved'
        ? (isAr ? 'تمت الموافقة على الاسترداد' : 'Refund Approved')
        : (isAr ? 'طلب الاسترداد قيد المراجعة' : 'Refund Request Pending');
    final note = (_refundRequest?['adminNote'] ?? '').toString().trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note, style: TextStyle(color: p.inkMuted, height: 1.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNurseProviderCard(CarelinkPalette p) {
    final overallRating = provider?.overallRating;
    final experience = provider?.experienceYears;
    final role = appointment!.providerRole.isNotEmpty
        ? appointment!.providerRole
        : 'Nurse';
    final isAr = localeController.isArabic;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                _roleHeroAsset(role),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: p.surfaceSoft,
                  child: Icon(
                    Icons.person_rounded,
                    size: 38,
                    color: p.inkMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment!.providerName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.inkDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  appointment!.specialization.isNotEmpty
                      ? appointment!.specialization
                      : role,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (overallRating != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            overallRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: p.inkDark,
                            ),
                          ),
                        ],
                      ),
                    if (experience != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.work_history_rounded,
                            color: p.inkMuted,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAr
                                ? '$experience سنوات خبرة'
                                : '$experience yrs exp',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: p.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    if (provider?.isAvailable == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAr ? 'متاح اليوم' : 'Available today',
                          style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (provider != null) ...[
                  const SizedBox(height: 8),
                  PatientPressable(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProviderDetailsScreen(
                            provider: provider!,
                            patientUserId: widget.patientUserId,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        10,
                        7,
                        8,
                        7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(
                          alpha: p.isDark ? 0.14 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 17,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isAr ? 'عرض الملف الشخصي' : 'View Profile',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            isAr
                                ? Icons.chevron_left_rounded
                                : Icons.chevron_right_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        PatientRecentChatsService.logChat({
                          'providerId': provider!.userId,
                          'displayName': provider!.fullName,
                          'specialty': provider!.specialization,
                          'profilePictureUrl': null,
                          'rating': provider!.overallRating,
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              name: provider!.fullName,
                              userId: widget.patientUserId,
                              doctorId: provider!.userId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                      ),
                      label: Text(
                        isAr ? 'مراسلة مقدم الرعاية' : 'Message Provider',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceAppointmentInfoCard(CarelinkPalette p) {
    final isAr = localeController.isArabic;
    final notes = _parseNotes(appointment!.notes);
    final service =
        notes['service'] ??
        (provider?.serviceType.isNotEmpty == true
            ? provider!.serviceType
            : appointment!.providerRole);
    final address = _shortenAddress(
      notes['address'] ??
          (appointment!.visitAddress.isNotEmpty
              ? appointment!.visitAddress
              : appointment!.location),
    );
    final payment = _ledgerPaymentStatus(appointment!).toLowerCase();
    final paymentText = switch (payment) {
      'paid' => isAr ? 'مدفوع' : 'Paid',
      'refunded' => isAr ? 'مسترد' : 'Refunded',
      'pending' => isAr ? 'قيد المعالجة' : 'Pending',
      _ => isAr ? 'غير مدفوع' : 'Unpaid',
    };
    final paymentColor = switch (payment) {
      'paid' => const Color(0xFF15803D),
      'refunded' => const Color(0xFF2563EB),
      'pending' => const Color(0xFFD97706),
      _ => const Color(0xFFDC2626),
    };
    final status = appointment!.status.toLowerCase().trim();
    final statusText = switch (status) {
      'pending' || 'pending_provider_approval' =>
        isAr ? 'بانتظار الرد' : 'Waiting for approval',
      'confirmed' || 'accepted' => isAr ? 'مؤكد' : 'Confirmed',
      'in_progress' => isAr ? 'قيد التنفيذ' : 'In progress',
      'completed' => isAr ? 'مكتمل' : 'Completed',
      'cancelled' || 'rejected' => isAr ? 'ملغي' : 'Cancelled',
      'expired' => isAr ? 'انتهت صلاحية الطلب' : 'Request expired',
      'missed' => isAr ? 'موعد فائت' : 'Missed appointment',
      _ => appointment!.status,
    };
    final statusColor = switch (status) {
      'confirmed' || 'accepted' => const Color(0xFF2563EB),
      'in_progress' => AppColors.primary,
      'completed' => const Color(0xFF15803D),
      'cancelled' || 'rejected' || 'missed' => const Color(0xFFDC2626),
      _ => const Color(0xFFD97706),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isAr ? 'معلومات الموعد' : 'Appointment Information',
              style: TextStyle(
                color: p.inkDark,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.14 : 0.035),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              _referenceInfoRow(
                p,
                label: isAr ? 'التاريخ' : 'Date',
                value: _formatDateOnly(appointment!.scheduledAt),
                icon: Icons.calendar_today_outlined,
              ),
              _referenceDivider(p),
              _referenceInfoRow(
                p,
                label: isAr ? 'الوقت' : 'Time',
                value: _formatTimeOnly(appointment!.scheduledAt),
                icon: Icons.access_time_rounded,
                ltrValue: true,
              ),
              _referenceDivider(p),
              _referenceInfoRow(
                p,
                label: isAr ? 'الموقع' : 'Location',
                value: address.isEmpty ? '—' : address,
                icon: Icons.location_on_outlined,
              ),
              _referenceDivider(p),
              _referenceInfoRow(
                p,
                label: isAr ? 'حالة الدفع' : 'Payment status',
                value: paymentText,
                icon: Icons.credit_card_outlined,
                badgeColor: paymentColor,
              ),
              _referenceDivider(p),
              _referenceInfoRow(
                p,
                label: isAr ? 'حالة الموعد' : 'Appointment status',
                value: statusText,
                icon: Icons.schedule_rounded,
                badgeColor: statusColor,
              ),
              _referenceDivider(p),
              _referenceInfoRow(
                p,
                label: isAr ? 'نوع الخدمة' : 'Service type',
                value: service.isEmpty
                    ? (isAr ? 'زيارة منزلية' : 'Home visit')
                    : service,
                icon: Icons.local_offer_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _referenceInfoRow(
    CarelinkPalette p, {
    required String label,
    required String value,
    required IconData icon,
    Color? badgeColor,
    bool ltrValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 19),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: badgeColor == null
                  ? Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: ltrValue ? TextDirection.ltr : null,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: p.inkDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _referenceDivider(CarelinkPalette p) => Divider(
    height: 1,
    thickness: 0.8,
    color: p.stroke.withValues(alpha: 0.75),
  );

  // ignore: unused_element
  Widget _buildAppointmentInfoCard(CarelinkPalette p) {
    final isAr = localeController.isArabic;
    final parsedNotes = _parseNotes(appointment!.notes);

    final serviceVal =
        parsedNotes['service'] ??
        (provider?.serviceType.isNotEmpty == true
            ? provider!.serviceType
            : appointment!.providerRole);

    // Visit Type is always Home Visit for patient bookings of home services
    final visitTypeVal = isAr ? 'زيارة منزلية' : 'Home Visit';

    final dateVal = _formatDateOnly(appointment!.scheduledAt);
    final timeVal = _formatTimeOnly(appointment!.scheduledAt);

    final addressRaw =
        parsedNotes['address'] ??
        (appointment!.visitAddress.isNotEmpty
            ? appointment!.visitAddress
            : appointment!.location);
    final displayAddress = _shortenAddress(addressRaw);

    final currentCaseVal = parsedNotes['currentcase'] ?? '';
    final reasonVal = parsedNotes['reason'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isAr ? 'معلومات الموعد' : 'Appointment Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: p.inkDark,
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.8),

          // Row 1: Date | Time
          Row(
            children: [
              Expanded(
                child: _buildGridCell(p, isAr ? 'التاريخ' : 'Date', dateVal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGridCell(p, isAr ? 'الوقت' : 'Time', timeVal),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 2: Service | Visit Type
          Row(
            children: [
              Expanded(
                child: _buildGridCell(
                  p,
                  isAr ? 'الخدمة' : 'Service',
                  serviceVal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGridCell(
                  p,
                  isAr ? 'نوع الزيارة' : 'Visit Type',
                  visitTypeVal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Full width: Address
          _buildFullWidthCell(p, isAr ? 'العنوان' : 'Address', displayAddress),

          // Current Case (hide if empty)
          if (currentCaseVal.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildFullWidthCell(
              p,
              isAr ? 'الحالة الحالية' : 'Current Case',
              currentCaseVal,
            ),
          ],

          // Reason (hide if empty)
          if (reasonVal.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildFullWidthCell(p, isAr ? 'سبب الزيارة' : 'Reason', reasonVal),
          ],

          // Symptoms
          if (appointment!.symptoms.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildFullWidthCell(
              p,
              isAr ? 'الأعراض' : 'Symptoms',
              appointment!.symptoms,
            ),
          ],

          // Additional notes (clean patient text)
          if (_cleanNotes(appointment!.notes).isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildFullWidthCell(
              p,
              isAr ? 'ملاحظات إضافية' : 'Additional Notes',
              _cleanNotes(appointment!.notes),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGridCell(CarelinkPalette p, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: p.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: p.inkDark,
          ),
        ),
      ],
    );
  }

  Widget _buildFullWidthCell(CarelinkPalette p, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: p.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, color: p.inkDark)),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildPaymentInfoCard(CarelinkPalette p) {
    final isAr = localeController.isArabic;
    final hint = _hintAmountFromOverview();
    final currency = (_paymentOverview?['currency'] ?? '').toString().trim();
    final cSymbol = currency.isNotEmpty
        ? ' $currency'
        : (isAr ? ' شيكل' : ' ILS');

    final amountLabel = hint != null && hint > 0
        ? '${hint.toStringAsFixed(2)}$cSymbol'
        : (isAr ? 'يحدد عند إتمام الدفع' : 'Amount set at checkout');

    final platformFeeValue =
        _paymentOverview?['adminAmount'] ?? _paymentOverview?['platformFee'];
    final platformFee = platformFeeValue != null
        ? double.tryParse(platformFeeValue.toString())
        : null;
    final platformFeeLabel = platformFee != null && platformFee > 0
        ? '${platformFee.toStringAsFixed(2)}$cSymbol'
        : '—';

    final refundAmount = _paymentOverview?['refundAmount'] != null
        ? double.tryParse(_paymentOverview!['refundAmount'].toString())
        : 0.0;
    final refundLabel = refundAmount != null && refundAmount > 0
        ? '${refundAmount.toStringAsFixed(2)}$cSymbol'
        : null;
    final providerShare = double.tryParse(
      (_paymentOverview?['providerAmount'] ?? '0').toString(),
    );
    final hasRetainedCancellationShares =
        (providerShare ?? 0) > 0 || (platformFee ?? 0) > 0;
    final hasRefundedPayment =
        (_paymentOverview?['paymentStatus'] ?? '')
            .toString()
            .toLowerCase()
            .trim() ==
        'refunded';
    final isExpiredRequest = const {
      'expired',
      'request_expired',
    }.contains(appointment!.status.toLowerCase().trim());
    final isMissedAppointment = const {
      'missed',
      'no_show',
    }.contains(appointment!.status.toLowerCase().trim());
    final refundPolicyText = isMissedAppointment
        ? (isAr
              ? 'لا يوجد استرداد تلقائي للموعد الفائت؛ يبقى الدفع قيد مراجعة الإدارة.'
              : 'No automatic refund applies to a missed appointment; payment remains held for admin review.')
        : hasRetainedCancellationShares
        ? (isAr
              ? 'تم احتساب الاسترداد وفق سياسة الإلغاء الخاصة بالمنصة.'
              : 'The refund was calculated according to the platform cancellation policy.')
        : hasRefundedPayment && isExpiredRequest
        ? (isAr
              ? 'سياسة الاسترجاع: استرداد كامل لانتهاء الطلب دون موافقة مقدم الخدمة.'
              : 'Refund Policy: Full refund because the request expired without provider approval.')
        : (isAr
              ? 'يتم احتساب أي استرداد وفق سياسة الإلغاء الخاصة بالمنصة.'
              : 'Any refund is calculated according to the platform cancellation policy.');

    final st = _ledgerPaymentStatus(appointment!);

    String displayStatus = st.isEmpty ? (isAr ? 'غير معروف' : 'Unknown') : st;
    Color statusColor = p.inkDark;
    if (displayStatus.toLowerCase() == 'paid') {
      displayStatus = isAr ? 'مدفوع' : 'Paid';
      statusColor = Colors.green;
    } else if (displayStatus.toLowerCase() == 'unpaid') {
      displayStatus = isAr ? 'غير مدفوع' : 'Unpaid';
      statusColor = Colors.redAccent;
    } else if (displayStatus.toLowerCase() == 'pending') {
      displayStatus = isAr ? 'قيد الانتظار' : 'Pending';
      statusColor = Colors.orange;
    } else if (displayStatus.toLowerCase() == 'refunded') {
      displayStatus = isAr ? 'مسترد' : 'Refunded';
      statusColor = Colors.blue;
    }

    final pm = (() {
      final pMethod = (_paymentOverview?['paymentMethod'] ?? '')
          .toString()
          .trim();
      if (pMethod.isNotEmpty) return pMethod;
      if (appointment!.paymentMethod.isEmpty) return '—';
      return appointment!.paymentMethod;
    })();

    String displayMethod = pm;
    if (pm.toLowerCase() == 'mock_card' || pm.toLowerCase() == 'card') {
      displayMethod = isAr ? 'بطاقة ائتمان' : 'Credit Card';
    } else if (pm.toLowerCase() == 'cash') {
      displayMethod = isAr ? 'نقداً' : 'Cash';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isAr ? 'تفاصيل الدفع' : 'Payment Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: p.inkDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: p.stroke),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(
                  p,
                  isAr ? 'المبلغ الإجمالي' : 'Total Amount',
                  amountLabel,
                  isHighlighted: true,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  p,
                  isAr ? 'رسوم المنصة' : 'Platform Fee',
                  platformFeeLabel,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  p,
                  isAr ? 'طريقة الدفع' : 'Method',
                  displayMethod,
                ),

                if (refundLabel != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    p,
                    isAr ? 'المبلغ المسترد' : 'Refund Amount',
                    refundLabel,
                    valueColor: Colors.blue,
                  ),
                ],
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: p.inkMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    refundPolicyText,
                    style: TextStyle(
                      fontSize: 12,
                      color: p.inkMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    CarelinkPalette p,
    String label,
    String value, {
    bool isHighlighted = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13.5, color: p.inkMuted)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color:
                  valueColor ?? (isHighlighted ? AppColors.primary : p.inkDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitRatingSection(CarelinkPalette p, AppointmentModel a) {
    if (a.status.toLowerCase() != 'completed') {
      return const SizedBox.shrink();
    }
    final isAr = localeController.isArabic;
    final existing = a.patientRatingStars;

    if (existing != null && existing >= 1) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.isDark ? 0.15 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr ? 'تقييمك للزيارة' : 'Your Rating',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: p.inkDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  i < existing ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 28,
                );
              }),
            ),
            if (a.patientRatingComment.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                a.patientRatingComment,
                style: TextStyle(fontSize: 13, color: p.inkMuted, height: 1.35),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'تقييم هذه الزيارة' : 'Rate this visit',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAr
                ? '1 = ضعيف، 5 = ممتاز. يساعدنا هذا في تحسين التوصيات الذكية.'
                : '1 = poor, 5 = excellent. This updates provider scores used in smart match.',
            style: TextStyle(fontSize: 12, color: p.inkMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final n = i + 1;
              final selected = _draftStars >= n;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: IconButton.filledTonal(
                  tooltip: '$n',
                  onPressed: _ratingBusy
                      ? null
                      : () => setState(() => _draftStars = n),
                  style: IconButton.styleFrom(
                    backgroundColor: selected
                        ? Colors.amber.withValues(alpha: 0.16)
                        : p.surfaceSoft,
                    foregroundColor: selected ? Colors.amber : p.inkMuted,
                    minimumSize: const Size(46, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                      side: BorderSide(
                        color: selected
                            ? Colors.amber.withValues(alpha: 0.45)
                            : p.stroke,
                      ),
                    ),
                  ),
                  icon: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: selected ? 1 : 0),
                    duration: const Duration(milliseconds: 210),
                    curve: Curves.easeOutBack,
                    builder: (context, t, child) =>
                        Transform.scale(scale: 1 + (0.16 * t), child: child),
                    child: Icon(
                      selected ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 28,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ratingComment,
            maxLines: 3,
            maxLength: 500,
            enabled: !_ratingBusy,
            style: TextStyle(color: p.inkDark, fontSize: 13),
            decoration: InputDecoration(
              hintText: isAr ? 'تعليق اختياري' : 'Optional comment',
              hintStyle: TextStyle(color: p.inkMuted, fontSize: 12),
              filled: true,
              fillColor: p.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: p.stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _ratingBusy
                  ? null
                  : () {
                      if (_draftStars < 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isAr
                                  ? 'يرجى اختيار تقييم بالنجوم من 1 إلى 5.'
                                  : 'Please choose a star rating from 1 to 5.',
                            ),
                          ),
                        );
                        return;
                      }
                      _submitVisitRating();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _ratingBusy
                  ? const SizedBox.shrink()
                  : const Icon(Icons.send_rounded, size: 18),
              label: _ratingBusy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isAr ? 'إرسال التقييم' : 'Submit rating',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomActions(CarelinkPalette p) {
    if (appointment == null) return const SizedBox.shrink();

    final isAr = localeController.isArabic;
    final actionState = AppointmentActionHelper.getActionState(
      status: appointment!.status,
      paymentStatus: appointment!.paymentStatus,
      requestedRescheduleAt: appointment!.requestedRescheduleAt,
    );

    if (actionState.type == AppointmentActionType.hidden && !_canCancel) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.stroke)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.22 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actionState.type != AppointmentActionType.hidden) ...[
              SizedBox(
                width: double.infinity,
                child: _buildActionStateButton(p, isAr, actionState),
              ),
              if (!actionState.isEnabled &&
                  actionState.helperTextEn != null) ...[
                const SizedBox(height: 6),
                Text(
                  isAr ? actionState.helperTextAr! : actionState.helperTextEn!,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],

            if (_canCancel &&
                actionState.type != AppointmentActionType.bookAgain) ...[
              if (actionState.type != AppointmentActionType.hidden)
                const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _buildCompactAction(
                  palette: p,
                  icon: Icons.close_rounded,
                  label: isAr ? 'إلغاء الحجز' : 'Cancel Booking',
                  color: const Color(0xFFD93636),
                  onTap: isCancelling ? null : _showCancelConfirmationDialog,
                  isLoading: isCancelling,
                  destructive: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionStateButton(
    CarelinkPalette p,
    bool isAr,
    AppointmentActionState state,
  ) {
    final label = AppointmentActionHelper.getLabel(state.type, isAr);
    final icon = AppointmentActionHelper.getIcon(state.type);

    VoidCallback? onTap;
    if (state.isEnabled) {
      if (state.type == AppointmentActionType.changeAppointment ||
          state.type == AppointmentActionType.requestReschedule) {
        onTap = _openRescheduleModal;
      } else if (state.type == AppointmentActionType.bookAgain) {
        onTap = _showRebookChoices;
      }
    }

    if (!state.isEnabled) {
      return OutlinedButton.icon(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          backgroundColor: p.isDark
              ? const Color(0xFF2D3748)
              : const Color(0xFFF1F5F9),
          disabledForegroundColor: p.inkMuted,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCompactAction({
    required CarelinkPalette palette,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool destructive = false,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: destructive
            ? color.withValues(alpha: palette.isDark ? 0.13 : 0.06)
            : palette.surfaceSoft,
        disabledForegroundColor: color.withValues(alpha: 0.55),
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        side: BorderSide(
          color: destructive
              ? color.withValues(alpha: 0.55)
              : color.withValues(alpha: 0.28),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, size: 19),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  Future<void> _showCancelConfirmationDialog() async {
    final isAr = localeController.isArabic;
    final shouldContinue = await _showPremiumCancellationModal<bool>(
      barrierDismissible: true,
      builder: (dialogContext) {
        return _cancellationDialog(
          icon: Icons.warning_amber_rounded,
          title: isAr ? 'إلغاء الحجز؟' : 'Cancel Booking?',
          subtitle: isAr
              ? 'هل أنت متأكد من أنك تريد إلغاء هذا الحجز؟'
              : 'Are you sure you want to cancel this booking?',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _cancellationInfoCard(isAr),
              const SizedBox(height: 12),
              _refundPreviewFallback(isAr),
            ],
          ),
          secondaryLabel: isAr ? 'الاحتفاظ بالحجز' : 'Keep Booking',
          primaryLabel: isAr ? 'متابعة' : 'Continue',
          onSecondary: () => Navigator.pop(dialogContext, false),
          onPrimary: () => Navigator.pop(dialogContext, true),
        );
      },
    );
    if (shouldContinue != true || !mounted) return;

    setState(() => isCancelling = true);
    Map<String, dynamic> summary;
    try {
      summary = await _api.getCancellationSummary(
        appointmentId: widget.appointmentId,
        patientUserId: widget.patientUserId,
      );
    } catch (e) {
      if (!mounted) return;
      final reason = _cancellationFailureReason(e, isAr);
      await _showPremiumCancellationModal<void>(
        barrierDismissible: false,
        builder: (dialogContext) => _cancellationStateDialog(
          icon: Icons.close_rounded,
          color: const Color(0xFFD93636),
          title: isAr ? 'تعذر تحميل ملخص الإلغاء' : 'Cancellation Failed',
          subtitle: reason,
          secondaryLabel: isAr ? 'إغلاق' : 'Close',
          onSecondary: () => Navigator.pop(dialogContext),
          buttonLabel: isAr ? 'إعادة المحاولة' : 'Retry',
          onPressed: () {
            Navigator.pop(dialogContext);
            _showCancelConfirmationDialog();
          },
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => isCancelling = false);
    }
    if (!mounted) return;

    final confirmed = await _showPremiumCancellationModal<bool>(
      barrierDismissible: false,
      builder: (dialogContext) => _cancellationDialog(
        icon: Icons.receipt_long_rounded,
        title: isAr ? 'ملخص الإلغاء' : 'Cancellation Summary',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow(
              isAr ? 'إجمالي المدفوع' : 'Total paid',
              _summaryMoney(summary, 'totalPaid'),
              Icons.payments_outlined,
            ),
            _summaryRow(
              isAr ? 'مبلغ الاسترداد' : 'Refund amount',
              _summaryMoney(summary, 'refundAmount'),
              Icons.account_balance_wallet_outlined,
            ),
            _summaryRow(
              isAr ? 'رسوم الإلغاء' : 'Cancellation fee',
              _summaryMoney(summary, 'cancellationFee'),
              Icons.money_off_csred_outlined,
            ),
            _summaryRow(
              isAr ? 'تعويض مقدم الرعاية' : 'Provider compensation',
              _summaryMoney(summary, 'providerCompensation'),
              Icons.medical_services_outlined,
            ),
            _summaryRow(
              isAr ? 'رسوم المنصة' : 'Platform fee',
              _summaryMoney(summary, 'platformFee'),
              Icons.account_balance_outlined,
            ),
            _summaryRow(
              isAr ? 'نسبة الاسترداد' : 'Refund percentage',
              summary['refundPercentage'] == null
                  ? '—'
                  : '${summary['refundPercentage']}%',
              Icons.percent_rounded,
            ),
            _summaryRow(
              isAr ? 'طريقة الاسترداد' : 'Refund method',
              isAr ? 'طريقة الدفع الأصلية' : 'Original payment method',
              Icons.credit_card_rounded,
            ),
            _summaryRow(
              isAr ? 'حالة الاسترداد' : 'Refund status',
              isAr ? 'طلب الاسترداد قيد المراجعة' : 'Pending admin review',
              Icons.hourglass_top_rounded,
            ),
            const SizedBox(height: 12),
            _summaryExplanation(
              (summary[isAr ? 'reasonAr' : 'reason'] ??
                      summary[isAr ? 'explanationAr' : 'explanation'] ??
                      '—')
                  .toString(),
            ),
            const SizedBox(height: 12),
            _refundProcessInfoBox(isAr),
          ],
        ),
        secondaryLabel: isAr ? 'رجوع' : 'Back',
        primaryLabel: isAr
            ? 'إرسال طلب الإلغاء'
            : 'Submit Cancellation Request',
        onSecondary: () => Navigator.pop(dialogContext, false),
        onPrimary: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await _cancel();
    } else if (confirmed == false) {
      await _showCancelConfirmationDialog();
    }
  }

  String _summaryMoney(Map<String, dynamic> summary, String key) {
    final raw = summary[key];
    if (raw == null) return '—';
    final amount = num.tryParse(raw.toString());
    final value = amount == null ? raw.toString() : amount.toStringAsFixed(2);
    final currency = (summary['currency'] ?? '').toString().trim();
    return currency.isEmpty ? value : '$value $currency';
  }

  String _cancellationFailureReason(Object error, bool isAr) {
    final raw = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|ApiServiceException):\s*'), '')
        .trim();
    if (raw.isNotEmpty) return raw;
    return isAr
        ? 'حدث خطأ ما. يرجى المحاولة مرة أخرى.'
        : 'Something went wrong. Please try again.';
  }

  Widget _summaryRow(String label, String value, IconData icon) {
    final p = CarelinkPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: p.inkMuted)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryExplanation(String text) {
    final p = CarelinkPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: TextStyle(color: p.inkMuted, height: 1.4)),
    );
  }

  Widget _refundProcessInfoBox(bool isAr) {
    final p = CarelinkPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'عملية الاسترداد' : 'Refund Process',
            style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            isAr
                ? 'بعد تأكيد الإلغاء، سيتم إرسال طلب الاسترداد إلى الإدارة للمراجعة. وبعد الموافقة، ستتم معالجة الاسترداد وفق سياسة الإلغاء.'
                : 'After confirming the cancellation, a refund request will be sent to the administrator for review. Once approved, the refund will be processed according to the cancellation policy.',
            style: TextStyle(color: p.inkMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _cancellationInfoCard(bool isAr) {
    final p = CarelinkPalette.of(context);
    final bullets = isAr
        ? const [
            'سيتم احتساب رسوم الإلغاء تلقائياً عند انطباقها.',
            'سيظهر مبلغ الاسترداد قبل التأكيد.',
            'لا يمكن التراجع عن هذا الإجراء.',
          ]
        : const [
            'Cancellation fees (if applicable) will be calculated automatically.',
            'Your refund amount will be shown before confirmation.',
            'This action cannot be undone.',
          ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke.withValues(alpha: .7)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < bullets.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6, color: Color(0xFFD93636)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    bullets[i],
                    style: TextStyle(color: p.inkMuted, height: 1.4),
                  ),
                ),
              ],
            ),
            if (i < bullets.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  Widget _refundPreviewFallback(bool isAr) {
    final p = CarelinkPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAr
                  ? 'سيتم احتساب مبلغ الاسترداد تلقائياً.'
                  : 'Refund amount will be calculated automatically.',
              style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<T?> _showPremiumCancellationModal<T>({
    required WidgetBuilder builder,
    required bool barrierDismissible,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: .35),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _cancellationStateDialog({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    List<(String, String)>? details,
    bool loading = false,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    String? buttonLabel,
    VoidCallback? onPressed,
  }) {
    final p = CarelinkPalette.of(context);
    final width = (MediaQuery.sizeOf(context).width * .88).clamp(0.0, 440.0);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.isDark ? .30 : .14),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: .7, end: 1),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutBack,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: loading
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: color,
                          ),
                        )
                      : Icon(icon, color: color, size: 38),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.inkMuted, height: 1.45),
                ),
              ],
              if (details != null && details.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (final detail in details)
                        _summaryRow(
                          detail.$1,
                          detail.$2,
                          Icons.check_circle_outline_rounded,
                        ),
                    ],
                  ),
                ),
              ],
              if (!loading && buttonLabel != null) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (secondaryLabel != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onSecondary,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(secondaryLabel),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: onPressed,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(buttonLabel, textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cancellationDialog({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget content,
    required String secondaryLabel,
    required String primaryLabel,
    required VoidCallback onSecondary,
    required VoidCallback onPrimary,
  }) {
    final p = CarelinkPalette.of(context);
    const danger = Color(0xFFD93636);
    final dialogWidth = (MediaQuery.sizeOf(context).width * .88).clamp(
      0.0,
      460.0,
    );
    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.isDark ? .28 : .12),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: danger.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: danger, size: 29),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DefaultTextStyle(
                style: TextStyle(color: p.inkMuted, fontSize: 14, height: 1.45),
                textAlign: TextAlign.center,
                child: content,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(secondaryLabel, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(primaryLabel, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateOnly(DateTime? date) {
    if (date == null) return context.tr('common.dateUnavailable');
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthsAr = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final isAr = localeController.isArabic;
    final monthName = isAr ? monthsAr[date.month - 1] : months[date.month - 1];
    return '${date.day} $monthName ${date.year}';
  }

  String _formatTimeOnly(DateTime? date) {
    if (date == null) return context.tr('common.timeUnavailable');
    final isAr = localeController.isArabic;
    final suffixEn = date.hour >= 12 ? 'PM' : 'AM';
    final suffixAr = date.hour >= 12 ? 'م' : 'ص';
    final suffix = isAr ? suffixAr : suffixEn;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $suffix';
  }

  Future<void> _submitVisitRating() async {
    if (_draftStars < 1) return;
    if (appointment == null) return;
    setState(() => _ratingBusy = true);
    try {
      await _api.rateCompletedVisit(
        appointmentId: widget.appointmentId,
        patientUserId: widget.patientUserId,
        stars: _draftStars,
        comment: _ratingComment.text.trim().isEmpty
            ? null
            : _ratingComment.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('patient.rating.thanks'))),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.userMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _ratingBusy = false);
    }
  }

  Widget _buildMapCard(CarelinkPalette p, AppointmentModel a) {
    final vLat = a.visitLatitude;
    final vLng = a.visitLongitude;
    final pLat = a.providerCurrentLat;
    final pLng = a.providerCurrentLng;

    LatLng? visitPoint;
    if (vLat != null && vLng != null) {
      visitPoint = LatLng(vLat, vLng);
    }
    LatLng? provPoint;
    if (pLat != null && pLng != null) {
      provPoint = LatLng(pLat, pLng);
    }

    final center = visitPoint ?? provPoint ?? const LatLng(0, 0);
    var zoom = 14.0;
    if (visitPoint != null && provPoint != null) {
      final dist = Geolocator.distanceBetween(
        visitPoint.latitude,
        visitPoint.longitude,
        provPoint.latitude,
        provPoint.longitude,
      );
      if (dist > 5000) {
        zoom = 11;
      } else if (dist > 1500) {
        zoom = 12;
      }
    }

    String? distLabel;
    if (visitPoint != null && provPoint != null) {
      final m = Geolocator.distanceBetween(
        visitPoint.latitude,
        visitPoint.longitude,
        provPoint.latitude,
        provPoint.longitude,
      );
      if (m >= 1000) {
        distLabel = 'About ${(m / 1000).toStringAsFixed(1)} km away';
      } else {
        distLabel = 'About ${m.round()} m away';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.stroke),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                'Live visit map',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.inkDark),
              ),
            ),
            if (pLat == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  'When the provider shares location, you will see them here (refreshes every few seconds).',
                  style: TextStyle(fontSize: 11, color: p.inkMuted),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Text(() {
                  final parts = <String>[
                    'Provider last update: ${_formatUpdated(a.providerLocationUpdatedAt)}',
                  ];
                  final d = distLabel;
                  if (d != null && d.isNotEmpty) parts.add(d);
                  return parts.join(' · ');
                }(), style: TextStyle(fontSize: 11, color: p.inkMuted)),
              ),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: center, initialZoom: zoom),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'carelink.app',
                  ),
                  MarkerLayer(
                    markers: [
                      if (visitPoint != null)
                        Marker(
                          point: visitPoint,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.home_rounded,
                            color: AppColors.primary,
                            size: 36,
                          ),
                        ),
                      if (provPoint != null)
                        Marker(
                          point: provPoint,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            color: Color(0xFF0D9488),
                            size: 36,
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
    );
  }
}

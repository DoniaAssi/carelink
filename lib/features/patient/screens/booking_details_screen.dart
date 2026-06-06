import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/payment_service.dart';
import 'package:carelink/features/patient/screens/provider_details_screen.dart';
import 'package:carelink/features/patient/screens/chat_screen.dart';
import 'package:carelink/shared/services/patient_recent_chats_service.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/features/patient/widgets/reschedule_modal.dart';
import 'package:carelink/features/patient/widgets/change_provider_modal.dart';

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
  bool _payBusy = false;

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
        final provData = await _api.getProviderById(apt.providerUserId);
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
      _setPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
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

  bool get _appointmentPaidLive {
    return _ledgerPaymentStatus(appointment!).toLowerCase() == 'paid';
  }

  bool get _canPayDemo {
    if (_payBusy || appointment == null || _isBookingCancelled) return false;
    if (_appointmentPaidLive) return false;
    final o = _paymentOverview;
    if (o != null && o['canPay'] == false) return false;
    return true;
  }

  bool get _isBookingCancelled {
    final s = appointment?.status.toLowerCase() ?? '';
    return s == 'cancelled' || s == 'canceled';
  }

  bool get _canCancel {
    final status = appointment?.status.toLowerCase();
    return status == 'pending' ||
        status == 'pending_payment' ||
        status == 'payment_pending' ||
        status == 'confirmed';
  }

  bool get _canReschedule {
    if (appointment == null) return false;
    final s = appointment!.status.toLowerCase().trim();
    return s == 'pending' ||
        s == 'pending_payment' ||
        s == 'payment_pending' ||
        s == 'request_sent' ||
        s == 'requested' ||
        s == 'waiting_provider_response' ||
        s == 'waiting response';
  }

  Future<void> _payNowDemo() async {
    final a = appointment;
    if (a == null || _payBusy) return;
    setState(() => _payBusy = true);
    try {
      final svc = PaymentService(api: _api);
      await svc.payForBooking(
        appointmentId: widget.appointmentId,
        patientUserId: widget.patientUserId,
        providerUserId: a.providerUserId,
        amountHint: _hintAmountFromOverview(),
        paymentMethod: 'mock_card',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful (DEMO — no real card charge).'),
        ),
      );
      await _load(silent: true);
      await _refreshPaymentOverview();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _payBusy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => isCancelling = true);
    try {
      await _api.cancelAppointment(
        appointmentId: widget.appointmentId,
        patientUserId: widget.patientUserId,
        reason: 'Cancelled from mobile app',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled successfully')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
          appointmentId: appointment!.appointmentId,
          providerUserId: appointment!.providerUserId,
          onSuccess: () {
            Navigator.pop(sheetCtx);
            _load();
          },
        );
      },
    );
  }

  void _openChangeProviderModal() {
    if (appointment == null) return;

    if (appointment!.scheduledAt != null) {
      final now = DateTime.now();
      final diff = appointment!.scheduledAt!.difference(now);
      if (diff.inHours < 2) {
        final isAr = localeController.isArabic;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAr
                  ? 'لا يمكن تغيير مقدم الرعاية قبل الموعد بوقت قصير.'
                  : 'Provider change is not available close to the appointment time.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return ChangeProviderModal(
          appointment: appointment!,
          patientUserId: widget.patientUserId,
          onSuccess: () {
            Navigator.pop(sheetCtx);
            _load();
          },
        );
      },
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
          child: Scaffold(
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
                                _buildStatusBannerSection(p),
                                const SizedBox(height: 12),

                                if (_showLiveMap)
                                  _buildMapCard(p, appointment!),

                                _buildNurseProviderCard(p),
                                const SizedBox(height: 12),

                                _buildAppointmentInfoCard(p),
                                const SizedBox(height: 12),

                                _buildPaymentInfoCard(p),
                                const SizedBox(height: 12),

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
    final status = appointment!.status.toLowerCase();
    final isAr = localeController.isArabic;

    Color bg;
    Color textCol;
    String title;
    String subtitle;

    if (status == 'pending_payment' || status == 'payment_pending') {
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
    } else if (status == 'pending' ||
        status == 'request_sent' ||
        status == 'requested' ||
        status == 'waiting') {
      bg = AppColors.primary.withValues(alpha: 0.12);
      textCol = AppColors.primary;
      title = isAr ? 'بانتظار رد مقدم الخدمة' : 'Waiting for provider response';
      subtitle = isAr
          ? 'سنخبرك عند قبول أو رفض الطلب'
          : 'The provider can accept or decline. We will notify you here.';
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
      title = status.toUpperCase();
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

  Widget _buildNurseProviderCard(CarelinkPalette p) {
    final overallRating = provider?.overallRating ?? 4.8;
    final experience = provider?.experienceYears ?? 3;
    final role = appointment!.providerRole.isNotEmpty
        ? appointment!.providerRole
        : 'Nurse';
    final isAr = localeController.isArabic;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
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
                    size: 32,
                    color: p.inkMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment!.providerName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
                const SizedBox(height: 6),
                Row(
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
                    const SizedBox(width: 12),
                    Icon(
                      Icons.work_history_rounded,
                      color: p.inkMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAr ? '$experience سنوات خبرة' : '$experience yrs exp',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.inkMuted,
                      ),
                    ),
                  ],
                ),
                if (provider != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
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
                    height: 50,
                    child: FilledButton.icon(
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
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.primary,
                        elevation: 0,
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

    // Extract additional details from _paymentOverview if available (or use defaults/placeholders for now)
    final platformFee = _paymentOverview?['platformFee'] != null
        ? double.tryParse(_paymentOverview!['platformFee'].toString())
        : (hint != null ? hint * 0.05 : 0.0); // Assuming 5% fee or from API
    final platformFeeLabel = platformFee != null && platformFee > 0
        ? '${platformFee.toStringAsFixed(2)}$cSymbol'
        : '—';

    final refundAmount = _paymentOverview?['refundAmount'] != null
        ? double.tryParse(_paymentOverview!['refundAmount'].toString())
        : 0.0;
    final refundLabel = refundAmount != null && refundAmount > 0
        ? '${refundAmount.toStringAsFixed(2)}$cSymbol'
        : null;

    final st = _ledgerPaymentStatus(appointment!);

    String displayStatus = st.isEmpty ? (isAr ? 'غير مدفوع' : 'Unpaid') : st;
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
                    isAr
                        ? 'سياسة الاسترجاع: يمكنك استرداد المبلغ كاملاً في حال الإلغاء قبل 24 ساعة من الموعد.'
                        : 'Refund Policy: Full refund available if cancelled 24 hours prior to appointment.',
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

          if (_canPayDemo) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _payNowDemo,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _payBusy
                      ? const SizedBox.shrink()
                      : const Icon(Icons.lock_outline_rounded, size: 19),
                  label: _payBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isAr ? 'ادفع الآن (تجريبي)' : 'Pay Now (Demo)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
          ],
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
                  icon: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 28,
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
    final isAr = localeController.isArabic;
    if (!_canReschedule && !_canCancel) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.stroke)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.22 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_canReschedule)
              Expanded(
                child: _buildCompactAction(
                  palette: p,
                  icon: Icons.edit_calendar_rounded,
                  label: isAr ? 'تعديل الموعد' : 'Reschedule',
                  color: AppColors.primary,
                  onTap: _openRescheduleModal,
                ),
              ),
            if (_canReschedule && _canCancel) const SizedBox(width: 8),
            if (_canCancel)
              Expanded(
                child: _buildCompactAction(
                  palette: p,
                  icon: Icons.sync_alt_rounded,
                  label: isAr ? 'تغيير المقدم' : 'Change',
                  color: const Color(0xFF167C83),
                  onTap: _openChangeProviderModal,
                ),
              ),
            if (_canCancel) const SizedBox(width: 8),
            if (_canCancel)
              Expanded(
                child: _buildCompactAction(
                  palette: p,
                  icon: Icons.close_rounded,
                  label: isAr ? 'إلغاء الحجز' : 'Cancel',
                  color: const Color(0xFFD93636),
                  onTap: isCancelling ? null : _showCancelConfirmationDialog,
                  isLoading: isCancelling,
                  destructive: true,
                ),
              ),
          ],
        ),
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
    final p = CarelinkPalette.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isAr ? 'إلغاء الحجز؟' : 'Cancel Booking?',
            style: TextStyle(
              color: p.inkDark,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            isAr
                ? 'هل أنت متأكد من أنك تريد إلغاء هذا الحجز؟ لا يمكن التراجع عن هذا الإجراء.'
                : 'Are you sure you want to cancel this booking? This action cannot be undone.',
            style: TextStyle(color: p.inkMuted, fontSize: 14),
          ),
          actions: <Widget>[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: p.stroke),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isAr ? 'الاحتفاظ بالحجز' : 'Keep Booking',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD93636),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(
                isAr ? 'نعم، إلغاء الحجز' : 'Yes, Cancel',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _cancel();
              },
            ),
          ],
        );
      },
    );
  }

  String _formatDateOnly(DateTime? date) {
    if (date == null) return 'Date unavailable';
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
    if (date == null) return 'Time unavailable';
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
        const SnackBar(
          content: Text(
            'Thanks! Your rating helps improve recommendations for everyone.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
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

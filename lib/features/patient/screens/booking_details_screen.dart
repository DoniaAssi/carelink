import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/payment/patient_visa_payment_copy.dart';
import 'package:carelink/features/patient/widgets/visa_demo_checkout_sheet.dart';
import 'package:carelink/shared/services/payment_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/features/patient/widgets/carelink_patient_app_bar.dart';

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

  static const String _dash = '\u2014';

  String _localizedPaymentStatus(BuildContext c, String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return _dash;
    switch (s) {
      case 'paid':
        return c.tr('patient.pay.paid');
      case 'pending':
        return c.tr('patient.pay.pending');
      case 'failed':
        return c.tr('patient.pay.failed');
      case 'declined':
        return c.tr('patient.pay.declined');
      default:
        return raw;
    }
  }

  String _localizedProviderRole(BuildContext c, String raw) {
    final s = raw.trim().toLowerCase();
    if (s.contains('doctor')) return c.tr('patient.role.doctor');
    if (s.contains('nurse')) return c.tr('patient.role.nurse');
    return raw.isEmpty ? _dash : raw;
  }

  String _localizedAppointmentStatus(BuildContext c, String raw) {
    final s = raw.trim().toLowerCase();
    switch (s) {
      case 'pending':
        return c.tr('patient.status.pending');
      case 'confirmed':
        return c.tr('patient.status.confirmed');
      case 'completed':
        return c.tr('patient.status.completed');
      case 'cancelled':
      case 'canceled':
        return c.tr('patient.status.cancelled');
      default:
        return raw.isEmpty ? _dash : raw;
    }
  }

  String _formatWhen(BuildContext c, DateTime? date) {
    if (date == null) return c.tr('patient.dateUnavailable');
    final loc = localeController.locale.toLanguageTag();
    try {
      return DateFormat.yMMMd(loc).add_jm().format(date.toLocal());
    } catch (_) {
      return DateFormat.yMMMd('en').add_jm().format(date.toLocal());
    }
  }

  String _relativeWhen(BuildContext c, DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.isNegative || diff.inSeconds < 60) {
      return c.tr('notifications.relative.justNow');
    }
    if (diff.inMinutes < 60) {
      final n = diff.inMinutes;
      return n <= 1
          ? c.tr('notifications.relative.oneMinute')
          : c.tr('notifications.relative.minutes', args: {'n': '$n'});
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return h <= 1
          ? c.tr('notifications.relative.oneHour')
          : c.tr('notifications.relative.hours', args: {'n': '$h'});
    }
    return '${t.day}/${t.month}/${t.year}';
  }

  void _setPolling() {
    _pollTimer?.cancel();
    final s = appointment?.status.toLowerCase() ?? '';
    if (s == 'confirmed') {
      _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
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
      if (!mounted) return;
      setState(() {
        appointment = AppointmentModel.fromJson(data);
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
    final fromApi =
        (_paymentOverview?['paymentStatus'] ?? '').toString().trim();
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

  Future<void> _payNowDemo() async {
    final a = appointment;
    if (a == null || _payBusy) return;
    final hint = _hintAmountFromOverview();
    if (hint == null || hint <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('patient.pay.amountUnavailable'))),
      );
      return;
    }
    var currency = (_paymentOverview?['currency'] ?? '').toString().trim();
    if (currency.isEmpty) currency = 'JOD';

    final serviceLabel = [
      if (a.symptoms.trim().isNotEmpty) a.symptoms.trim(),
      if (a.notes.trim().isNotEmpty) a.notes.trim(),
    ].join(' · ');
    final serviceName = serviceLabel.isEmpty
        ? context.tr('patient.pay.careVisit')
        : serviceLabel;

    setState(() => _payBusy = true);
    try {
      final out = await showVisaDemoCheckoutSheet(
        context: context,
        appointmentId: widget.appointmentId,
        patientUserId: widget.patientUserId,
        providerUserId: a.providerUserId,
        amount: hint,
        currencyCode: currency,
        providerName:
            a.providerName.trim().isNotEmpty
                ? a.providerName
                : context.tr('patient.providerFallback'),
        serviceName: serviceName,
        paymentService: PaymentService(api: _api),
      );
      if (!mounted) return;
      if (out != null &&
          (out['paymentStatus'] ?? '').toString().toLowerCase() == 'paid') {
        final four = (out['cardLast4'] ?? '').toString().trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(PatientVisaPaymentCopy.paidLine(context, four)),
          ),
        );
      }
      await _load(silent: true);
      await _refreshPaymentOverview();
    } finally {
      if (mounted) setState(() => _payBusy = false);
    }
  }

  Widget _buildPaymentLedgerCard(CarelinkPalette p, AppointmentModel a) {
    final hint = _hintAmountFromOverview();
    final currency = (_paymentOverview?['currency'] ?? '').toString().trim();
    final amountLabel = hint != null && hint > 0
        ? '${hint.toStringAsFixed(2)}${currency.isNotEmpty ? ' $currency' : ''}'
        : context.tr(
            'patient.pay.amountAtCheckout',
            args: {
              'currency': currency.isNotEmpty ? currency : _dash,
            },
          );
    final stRaw = _ledgerPaymentStatus(a);
    final stUi = _localizedPaymentStatus(context, stRaw);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('patient.title.payment'),
              style: TextStyle(fontWeight: FontWeight.w700, color: p.inkDark),
            ),
            const SizedBox(height: 6),
            Text(
              amountLabel,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'patient.pay.statusLine',
                args: {'status': stUi},
              ),
              style: TextStyle(fontSize: 13, color: p.inkMuted),
            ),
            const SizedBox(height: 10),
            if (_appointmentPaidLive)
              Text(
                PatientVisaPaymentCopy.paidLine(
                  context,
                  (_paymentOverview?['cardLast4'] ?? '').toString(),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: p.inkDark,
                  height: 1.35,
                ),
              )
            else
              Text(
                PatientVisaPaymentCopy.unpaidPayWithVisa(context),
                style: TextStyle(fontSize: 13, color: p.inkMuted, height: 1.35),
              ),
            const SizedBox(height: 10),
            Text(
              context.tr('payment.demoLedgerNote'),
              style: TextStyle(fontSize: 11.5, color: p.inkMuted, height: 1.35),
            ),
            if (_canPayDemo) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _payNowDemo,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _payBusy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          context.tr('payment.payWithVisa'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _canCancel {
    final status = appointment?.status.toLowerCase();
    return status == 'pending' || status == 'confirmed';
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

  Future<void> _cancel() async {
    final cancelReason = context.tr('patient.booking.cancelReasonApp');
    setState(() => isCancelling = true);
    try {
      await _api.cancelAppointment(
        appointmentId: widget.appointmentId,
        patientUserId: widget.patientUserId,
        reason: cancelReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('patient.booking.cancelSuccess'))),
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

  Widget _buildVisitRatingSection(CarelinkPalette p, AppointmentModel a) {
    if (a.status.toLowerCase() != 'completed') {
      return const SizedBox.shrink();
    }
    final existing = a.patientRatingStars;
    if (existing != null && existing >= 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('patient.visitRating.title'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: p.inkDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < existing
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 28,
                  );
                }),
              ),
              if (a.patientRatingComment.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  a.patientRatingComment,
                  style: TextStyle(
                    fontSize: 13,
                    color: p.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('patient.visitRating.ratePrompt'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: p.inkDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('patient.visitRating.scaleExplain'),
              style: TextStyle(fontSize: 12, color: p.inkMuted),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final n = i + 1;
                final selected = _draftStars >= n;
                return IconButton(
                  onPressed: _ratingBusy
                      ? null
                      : () => setState(() => _draftStars = n),
                  icon: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    color: selected
                        ? const Color(0xFFF59E0B)
                        : p.inkMuted,
                    size: 36,
                  ),
                );
              }),
            ),
            TextField(
              controller: _ratingComment,
              maxLines: 3,
              maxLength: 500,
              enabled: !_ratingBusy,
              style: TextStyle(color: p.inkDark, fontSize: 13),
              decoration: InputDecoration(
                hintText: context.tr('patient.visitRating.optionalComment'),
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _ratingBusy
                    ? null
                    : () {
                        if (_draftStars < 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.tr('patient.visitRating.pickStars'),
                              ),
                            ),
                          );
                          return;
                        }
                        _submitVisitRating();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _ratingBusy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        context.tr('patient.visitRating.submitBtn'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
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
        SnackBar(content: Text(context.tr('patient.visitRating.thanks'))),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ratingBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: carelinkPatientAppBar(
        context,
        title: CarelinkAppBarTitle.forPatient(
          context,
          context.tr('patient.title.bookingDetails'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : appointment == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (appointment!.status.toLowerCase() == 'confirmed') ...[
                    _statusBanner(
                      p,
                      context.tr('patient.booking.banner.acceptTitle'),
                      context.tr('patient.booking.banner.acceptSub'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (appointment!.status.toLowerCase() == 'pending') ...[
                    _statusBanner(
                      p,
                      context.tr('patient.booking.banner.pendingTitle'),
                      context.tr('patient.booking.banner.pendingSub'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (appointment!.status.toLowerCase() == 'completed') ...[
                    _statusBanner(
                      p,
                      context.tr('patient.booking.banner.completedTitle'),
                      context.tr('patient.booking.banner.completedSub'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_showLiveMap)
                            _buildMapCard(context, p, appointment!),
                          _detailCard(
                            context,
                            context.tr('patient.detail.provider'),
                            appointment!.providerName,
                          ),
                          _detailCard(
                            context,
                            context.tr('patient.detail.role'),
                            _localizedProviderRole(
                              context,
                              appointment!.providerRole,
                            ),
                          ),
                          _detailCard(
                            context,
                            context.tr('patient.detail.specialization'),
                            appointment!.specialization,
                          ),
                          _detailCard(
                            context,
                            context.tr('patient.detail.dateTime'),
                            _formatWhen(context, appointment!.scheduledAt),
                          ),
                          _detailCard(
                            context,
                            context.tr('patient.detail.status'),
                            _localizedAppointmentStatus(
                              context,
                              appointment!.status,
                            ),
                          ),
                          _detailCard(
                            context,
                            context.tr('patient.detail.notes'),
                            appointment!.notes.isEmpty
                                ? _dash
                                : appointment!.notes,
                          ),
                          _detailCard(
                            context,
                            context.tr('patient.detail.location'),
                            appointment!.location.isEmpty
                                ? _dash
                                : appointment!.location,
                          ),
                          _detailCard(
                            context,
                            context.tr('patient.detail.visitAddress'),
                            appointment!.visitAddress.isEmpty
                                ? _dash
                                : appointment!.visitAddress,
                          ),
                          _detailCard(
                            context,
                            context.tr('patient.detail.locationNote'),
                            appointment!.locationNote.isEmpty
                                ? _dash
                                : appointment!.locationNote,
                          ),
                          _detailCard(
                            context,
                            context.tr('patient.detail.symptoms'),
                            appointment!.symptoms.isEmpty
                                ? _dash
                                : appointment!.symptoms,
                          ),
                          _detailCard(
                            context,
                            context.tr('patient.detail.urgency'),
                            appointment!.isUrgent
                                ? context.tr('patient.detail.urgencyUrgent')
                                : context.tr('patient.detail.urgencyNormal'),
                          ),
                          _buildPaymentLedgerCard(p, appointment!),
                          _buildVisitRatingSection(p, appointment!),
                        ],
                      ),
                    ),
                  ),
                  if (_canCancel)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isCancelling ? null : _cancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isCancelling
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                context.tr('patient.booking.cancelCta'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _statusBanner(
    CarelinkPalette p,
    String title,
    String subtitle,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: p.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(BuildContext context, CarelinkPalette p, AppointmentModel a) {
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
        distLabel = context.tr(
          'patient.map.aboutKmAway',
          args: {'km': (m / 1000).toStringAsFixed(1)},
        );
      } else {
        distLabel = context.tr(
          'patient.map.aboutMAway',
          args: {'m': '${m.round()}'},
        );
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
                context.tr('patient.map.liveVisitTitle'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: p.inkDark,
                ),
              ),
            ),
            if (pLat == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  context.tr('patient.map.whenProviderShares'),
                  style: TextStyle(fontSize: 11, color: p.inkMuted),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Text(
                  () {
                    final parts = <String>[
                      context.tr(
                        'patient.map.providerLastUpdate',
                        args: {
                          'relative': _relativeWhen(
                            context,
                            a.providerLocationUpdatedAt,
                          ),
                        },
                      ),
                    ];
                    final d = distLabel;
                    if (d != null && d.isNotEmpty) parts.add(d);
                    return parts.join(' · ');
                  }(),
                  style: TextStyle(fontSize: 11, color: p.inkMuted),
                ),
              ),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: zoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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

  Widget _detailCard(
    BuildContext context,
    String title,
    String value,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: AppColors.textLight, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

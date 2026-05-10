import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/payment_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

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
          content: Text(
            'Payment successful (DEMO — no real card charge).',
          ),
        ),
      );
      await _load(silent: true);
      await _refreshPaymentOverview();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _payBusy = false);
    }
  }

  Widget _buildPaymentLedgerCard(CarelinkPalette p, AppointmentModel a) {
    final hint = _hintAmountFromOverview();
    final currency = (_paymentOverview?['currency'] ?? '').toString().trim();
    final amountLabel = hint != null && hint > 0
        ? '${hint.toStringAsFixed(2)}${currency.isNotEmpty ? ' $currency' : ''}'
        : 'Amount set at checkout (${currency.isNotEmpty ? currency : '—'})';
    final st = _ledgerPaymentStatus(a);

    final methodShown = (() {
      final pm = (_paymentOverview?['paymentMethod'] ?? '').toString().trim();
      if (pm.isNotEmpty) return pm;
      if (a.paymentMethod.isEmpty) return '—';
      return a.paymentMethod;
    })();

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
              'Payment',
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
            const SizedBox(height: 6),
            Text(
              'Status: ${st.isEmpty ? '—' : st}',
              style: TextStyle(fontSize: 13, color: p.inkMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Method: $methodShown',
              style: TextStyle(fontSize: 13, color: p.inkMuted),
            ),
            const SizedBox(height: 10),
            Text(
              'DEMO checkout: tapping Pay uses mock_card via the CareLink ledger — no gateway keys in the app.',
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
                      : const Text(
                          'Pay now (DEMO)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
            if (_appointmentPaidLive) ...[
              const SizedBox(height: 10),
              Text(
                'This visit is marked paid.',
                style: TextStyle(fontSize: 13, color: p.inkDark),
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date unavailable';
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $hour:$minute $suffix';
  }

  String _formatUpdated(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours} hr ago';
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
                'Your rating',
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
              'Rate this visit',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: p.inkDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '1 = poor, 5 = excellent. This updates provider scores used in smart match.',
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
                hintText: 'Optional comment',
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
                            const SnackBar(
                              content: Text(
                                'Please choose a star rating from 1 to 5.',
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
                    : const Text(
                        'Submit rating',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
      appBar: AppBar(
        centerTitle: true,
        title: const CarelinkAppBarTitle('Booking details'),
        actions: carelinkAppBarActions(),
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
                      'Accepted — visit on your schedule',
                      'You can follow the care provider on the map when they share live location.',
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (appointment!.status.toLowerCase() == 'pending') ...[
                    _statusBanner(
                      p,
                      'Pending provider response',
                      'The provider can accept or decline. We will notify you here.',
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (appointment!.status.toLowerCase() == 'completed') ...[
                    _statusBanner(
                      p,
                      'Visit completed',
                      'Rate your provider after the service — it helps future smart matches for you and others.',
                    ),
                    const SizedBox(height: 10),
                  ],
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_showLiveMap) _buildMapCard(p, appointment!),
                          _detailCard('Provider', appointment!.providerName),
                          _detailCard('Role', appointment!.providerRole),
                          _detailCard(
                            'Specialization',
                            appointment!.specialization,
                          ),
                          _detailCard(
                            'Date & time',
                            _formatDate(appointment!.scheduledAt),
                          ),
                          _detailCard('Status', appointment!.status),
                          _detailCard(
                            'Notes',
                            appointment!.notes.isEmpty
                                ? '—'
                                : appointment!.notes,
                          ),
                          _detailCard(
                            'Location',
                            appointment!.location.isEmpty
                                ? '—'
                                : appointment!.location,
                          ),
                          _detailCard(
                            'Visit address',
                            appointment!.visitAddress.isEmpty
                                ? '—'
                                : appointment!.visitAddress,
                          ),
                          _detailCard(
                            'Location note',
                            appointment!.locationNote.isEmpty
                                ? '—'
                                : appointment!.locationNote,
                          ),
                          _detailCard(
                            'Symptoms',
                            appointment!.symptoms.isEmpty
                                ? '—'
                                : appointment!.symptoms,
                          ),
                          _detailCard(
                            'Urgency',
                            appointment!.isUrgent ? 'Urgent' : 'Normal',
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
                            : const Text(
                                'Cancel booking',
                                style: TextStyle(
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
                  'When the provider shares location, you will see them here (refreshes every few seconds).',
                  style: TextStyle(fontSize: 11, color: p.inkMuted),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Text(
                  () {
                    final parts = <String>[
                      'Provider last update: ${_formatUpdated(a.providerLocationUpdatedAt)}',
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

  Widget _detailCard(String title, String value) {
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

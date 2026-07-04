import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/service_request.dart';

import 'nurse_ui.dart';

enum _NurseTrackingStage { onTheWay, arrived }

class NurseVisitTrackingScreen extends StatefulWidget {
  const NurseVisitTrackingScreen({
    super.key,
    required this.request,
    required this.onStartVisit,
  });

  final ServiceRequest request;
  final Future<bool> Function(DateTime startTime) onStartVisit;

  @override
  State<NurseVisitTrackingScreen> createState() =>
      _NurseVisitTrackingScreenState();
}

class _NurseVisitTrackingScreenState extends State<NurseVisitTrackingScreen> {
  static const _primary = Color(0xFF0F8B8D);
  static const _text = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const double _arrivalThresholdMeters = 30;

  _NurseTrackingStage _stage = _NurseTrackingStage.onTheWay;
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _arrivalTime;
  double? _distanceMeters;
  bool _arrivalVerified = false;
  bool _isRestoring = true;
  bool _isLocating = false;
  bool _isStartingVisit = false;
  String? _locationError;

  String get _storageKey => 'nurse_visit_tracking_${widget.request.id}';
  double? get _patientLatitude => _validLatitude(widget.request.gpsLat);
  double? get _patientLongitude => _validLongitude(widget.request.gpsLng);
  String get _patientAddress {
    for (final value in [
      widget.request.location,
      widget.request.patientAddress,
      widget.request.locationNote,
    ]) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return 'Address not available';
  }

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[nurse visit tracking] requestId=${widget.request.id} '
      'visitLatitude=${widget.request.gpsLat} '
      'visitLongitude=${widget.request.gpsLng} '
      'visitAddress=$_patientAddress',
    );
    _restoreState();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  double? _validLatitude(double? value) =>
      value != null && value >= -90 && value <= 90 ? value : null;

  double? _validLongitude(double? value) =>
      value != null && value >= -180 && value <= 180 ? value : null;

  Future<void> _restoreState() async {
    final preferences = await SharedPreferences.getInstance();
    final savedStage = preferences.getInt('${_storageKey}_stage');
    final verified =
        preferences.getBool('${_storageKey}_arrival_verified') ?? false;
    final arrivalValue = preferences.getString('${_storageKey}_arrival_time');
    final restoredStage =
        savedStage == _NurseTrackingStage.arrived.index && verified
        ? _NurseTrackingStage.arrived
        : _NurseTrackingStage.onTheWay;

    if (!mounted) return;
    setState(() {
      _stage = restoredStage;
      _arrivalVerified = verified;
      _arrivalTime = arrivalValue == null
          ? null
          : DateTime.tryParse(arrivalValue)?.toLocal();
      _isRestoring = false;
    });
    unawaited(_startLocationTracking());
  }

  Future<void> _persistState() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('${_storageKey}_stage', _stage.index);
    await preferences.setBool(
      '${_storageKey}_arrival_verified',
      _arrivalVerified,
    );
    if (_arrivalTime != null) {
      await preferences.setString(
        '${_storageKey}_arrival_time',
        _arrivalTime!.toUtc().toIso8601String(),
      );
    }
  }

  Future<void> _clearState() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove('${_storageKey}_stage'),
      preferences.remove('${_storageKey}_arrival_verified'),
      preferences.remove('${_storageKey}_arrival_time'),
    ]);
  }

  Future<void> _startLocationTracking() async {
    if (_isLocating || _isStartingVisit) return;
    final patientLatitude = _patientLatitude;
    final patientLongitude = _patientLongitude;
    if (patientLatitude == null || patientLongitude == null) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Patient location coordinates are unavailable.';
        _isLocating = false;
      });
      return;
    }

    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _NurseLocationException(
          'Location services are disabled. Please enable GPS and try again.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _NurseLocationException(
          'Location permission is required to verify your arrival.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _NurseLocationException(
          'Location permission is permanently denied. Enable it in app settings.',
        );
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _handlePosition(current);

      await _positionSubscription?.cancel();
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: settings).listen(
            _handlePosition,
            onError: (Object error) {
              if (!mounted) return;
              setState(() {
                _locationError = 'Unable to update GPS location: $error';
              });
            },
          );
      if (!mounted) return;
      setState(() => _isLocating = false);
    } on _NurseLocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _locationError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _locationError = 'Unable to access GPS: $error';
      });
    }
  }

  void _handlePosition(Position position) {
    final latitude = _patientLatitude;
    final longitude = _patientLongitude;
    if (!mounted || latitude == null || longitude == null) return;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );
    final justArrived =
        _stage == _NurseTrackingStage.onTheWay &&
        distance <= _arrivalThresholdMeters;

    setState(() {
      _distanceMeters = distance;
      _locationError = null;
      if (justArrived) {
        _stage = _NurseTrackingStage.arrived;
        _arrivalVerified = true;
        _arrivalTime = DateTime.now();
      }
    });

    if (justArrived) {
      unawaited(_persistState());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arrival verified successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _startVisit() async {
    if (!_arrivalVerified ||
        _distanceMeters == null ||
        _distanceMeters! > _arrivalThresholdMeters) {
      _showArrivalRequired();
      return;
    }
    if (_isStartingVisit) return;

    setState(() => _isStartingVisit = true);
    final started = await widget.onStartVisit(DateTime.now());
    if (started) {
      await _clearState();
      await _positionSubscription?.cancel();
      _positionSubscription = null;
    }
    if (!mounted) return;
    setState(() => _isStartingVisit = false);
  }

  void _showArrivalRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "You must be at the patient's location to start the visit.",
        ),
      ),
    );
  }

  String get _distanceText {
    final distance = _distanceMeters;
    if (distance == null) return 'Locating...';
    if (distance < 1000) return '${distance.round()} m';
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '--:--';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatAppointment(DateTime value) {
    const months = [
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
    return '${months[value.month - 1]} ${value.day}, ${value.year} - '
        '${_formatTime(value)}';
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: const Text('Visit Tracking'),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: _isRestoring
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      children: [
                        _progressIndicator(),
                        const SizedBox(height: 18),
                        _patientCard(),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _stage == _NurseTrackingStage.onTheWay
                              ? _onTheWayContent()
                              : _arrivedContent(),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _progressIndicator() {
    final activeIndex = _stage == _NurseTrackingStage.onTheWay ? 0 : 1;
    const labels = ['On The Way', 'Arrived', 'In Progress'];
    const icons = [
      Icons.directions_car,
      Icons.location_on,
      Icons.medical_services_outlined,
    ];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= activeIndex;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: active ? _primary : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? _primary : NurseUi.border,
                        ),
                      ),
                      child: Icon(
                        icons[index],
                        size: 21,
                        color: active ? Colors.white : _muted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    FittedBox(
                      child: Text(
                        labels[index],
                        style: TextStyle(
                          color: active ? _primary : _muted,
                          fontSize: 12,
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (index < labels.length - 1)
                Container(
                  width: 24,
                  height: 1.5,
                  margin: const EdgeInsets.only(bottom: 25),
                  color: index < activeIndex ? _primary : NurseUi.border,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _patientCard() {
    final name = widget.request.patientName.trim().isEmpty
        ? 'Patient'
        : widget.request.patientName.trim();
    return _card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: const Color(0xFFDDF2EF),
            child: Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: _primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.request.serviceType,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.request.patientPhone.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 15,
                        color: _primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.request.patientPhone,
                        style: const TextStyle(color: _primary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _onTheWayContent() {
    return Column(
      key: const ValueKey('nurse-on-the-way'),
      children: [
        _statusBanner(
          Icons.directions_car,
          'On The Way',
          'You are on your way to the patient',
        ),
        const SizedBox(height: 14),
        _card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const SizedBox(
                height: 220,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: CustomPaint(painter: _NurseRouteMapPainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _detailRow(
                      Icons.event_outlined,
                      'Appointment',
                      _formatAppointment(widget.request.scheduledDate),
                    ),
                    const Divider(height: 22),
                    _detailRow(
                      Icons.location_on_outlined,
                      'Patient Location',
                      _patientAddress,
                    ),
                    const Divider(height: 22),
                    _detailRow(Icons.route_outlined, 'Distance', _distanceText),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_locationError != null) ...[
          const SizedBox(height: 14),
          _errorMessage(_locationError!),
        ],
        const SizedBox(height: 14),
        _infoMessage(
          Icons.shield_outlined,
          'Please travel safely and follow traffic rules.',
        ),
        const SizedBox(height: 18),
        _primaryButton(
          icon: Icons.navigation_outlined,
          label: 'Start Navigation',
          loading: _isLocating,
          onPressed: _startLocationTracking,
        ),
      ],
    );
  }

  Widget _arrivedContent() {
    final canStart =
        _arrivalVerified &&
        _distanceMeters != null &&
        _distanceMeters! <= _arrivalThresholdMeters;
    return Column(
      key: const ValueKey('nurse-arrived'),
      children: [
        _statusBanner(
          Icons.check_circle,
          'Arrived Successfully',
          'You have reached the patient location',
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            children: [
              Container(
                width: 142,
                height: 142,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF2EE),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFB8E0D8), width: 2),
                ),
                child: const Icon(Icons.location_on, size: 55, color: _primary),
              ),
              const SizedBox(height: 18),
              _detailRow(
                Icons.schedule_outlined,
                'Arrival Time',
                _formatTime(_arrivalTime),
              ),
              const Divider(height: 24),
              _detailRow(Icons.my_location_outlined, 'Distance', _distanceText),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _infoMessage(
          Icons.verified_user_outlined,
          'Arrival verified successfully.',
          success: true,
        ),
        const SizedBox(height: 18),
        _primaryButton(
          icon: Icons.play_arrow_rounded,
          label: 'Start Visit',
          loading: _isStartingVisit,
          onPressed: canStart ? _startVisit : _showArrivalRequired,
        ),
      ],
    );
  }

  Widget _statusBanner(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF3EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC5E8E0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: Colors.white,
            child: Icon(icon, color: _primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _primary, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Text(label, style: const TextStyle(color: _muted)),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _infoMessage(IconData icon, String text, {bool success = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFE4F5E9) : const Color(0xFFEAF6F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: success ? AppColors.success : _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: _text)),
          ),
          if (success)
            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
        ],
      ),
    );
  }

  Widget _errorMessage(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC7C7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_outlined, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFF8A1C1C))),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NurseUi.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F23352F),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NurseRouteMapPainter extends CustomPainter {
  const _NurseRouteMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9F0EC),
    );
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final thinRoad = Paint()
      ..color = const Color(0xFFF9FBFA)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * .28),
      Offset(size.width, size.height * .5),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .22, 0),
      Offset(size.width * .42, size.height),
      road,
    );
    canvas.drawLine(
      Offset(0, size.height * .78),
      Offset(size.width, size.height * .68),
      thinRoad,
    );

    final route = Path()
      ..moveTo(size.width * .17, size.height * .73)
      ..cubicTo(
        size.width * .32,
        size.height * .62,
        size.width * .40,
        size.height * .36,
        size.width * .53,
        size.height * .48,
      )
      ..cubicTo(
        size.width * .64,
        size.height * .57,
        size.width * .70,
        size.height * .24,
        size.width * .82,
        size.height * .28,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFF0F8B8D)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final nurse = Offset(size.width * .17, size.height * .73);
    final patient = Offset(size.width * .82, size.height * .28);
    canvas.drawCircle(nurse, 13, Paint()..color = Colors.white);
    canvas.drawCircle(nurse, 8, Paint()..color = const Color(0xFF2677E8));
    canvas.drawCircle(patient, 18, Paint()..color = Colors.white);
    canvas.drawCircle(patient, 14, Paint()..color = const Color(0xFF0F8B8D));
    final marker = TextPainter(
      text: const TextSpan(
        text: 'P',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    marker.paint(canvas, patient - Offset(marker.width / 2, marker.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NurseLocationException implements Exception {
  const _NurseLocationException(this.message);

  final String message;
}

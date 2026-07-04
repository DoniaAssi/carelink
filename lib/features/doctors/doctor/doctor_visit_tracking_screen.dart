import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../core/profile_avatar.dart';
import 'doctor_ui_constants.dart';

enum _VisitTrackingStage { onTheWay, arrived, inProgress }

class DoctorVisitTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final Future<bool> Function() onCompleteVisit;

  const DoctorVisitTrackingScreen({
    super.key,
    required this.requestData,
    required this.onCompleteVisit,
  });

  @override
  State<DoctorVisitTrackingScreen> createState() =>
      _DoctorVisitTrackingScreenState();
}

class _DoctorVisitTrackingScreenState extends State<DoctorVisitTrackingScreen> {
  _VisitTrackingStage _stage = _VisitTrackingStage.onTheWay;
  DateTime? _arrivalTime;
  DateTime? _visitStartTime;
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  Duration _elapsed = Duration.zero;
  bool _isCompleting = false;
  bool _isRestoring = true;
  bool _isLocating = false;
  bool _arrivalVerified = false;
  double? _distanceMeters;
  String? _locationError;

  static const _teal = Color(0xFF0F8B8D);
  static const _text = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const double _arrivalThresholdMeters = 30;

  String get _trackingStorageKey {
    final requestId = _textFor([
      'requestId',
      'serviceRequestId',
      'id',
    ], fallback: '');
    if (requestId.isNotEmpty) return 'doctor_visit_tracking_$requestId';

    final patientId = _textFor([
      'patientUserId',
      'patientId',
    ], fallback: 'unknown_patient');
    final scheduled =
        _valueFor([
          'scheduledAt',
          'appointmentDateTime',
          'dateTime',
          'appointmentDate',
        ])?.toString() ??
        'unknown_visit';
    return 'doctor_visit_tracking_${patientId}_$scheduled';
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[doctor visit tracking] requestData=${widget.requestData}');
    debugPrint(
      '[doctor visit tracking] requestId='
      '${widget.requestData['requestId'] ?? widget.requestData['serviceRequestId']} '
      'visitLatitude=${widget.requestData['visitLatitude']} '
      '(${widget.requestData['visitLatitude']?.runtimeType}) '
      'visitLongitude=${widget.requestData['visitLongitude']} '
      '(${widget.requestData['visitLongitude']?.runtimeType}) '
      'visitAddress=${widget.requestData['visitAddress']}',
    );
    _restoreTrackingState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restoreTrackingState() async {
    final preferences = await SharedPreferences.getInstance();
    final key = _trackingStorageKey;
    final savedStage = preferences.getInt('${key}_stage');
    final arrivalValue = preferences.getString('${key}_arrival_time');
    final startValue = preferences.getString('${key}_start_time');
    final savedArrivalVerified =
        preferences.getBool('${key}_arrival_verified') ?? false;

    var restoredStage =
        savedStage != null &&
            savedStage >= 0 &&
            savedStage < _VisitTrackingStage.values.length
        ? _VisitTrackingStage.values[savedStage]
        : _VisitTrackingStage.onTheWay;
    var restoredArrival = arrivalValue == null
        ? null
        : DateTime.tryParse(arrivalValue)?.toLocal();
    var restoredStart = startValue == null
        ? null
        : DateTime.tryParse(startValue)?.toLocal();

    if (restoredStage != _VisitTrackingStage.onTheWay &&
        !savedArrivalVerified) {
      restoredStage = _VisitTrackingStage.onTheWay;
      restoredArrival = null;
      restoredStart = null;
    }

    if (!mounted) return;
    setState(() {
      _stage = restoredStage;
      _arrivalTime = restoredArrival;
      _visitStartTime = restoredStart;
      _arrivalVerified = savedArrivalVerified;
      if (restoredStage == _VisitTrackingStage.inProgress &&
          restoredStart != null) {
        _elapsed = DateTime.now().difference(restoredStart);
      }
      _isRestoring = false;
    });

    if (restoredStage == _VisitTrackingStage.inProgress &&
        restoredStart != null) {
      _startElapsedTimer();
    } else {
      unawaited(_startLocationTracking());
    }
  }

  Future<void> _persistTrackingState() async {
    final preferences = await SharedPreferences.getInstance();
    final key = _trackingStorageKey;
    await preferences.setInt('${key}_stage', _stage.index);
    await preferences.setBool('${key}_arrival_verified', _arrivalVerified);
    if (_arrivalTime != null) {
      await preferences.setString(
        '${key}_arrival_time',
        _arrivalTime!.toUtc().toIso8601String(),
      );
    }
    if (_visitStartTime != null) {
      await preferences.setString(
        '${key}_start_time',
        _visitStartTime!.toUtc().toIso8601String(),
      );
    }
  }

  Future<void> _clearTrackingState() async {
    final preferences = await SharedPreferences.getInstance();
    final key = _trackingStorageKey;
    await Future.wait([
      preferences.remove('${key}_stage'),
      preferences.remove('${key}_arrival_time'),
      preferences.remove('${key}_start_time'),
      preferences.remove('${key}_arrival_verified'),
    ]);
  }

  void _startElapsedTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _visitStartTime == null) return;
      setState(() => _elapsed = DateTime.now().difference(_visitStartTime!));
    });
  }

  dynamic _valueFor(List<String> keys) {
    for (final key in keys) {
      final value = widget.requestData[key];
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  String _textFor(List<String> keys, {String fallback = 'Not available'}) {
    return _valueFor(keys)?.toString().trim() ?? fallback;
  }

  DateTime? get _scheduledAt {
    final value = _valueFor([
      'scheduledAt',
      'appointmentDateTime',
      'dateTime',
      'appointmentDate',
    ]);
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String get _patientName =>
      _textFor(['patientName', 'fullName', 'patientFullName']);

  String get _patientPhone =>
      _textFor(['patientPhone', 'phoneNumber', 'phone']);

  String get _patientAddress => _textFor([
    'visitAddress',
    'addressText',
    'location',
    'address',
    'locationNote',
  ]);

  String get _serviceType => _textFor([
    'serviceType',
    'serviceName',
    'appointmentType',
    'type',
    'reasonForVisit',
  ]);

  String? get _profileImage => _valueFor([
    'patientProfileImage',
    'patientProfileImageUrl',
    'profileImageUrl',
    'patientImage',
    'profileImage',
  ])?.toString();

  double? _coordinateFor(String key) {
    final value = widget.requestData[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '');
  }

  double? get _patientLatitude {
    final value = _coordinateFor('visitLatitude');
    return value != null && value >= -90 && value <= 90 ? value : null;
  }

  double? get _patientLongitude {
    final value = _coordinateFor('visitLongitude');
    return value != null && value >= -180 && value <= 180 ? value : null;
  }

  String get _distanceText {
    final distance = _distanceMeters;
    if (distance == null) return 'Locating...';
    if (distance < 1000) return '${distance.round()} m';
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  Future<void> _startLocationTracking() async {
    if (_isLocating || _stage == _VisitTrackingStage.inProgress) return;

    final patientLatitude = _patientLatitude;
    final patientLongitude = _patientLongitude;
    debugPrint(
      '[doctor visit tracking] coordinates before distance calculation: '
      'latitude=$patientLatitude longitude=$patientLongitude '
      'address=${widget.requestData['visitAddress']}',
    );
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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const _VisitLocationException(
          'Location services are disabled. Please enable GPS and try again.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _VisitLocationException(
          'Location permission is required to verify your arrival.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _VisitLocationException(
          'Location permission is permanently denied. Enable it in app settings.',
        );
      }

      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _handlePosition(currentPosition);

      await _positionSubscription?.cancel();
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            _handlePosition,
            onError: (Object error) {
              if (!mounted) return;
              setState(
                () => _locationError = 'Unable to update GPS location: $error',
              );
            },
          );

      if (!mounted) return;
      setState(() => _isLocating = false);
    } on _VisitLocationException catch (error) {
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
    final patientLatitude = _patientLatitude;
    final patientLongitude = _patientLongitude;
    if (!mounted || patientLatitude == null || patientLongitude == null) return;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      patientLatitude,
      patientLongitude,
    );
    final justArrived =
        _stage == _VisitTrackingStage.onTheWay &&
        distance <= _arrivalThresholdMeters;

    setState(() {
      _distanceMeters = distance;
      _locationError = null;
      if (justArrived) {
        _arrivalVerified = true;
        _arrivalTime = DateTime.now();
        _stage = _VisitTrackingStage.arrived;
      }
    });

    if (justArrived) {
      unawaited(_persistTrackingState());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arrival verified successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showArrivalRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "You must be at the patient's location to start the visit.",
        ),
      ),
    );
  }

  void _startVisit() {
    if (!_arrivalVerified ||
        _distanceMeters == null ||
        _distanceMeters! > _arrivalThresholdMeters) {
      _showArrivalRequiredMessage();
      return;
    }

    final startedAt = DateTime.now();
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    setState(() {
      _visitStartTime = startedAt;
      _elapsed = Duration.zero;
      _stage = _VisitTrackingStage.inProgress;
    });
    _startElapsedTimer();
    unawaited(_persistTrackingState());
  }

  Future<void> _completeVisit() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    final completed = await widget.onCompleteVisit();
    if (completed) await _clearTrackingState();
    if (!mounted) return;
    setState(() => _isCompleting = false);
    if (completed) Navigator.pop(context, true);
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Not scheduled';
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

  String _formatTime(DateTime? value) {
    if (value == null) return '--:--';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  String get _elapsedText {
    final hours = _elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DoctorUiConstants.doctorBackground,
      appBar: AppBar(
        backgroundColor: DoctorUiConstants.doctorBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _teal,
        centerTitle: true,
        title: Text(
          _stage == _VisitTrackingStage.inProgress
              ? 'Visit In Progress'
              : 'Visit Tracking',
          style: const TextStyle(
            color: _text,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isRestoring
            ? const Center(child: CircularProgressIndicator(color: _teal))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    children: [
                      _buildProgress(),
                      const SizedBox(height: 18),
                      _buildPatientCard(),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: switch (_stage) {
                          _VisitTrackingStage.onTheWay => _buildOnTheWay(),
                          _VisitTrackingStage.arrived => _buildArrived(),
                          _VisitTrackingStage.inProgress => _buildInProgress(),
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProgress() {
    const labels = ['On The Way', 'Arrived', 'In Progress'];
    const icons = [
      Icons.directions_car,
      Icons.location_on,
      Icons.medical_services_outlined,
    ];
    final activeIndex = _stage.index;

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
                        color: active ? _teal : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? _teal : const Color(0xFFD7E0DE),
                        ),
                        boxShadow: active
                            ? const [
                                BoxShadow(
                                  color: Color(0x260F8B8D),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        icons[index],
                        size: 21,
                        color: active ? Colors.white : _muted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[index],
                        style: TextStyle(
                          color: active ? _teal : _muted,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 12,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (index < labels.length - 1)
                Container(
                  width: 26,
                  height: 1.5,
                  margin: const EdgeInsets.only(bottom: 25),
                  color: index < activeIndex ? _teal : const Color(0xFFD7E0DE),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildPatientCard() {
    return _card(
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 58,
              height: 58,
              color: const Color(0xFFE4F4F1),
              child: profileAvatarOrPlaceholder(
                imageUrl: _profileImage,
                size: 58,
                placeholderColor: _teal,
                placeholderIcon: Icons.person,
                iconSize: 30,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _serviceType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, letterSpacing: 0),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 15, color: _teal),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _patientPhone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _teal,
                          fontSize: 12,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnTheWay() {
    return Column(
      key: const ValueKey('on-the-way'),
      children: [
        _statusBanner(
          icon: Icons.directions_car,
          title: 'On The Way',
          subtitle: 'You are on your way to the patient',
        ),
        const SizedBox(height: 14),
        _card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const SizedBox(
                height: 230,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: CustomPaint(painter: _RouteMapPainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _detailRow(
                      Icons.event_outlined,
                      'Appointment',
                      _formatDateTime(_scheduledAt),
                    ),
                    const Divider(height: 22),
                    _detailRow(
                      Icons.location_on_outlined,
                      'Patient Location',
                      _patientAddress,
                    ),
                    const Divider(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _metric(
                            Icons.schedule_outlined,
                            'Estimated time',
                            '-- min',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 44,
                          color: const Color(0xFFE3E9E7),
                        ),
                        Expanded(
                          child: _metric(
                            Icons.route_outlined,
                            'Distance',
                            _distanceText,
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
        const SizedBox(height: 14),
        if (_locationError != null) ...[
          _locationErrorMessage(_locationError!),
          const SizedBox(height: 14),
        ],
        _infoMessage(
          Icons.shield_outlined,
          'Please drive safely and follow traffic rules.',
        ),
        const SizedBox(height: 18),
        _primaryButton(
          icon: Icons.navigation_outlined,
          label: 'Start Navigation',
          isLoading: _isLocating,
          onPressed: _startLocationTracking,
        ),
      ],
    );
  }

  Widget _buildArrived() {
    return Column(
      key: const ValueKey('arrived'),
      children: [
        _statusBanner(
          icon: Icons.check_circle,
          title: 'Arrived Successfully',
          subtitle: 'You have reached the patient location',
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF2EE),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFB8E0D8), width: 2),
                ),
                child: const Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.location_on, size: 54, color: _teal),
                      Positioned(
                        bottom: 39,
                        child: Icon(
                          Icons.circle,
                          size: 15,
                          color: Color(0xFF2677E8),
                        ),
                      ),
                    ],
                  ),
                ),
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
          onPressed:
              _distanceMeters != null &&
                  _distanceMeters! <= _arrivalThresholdMeters
              ? _startVisit
              : _showArrivalRequiredMessage,
        ),
      ],
    );
  }

  Widget _buildInProgress() {
    return Column(
      key: const ValueKey('in-progress'),
      children: [
        _statusBanner(
          icon: Icons.medical_services_outlined,
          title: 'Visit In Progress',
          subtitle: 'Consultation in progress',
        ),
        const SizedBox(height: 14),
        _card(
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: _teal, size: 30),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Visit Duration',
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _elapsedText,
                    style: const TextStyle(
                      color: _teal,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'Live',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            children: [
              _detailRow(
                Icons.calendar_today_outlined,
                'Start Time',
                _formatTime(_visitStartTime),
              ),
              const Divider(height: 24),
              _detailRow(
                Icons.location_on_outlined,
                'Patient Location',
                _patientAddress,
              ),
              const Divider(height: 24),
              _detailRow(
                Icons.medical_services_outlined,
                'Visit Type',
                _serviceType,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _infoMessage(
          Icons.info_outline,
          'Complete the visit when the consultation is finished.',
        ),
        const SizedBox(height: 18),
        _primaryButton(
          icon: Icons.check_circle_outline,
          label: 'Complete Visit',
          isLoading: _isCompleting,
          onPressed: _completeVisit,
        ),
      ],
    );
  }

  Widget _statusBanner({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF3EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC5E8E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _teal),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
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
        Icon(icon, color: _teal, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: _muted, letterSpacing: 0),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metric(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: _teal),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12, letterSpacing: 0),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: _text,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
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
          Icon(icon, color: success ? AppColors.success : _teal, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _text,
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
          ),
          if (success)
            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
        ],
      ),
    );
  }

  Widget _locationErrorMessage(String message) {
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
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8A1C1C),
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
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
        border: Border.all(color: const Color(0xFFDDE8E5)),
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

class _RouteMapPainter extends CustomPainter {
  const _RouteMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFE9F0EC);
    canvas.drawRect(Offset.zero & size, background);

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
    canvas.drawLine(
      Offset(size.width * .75, 0),
      Offset(size.width * .62, size.height),
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
    final routePaint = Paint()
      ..color = const Color(0xFF0F8B8D)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, routePaint);

    final doctorPoint = Offset(size.width * .17, size.height * .73);
    final patientPoint = Offset(size.width * .82, size.height * .28);
    canvas.drawCircle(doctorPoint, 13, Paint()..color = Colors.white);
    canvas.drawCircle(doctorPoint, 8, Paint()..color = const Color(0xFF2677E8));
    canvas.drawCircle(patientPoint, 18, Paint()..color = Colors.white);
    canvas.drawCircle(
      patientPoint,
      14,
      Paint()..color = const Color(0xFF0F8B8D),
    );

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
    marker.paint(
      canvas,
      patientPoint - Offset(marker.width / 2, marker.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VisitLocationException implements Exception {
  final String message;

  const _VisitLocationException(this.message);
}

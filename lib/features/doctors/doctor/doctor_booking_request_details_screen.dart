import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/profile_avatar.dart';
import 'package:carelink/features/patient/screens/chat_screen.dart';
import 'package:carelink/features/patient/screens/profile_screen.dart'
    as patient_profile;
import 'package:carelink/services/doctor_service.dart';

class DoctorBookingRequestDetailsScreen extends StatefulWidget {
  const DoctorBookingRequestDetailsScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<DoctorBookingRequestDetailsScreen> createState() =>
      _DoctorBookingRequestDetailsScreenState();
}

class _DoctorBookingRequestDetailsScreenState
    extends State<DoctorBookingRequestDetailsScreen> {
  final DoctorService _doctorService = DoctorService();

  bool _isLoading = true;
  String? _errorMessage;
  String _doctorId = '';
  Map<String, dynamic> _request = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      final request = await _doctorService.getRequestDetails(widget.requestId);
      if (!mounted) return;
      setState(() {
        _doctorId = doctorId;
        _request = request;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _openPatientProfile() {
    final patientId = _patientId;
    if (patientId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => patient_profile.ProfileScreen(userId: patientId),
      ),
    );
  }

  void _messagePatient() {
    if (_patientId.isEmpty || _doctorId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          name: _patientName,
          userId: _patientId,
          doctorId: _doctorId,
          currentUserId: _doctorId,
          isDoctorView: true,
          peerImageUrl: _patientImageUrl,
        ),
      ),
    );
  }

  String get _patientId => _firstString([
    _request['patientUserId'],
    _request['patientId'],
    _request['userId'],
  ]);

  String get _patientName => _firstString([
    _request['patientName'],
    _request['fullName'],
    _request['name'],
  ], fallback: 'Patient');

  String? get _patientImageUrl {
    final url = profileImageUrlFromMap(_request);
    if (url != null) return url;
    final nested = _request['patient'];
    if (nested is Map) {
      return profileImageUrlFromMap(Map<String, dynamic>.from(nested));
    }
    return null;
  }

  String get _serviceType => _cleanService(
    _firstString([
      _request['serviceType'],
      _request['appointmentType'],
      _request['type'],
      _request['reasonForVisit'],
    ], fallback: 'Service request'),
  );

  String get _status =>
      _normalizeStatus(_firstString([_request['status']], fallback: 'pending'));

  String get _address => _firstString([
    _request['visitAddress'],
    _request['address'],
    _request['location'],
    _request['locationNote'],
  ], fallback: 'Not specified');

  DateTime? get _scheduledAt {
    final raw = _firstString([
      _request['scheduledAt'],
      _request['appointmentDateTime'],
      _request['dateTime'],
    ]);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toLocal();
  }

  String get _dateText {
    final scheduledAt = _scheduledAt;
    if (scheduledAt != null) {
      return '${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year}';
    }
    return _firstString([
      _request['appointmentDate'],
      _request['date'],
    ], fallback: 'Not scheduled');
  }

  String get _timeText {
    final scheduledAt = _scheduledAt;
    if (scheduledAt != null) {
      final hour = scheduledAt.hour.toString().padLeft(2, '0');
      final minute = scheduledAt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return _firstString([
      _request['appointmentTime'],
      _request['time'],
    ], fallback: 'Not scheduled');
  }

  @override
  Widget build(BuildContext context) {
    final palette = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: palette.pageBg,
      appBar: AppBar(
        title: const Text('Booking Request'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
          ? _ErrorState(message: _errorMessage!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PatientSummaryCard(
                    palette: palette,
                    patientName: _patientName,
                    patientImageUrl: _patientImageUrl,
                    serviceType: _serviceType,
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    palette: palette,
                    title: 'Appointment Details',
                    children: [
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: _dateText,
                      ),
                      _DetailRow(
                        icon: Icons.schedule_outlined,
                        label: 'Time',
                        value: _timeText,
                      ),
                      _DetailRow(
                        icon: Icons.medical_services_outlined,
                        label: 'Service Type',
                        value: _serviceType,
                      ),
                      _DetailRow(
                        icon: Icons.place_outlined,
                        label: 'Address',
                        value: _address,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    palette: palette,
                    title: 'Request Status',
                    children: [_StatusBadge(status: _status)],
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: _patientId.isEmpty ? null : _openPatientProfile,
                    icon: const Icon(Icons.person_search_outlined),
                    label: const Text('View Patient Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _patientId.isEmpty || _doctorId.isEmpty
                        ? null
                        : _messagePatient,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Message Patient'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PatientSummaryCard extends StatelessWidget {
  const _PatientSummaryCard({
    required this.palette,
    required this.patientName,
    required this.patientImageUrl,
    required this.serviceType,
  });

  final CarelinkPalette palette;
  final String patientName;
  final String? patientImageUrl;
  final String serviceType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(palette),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 64,
              height: 64,
              color: AppColors.primary.withValues(alpha: 0.1),
              child: profileAvatarOrPlaceholder(
                imageUrl: patientImageUrl,
                size: 64,
                placeholderColor: AppColors.primary,
                placeholderIcon: Icons.person_outline_rounded,
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
                  patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.inkDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  serviceType,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.inkMuted,
                    fontSize: 13,
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
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.palette,
    required this.title,
    required this.children,
  });

  final CarelinkPalette palette;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(palette),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.inkDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = CarelinkPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: palette.inkMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: palette.inkDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(CarelinkPalette palette) {
  return BoxDecoration(
    color: palette.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: palette.stroke),
    boxShadow: [
      BoxShadow(
        color: palette.cardShadowColor(0.06),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

String _firstString(List<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return fallback;
}

String _cleanService(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _normalizeStatus(String raw) {
  final status = raw.trim().toLowerCase().replaceAll('_', ' ');
  switch (status) {
    case 'confirmed':
    case 'accepted':
      return 'Accepted';
    case 'complete':
    case 'completed':
      return 'Completed';
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    default:
      return 'Pending';
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'accepted':
      return AppColors.success;
    case 'completed':
      return AppColors.info;
    case 'cancelled':
      return Colors.redAccent;
    default:
      return AppColors.warning;
  }
}

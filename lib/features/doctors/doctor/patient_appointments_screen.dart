import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/doctor_service.dart';
import 'doctor_ui_constants.dart';

class DoctorPatientAppointmentsScreen extends StatefulWidget {
  const DoctorPatientAppointmentsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  final String patientId;
  final String patientName;

  @override
  State<DoctorPatientAppointmentsScreen> createState() =>
      _DoctorPatientAppointmentsScreenState();
}

class _DoctorPatientAppointmentsScreenState
    extends State<DoctorPatientAppointmentsScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  List<dynamic> _appointments = [];

  static const _pageColor = DoctorUiConstants.doctorBackground;
  static const _primary = Color(0xFF0F8B8D);
  static const _textDark = Color(0xFF101828);
  static const _textMuted = Color(0xFF667085);

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      final requests = doctorId.isEmpty
          ? <dynamic>[]
          : await _doctorService.getRequests(doctorId);

      if (!mounted) return;
      setState(() {
        _appointments = requests.where((item) {
          final request = item is Map ? item : <String, dynamic>{};
          return (request['patientUserId'] ?? '').toString() ==
              widget.patientId;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading patient appointments: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DoctorTypographyScope(
      child: Scaffold(
        backgroundColor: _pageColor,
        appBar: AppBar(
          backgroundColor: _pageColor,
          surfaceTintColor: _pageColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: _primary,
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text(
            'Appointments',
            style: TextStyle(
              color: _textDark,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: RefreshIndicator(
                onRefresh: _loadAppointments,
                color: _primary,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _appointments.isEmpty
                    ? _emptyState()
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                        children: [
                          _summaryCard(),
                          const SizedBox(height: 18),
                          for (final appointment in _appointments)
                            _appointmentCard(appointment),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(22),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F4F1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.event_note_rounded, color: _primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patientName.isEmpty ? 'Patient' : widget.patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_appointments.length} appointments and requests',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentCard(dynamic raw) {
    final item = raw is Map ? Map<String, dynamic>.from(raw) : {};
    final serviceType =
        _text(item['serviceType']) ??
        _text(item['reasonForVisit']) ??
        'Medical visit';
    final status = _text(item['status']) ?? 'pending';
    final scheduledAt = _text(item['scheduledAt']);
    final location =
        _text(item['visitAddress']) ??
        _text(item['location']) ??
        _text(item['addressText']) ??
        'Location not set';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F4F1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: _primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        serviceType,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _statusBadge(status),
                  ],
                ),
                const SizedBox(height: 12),
                _metaRow(
                  Icons.schedule_rounded,
                  [
                    _formatDate(scheduledAt),
                    _formatTime(scheduledAt),
                  ].where((x) => x.isNotEmpty).join(' - '),
                ),
                const SizedBox(height: 8),
                _metaRow(Icons.place_outlined, location),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
          decoration: _cardDecoration(24),
          child: Column(
            children: const [
              Icon(Icons.event_busy_rounded, size: 56, color: _primary),
              SizedBox(height: 16),
              Text(
                'No appointments for this patient',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Only this patient\'s requests and visits will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not set' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'completed' => const Color(0xFF12A150),
      'confirmed' => const Color(0xFF0F8B8D),
      'cancelled' || 'canceled' => const Color(0xFFD92D20),
      'pending' || 'pending_provider_approval' => const Color(0xFFF79009),
      _ => const Color(0xFF667085),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(double radius) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 24,
          spreadRadius: -10,
          offset: const Offset(0, 14),
        ),
      ],
    );
  }

  String? _text(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(String? value) {
    if (value == null || value.isEmpty) return '';
    final date = DateTime.tryParse(value);
    if (date == null) return '';
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

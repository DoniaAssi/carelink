import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
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
  List<dynamic> appointments = [];
  bool isLoading = true;
  String? errorMessage;
  _ScheduleFilter currentFilter = _ScheduleFilter.pending;

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
      final data = await ApiService().getAppointments(widget.patientUserId);

      if (!mounted) return;

      setState(() {
        appointments = data;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<dynamic> get filteredAppointments {
    return appointments.where((item) {
      final status = _normalizedStatus(item['status']?.toString());
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
    if (status == 'completed') return 'completed';
    if (status == 'cancelled') return 'cancelled';
    return 'upcoming';
  }

  DateTime? _parseScheduledAt(dynamic rawValue) {
    final value = rawValue?.toString();
    if (value == null || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date unavailable';

    final monthNames = [
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

    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return 'Time unavailable';

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = '${date.minute}'.padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _providerRoleLabel(dynamic item) {
    final role = item['providerRole']?.toString().toLowerCase();
    if (role == 'doctor') return 'Doctor';
    if (role == 'nurse') return 'Nurse';
    return 'Care Provider';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFEF6C00);
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'cancelled':
        return const Color(0xFFC62828);
      default:
        return AppColors.primaryDark;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Approval';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Upcoming';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: AppBar(
        centerTitle: true,
        title: const CarelinkAppBarTitle('My Schedule'),
        actions: carelinkAppBarActions(),
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
              _buildHeroCard(),
              const SizedBox(height: 18),
              _buildFilterTabs(),
              const SizedBox(height: 18),
              _buildBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
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
                const Text(
                  'Appointments Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track your upcoming visits and review completed or cancelled bookings in one place.',
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

  Widget _buildFilterTabs() {
    return Row(
      children: [
        Expanded(
          child: _filterChip(
            label: 'Pending',
            filter: _ScheduleFilter.pending,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _filterChip(
            label: 'Upcoming',
            filter: _ScheduleFilter.upcoming,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _filterChip(
            label: 'Completed',
            filter: _ScheduleFilter.completed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _filterChip(
            label: 'Cancelled',
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
            color: isSelected ? AppColors.primaryDark : AppColors.border,
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

  Widget _buildBody() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
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
              errorMessage!,
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
              child: const Text('Try Again'),
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
              'No ${_statusLabel(_filterToStatus(currentFilter)).toLowerCase()} appointments found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your appointments will appear here after your booking request is sent.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
        final status = _normalizedStatus(item['status']?.toString());
        final appointmentId = (item['appointmentId'] ?? item['requestId'] ?? '')
            .toString()
            .trim();
        final providerLabel = (item['providerName'] ?? item['doctorName'] ?? '')
            .toString()
            .trim();

        return Material(
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
          margin: const EdgeInsets.only(bottom: 14),
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
                          providerLabel.isNotEmpty ? providerLabel : 'Provider',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_providerRoleLabel(item)} - ${item['specialization']?.toString() ?? 'Specialization unavailable'}',
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
                      color: _statusColor(status).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _scheduleMeta(
                      icon: Icons.event_rounded,
                      title: 'Date',
                      value: _formatDate(scheduledAt),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _scheduleMeta(
                      icon: Icons.access_time_rounded,
                      title: 'Time',
                      value: _formatTime(scheduledAt),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
      }).toList(),
    );
  }

  String _filterToStatus(_ScheduleFilter filter) {
    switch (filter) {
      case _ScheduleFilter.completed:
        return 'completed';
      case _ScheduleFilter.cancelled:
        return 'cancelled';
      case _ScheduleFilter.pending:
        return 'pending';
      case _ScheduleFilter.upcoming:
        return 'upcoming';
    }
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

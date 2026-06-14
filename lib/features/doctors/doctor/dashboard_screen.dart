import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/locale_controller.dart';
import '../../../core/theme_controller.dart';
import 'package:carelink/features/notifications/notifications_screen.dart';
import '../../../services/doctor_service.dart';
import '../../../shared/widgets/carelink_brand_logo.dart';
import 'patients_screen.dart';
import 'payments_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'requests_list_screen.dart';
import 'schedule_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  int _selectedIndex = 0;
  Map<String, dynamic> _stats = {};
  List<dynamic> _schedule = [];
  String _doctorName = '';
  String _doctorId = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _doctorId = prefs.getString('doctor_userId') ?? '';
      _doctorName = prefs.getString('doctor_fullName') ?? 'Doctor';

      if (_doctorId.isNotEmpty) {
        final results = await Future.wait([
          _doctorService.getDashboardStats(_doctorId),
          _doctorService.getRequests(_doctorId),
        ]);

        if (!mounted) return;
        final requests = results[1] as List<dynamic>;
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _schedule = requests.take(4).toList();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NotificationsScreen(userId: _doctorId, userRole: 'doctor'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) {
        return Directionality(
          textDirection: localeController.isDoctorArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: _pageColor,
            body: _buildBody(),
            bottomNavigationBar: _buildBottomNav(),
          ),
        );
      },
    );
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _pageColor =>
      _isDark ? const Color(0xFF0F1716) : const Color(0xFFF4FAF8);

  Color get _cardColor => _isDark ? const Color(0xFF182321) : Colors.white;

  Color get _primaryText => _isDark ? const Color(0xFFF3FAF8) : Colors.black;

  Color get _secondaryText =>
      _isDark ? const Color(0xFFB7C5C1) : const Color(0xFF68727D);

  Color get _dividerColor =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100;

  Color _softColor(Color lightColor) {
    return _isDark ? AppColors.primary.withValues(alpha: 0.14) : lightColor;
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHome();
      case 1:
        return const DoctorScheduleScreen();
      case 2:
        return const DoctorPatientsScreen();
      case 3:
        return const DoctorPaymentsScreen();
      case 4:
        return const DoctorReportsScreen();
      case 5:
        return const DoctorProfileScreen();
      default:
        return _buildHome();
    }
  }

  Widget _buildHome() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 118),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 34),
                  _buildWelcomeHeader(),
                  const SizedBox(height: 34),
                  _buildStatsGrid(),
                  const SizedBox(height: 26),
                  _buildReportsCard(),
                  const SizedBox(height: 26),
                  _buildScheduleTitle(),
                  const SizedBox(height: 10),
                  _buildSchedulePanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const CarelinkBrandLogo(height: 34),
        const Spacer(),
        _roundIcon(
          Icons.language_rounded,
          () => localeController.toggleDoctor(),
        ),
        const SizedBox(width: 12),
        ListenableBuilder(
          listenable: themeController,
          builder: (context, _) {
            return _roundIcon(
              themeController.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              () => themeController.toggle(),
            );
          },
        ),
        const SizedBox(width: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _roundIcon(Icons.notifications_none_rounded, _openNotifications),
            Positioned(
              top: 6,
              right: 8,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF1744),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: _cardColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: _primaryText, size: 27),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Row(
      children: [
        Container(
          width: 120,
          height: 120,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Color(0xFFE2F1F7),
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            'assets/images/doctorportrait.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 70,
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.dtr(
                  'doctor.dashboard.helloDoctor',
                  args: {'name': _doctorName},
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 28,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.dtr(
                  'doctor.dashboard.overviewLine',
                  args: {'greeting': _greeting()},
                ),
                style: TextStyle(
                  fontSize: 17,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: _secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              color: AppColors.primary.withValues(alpha: 0.07),
              size: 66,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RequestsListScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                fixedSize: const Size(56, 56),
                padding: EdgeInsets.zero,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final today = _toInt(_stats['todayAppointments']);
    final pending = _toInt(_stats['pendingRequests']);
    final rating = _toDouble(_stats['averageRating']);
    final responseRate = _toDouble(_stats['responseRate']);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.22,
      children: [
        _metricCard(
          value: today.toString(),
          label: context.dtr('doctor.dashboard.appointmentsToday'),
          icon: Icons.medical_services_outlined,
          color: AppColors.primary,
          background: const Color(0xFFE7F7F2),
        ),
        _metricCard(
          value: pending.toString(),
          label: context.dtr('doctor.dashboard.upcomingRequests'),
          icon: Icons.event_note_outlined,
          color: AppColors.info,
          background: const Color(0xFFEAF4FF),
        ),
        _metricCard(
          value: rating.toStringAsFixed(1),
          label: context.dtr('doctor.dashboard.averageRating'),
          icon: Icons.favorite_border_rounded,
          color: const Color(0xFFE91E63),
          background: const Color(0xFFFCE7EF),
        ),
        _metricCard(
          value: '${responseRate.round()}%',
          label: context.dtr('doctor.dashboard.responseRate'),
          icon: Icons.link_rounded,
          color: AppColors.primary,
          background: const Color(0xFFE7F7F2),
        ),
      ],
    );
  }

  Widget _buildReportsCard() {
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = 4),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _softColor(const Color(0xFFE7F7F2)),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.dtr('doctor.dashboard.medicalReports'),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _primaryText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.dtr('doctor.dashboard.medicalReportsSubtitle'),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: _secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => setState(() => _selectedIndex = 4),
                icon: const Icon(Icons.add_rounded, size: 22),
                label: Text(context.dtr('doctor.dashboard.newReport')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.16 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _softColor(background),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
              color: _primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: _primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.dtr('doctor.dashboard.todaysSchedule'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: _primaryText,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RequestsListScreen(),
              ),
            );
          },
          child: Text(
            context.dtr('doctor.dashboard.viewAll'),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulePanel() {
    if (_schedule.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 42,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              context.dtr('doctor.dashboard.noAppointmentsToday'),
              style: TextStyle(
                color: _secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _schedule.length; i++) ...[
            _scheduleRow(_schedule[i]),
            if (i != _schedule.length - 1)
              Divider(height: 1, color: _dividerColor),
          ],
        ],
      ),
    );
  }

  Widget _scheduleRow(dynamic rawItem) {
    final item = rawItem is Map ? rawItem : <String, dynamic>{};
    final patientName = (item['patientName'] ?? 'Unavailable').toString();
    final serviceType = (item['serviceType'] ?? 'Consultation').toString();
    final status = (item['status'] ?? 'pending').toString();
    final scheduledAt = item['scheduledAt'] ?? item['requestedDate'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              _formatTime(scheduledAt),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _primaryText,
              ),
            ),
          ),
          CircleAvatar(
            radius: 22,
            backgroundColor: _softColor(const Color(0xFFE7F7F2)),
            child: Text(
              patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  serviceType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusBadge(status),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _dividerColor),
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final lower = status.toLowerCase();
    final isCanceled = lower.contains('cancel') || lower.contains('reject');
    final isPending = lower.contains('pending');
    final color = isCanceled
        ? const Color(0xFFE91E63)
        : isPending
        ? const Color(0xFF23252A)
        : AppColors.primary;
    final background = isCanceled
        ? const Color(0xFFFFE4EE)
        : isPending
        ? const Color(0xFFF3F4F6)
        : const Color(0xFFE7F7F2);
    final label = isCanceled
        ? context.dtr('doctor.dashboard.statusCanceled')
        : isPending
        ? context.dtr('doctor.dashboard.statusPending')
        : context.dtr('doctor.dashboard.statusConfirmed');

    return Container(
      constraints: const BoxConstraints(minWidth: 84),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() => _selectedIndex = index);
              if (index == 0) _loadDashboardData();
            },
            selectedItemColor: AppColors.primary,
            unselectedItemColor: _secondaryText,
            selectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: _cardColor,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_rounded),
                label: context.dtr('doctor.nav.home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month_outlined),
                label: context.dtr('doctor.nav.schedule'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.group_outlined),
                label: context.dtr('doctor.nav.patients'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: context.dtr('doctor.nav.payment'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.article_outlined),
                label: context.dtr('doctor.nav.reports'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline_rounded),
                label: context.dtr('doctor.nav.profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.dtr('doctor.dashboard.goodMorning');
    if (hour < 17) return context.dtr('doctor.dashboard.goodAfternoon');
    return context.dtr('doctor.dashboard.goodEvening');
  }

  String _formatTime(dynamic value) {
    if (value is! String) return '--:--';
    final date = DateTime.tryParse(value);
    if (date == null) return '--:--';

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

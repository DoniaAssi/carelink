import 'package:carelink/core/profile_avatar.dart';
import 'package:carelink/features/notifications/notifications_screen.dart';
import 'package:carelink/shared/services/notification_center.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/locale_controller.dart';
import '../../../core/theme_controller.dart';
import '../../../services/doctor_service.dart';
import 'doctor_ui_constants.dart';
import 'medical_record_screen.dart';
import 'patients_screen.dart';
import 'payments_screen.dart';
import 'profile_screen.dart';
import 'ratings_screen.dart';
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
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _rateStatus = {};
  List<dynamic> _requests = [];
  String _doctorName = '';
  String _doctorId = '';
  bool _rateDialogShown = false;

  @override
  void initState() {
    super.initState();
    notificationCenter.addListener(_onNotificationsChanged);
    _loadDashboardData();
  }

  @override
  void dispose() {
    notificationCenter.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _doctorId = prefs.getString('doctor_userId') ?? '';
      _doctorName = prefs.getString('doctor_fullName') ?? '';

      if (_doctorId.isNotEmpty) {
        final previousRateSetAt = _rateStatus['rateSetAt']?.toString();
        final results = await Future.wait([
          _doctorService.getDashboardStats(_doctorId),
          _doctorService.getRequests(_doctorId),
          _doctorService.getProfile(_doctorId),
          _doctorService.getRateStatus(_doctorId),
          notificationCenter.load(_doctorId, force: true).then((_) => null),
        ]);

        if (!mounted) return;
        final nextRateStatus = results[3] as Map<String, dynamic>;
        final nextRateSetAt = nextRateStatus['rateSetAt']?.toString();
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _requests = results[1] as List<dynamic>;
          _profile = results[2] as Map<String, dynamic>;
          _rateStatus = nextRateStatus;
          if (previousRateSetAt != nextRateSetAt &&
              (nextRateStatus['rateAcceptanceStatus'] ?? '')
                      .toString()
                      .toLowerCase() ==
                  'pending') {
            _rateDialogShown = false;
          }
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPendingRateDialog();
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _canUsePayments => _rateStatus['canWork'] == true;

  String get _rateAcceptanceStatus =>
      (_rateStatus['rateAcceptanceStatus'] ?? 'pending')
          .toString()
          .toLowerCase();

  double get _assignedRate => _toDouble(_rateStatus['providerRate']);

  Future<void> _showPendingRateDialog() async {
    if (!mounted ||
        _rateDialogShown ||
        _doctorId.isEmpty ||
        _assignedRate <= 0 ||
        _rateAcceptanceStatus != 'pending' ||
        (_rateStatus['approvalStatus'] ?? '').toString().toLowerCase() !=
            'approved') {
      return;
    }
    _rateDialogShown = true;
    var submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            icon: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payments_outlined,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            title: Text(
              context.dx('Service Rate Approval'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primaryText,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.dx(
                    'The administrator has assigned your service rate. Please review and accept it before continuing.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _secondaryText,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        context.dx('Assigned Rate'),
                        style: TextStyle(
                          color: _secondaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_assignedRate.toStringAsFixed(2)} ILS',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        setDialogState(() => submitting = true);
                        final closed = await _submitRateDecision(
                          'rejected',
                          dialogContext,
                        );
                        if (!closed && dialogContext.mounted) {
                          setDialogState(() => submitting = false);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade400),
                  minimumSize: const Size(120, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(context.dx('Reject')),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        setDialogState(() => submitting = true);
                        final closed = await _submitRateDecision(
                          'accepted',
                          dialogContext,
                        );
                        if (!closed && dialogContext.mounted) {
                          setDialogState(() => submitting = false);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(120, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(context.dx('Accept')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _submitRateDecision(
    String decision,
    BuildContext dialogContext,
  ) async {
    try {
      final result = await _doctorService.decideRate(_doctorId, decision);
      if (!mounted) return false;
      setState(() => _rateStatus = result);
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'accepted'
                ? context.dx('Service rate accepted. Payment is now available.')
                : context.dx(
                    'Service rate rejected. Please wait for administrator review.',
                  ),
          ),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return false;
    }
  }

  void _selectDashboardTab(int index) {
    if (index == 3 && !_canUsePayments) {
      final reason =
          (_rateStatus['reason'] ??
                  'Accept your assigned service rate before using Payment.')
              .toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reason)));
      _showPendingRateDialog();
      return;
    }
    setState(() => _selectedIndex = index);
    if (index == 0) _loadDashboardData();
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
    return DoctorTypographyScope(
      child: ListenableBuilder(
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
      ),
    );
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _pageColor => DoctorUiConstants.pageColor(context);

  Color get _cardColor => DoctorUiConstants.surfaceColor(context);

  Color get _primaryText => DoctorUiConstants.inkColor(context);

  Color get _secondaryText => DoctorUiConstants.mutedColor(context);

  Color _softColor(Color lightColor) {
    return _isDark ? AppColors.primary.withValues(alpha: 0.14) : lightColor;
  }

  BoxShadow _softShadow({double opacity = 0.06, Offset? offset}) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: _isDark ? 0.22 : opacity),
      blurRadius: 24,
      spreadRadius: _isDark ? -10 : -8,
      offset: offset ?? const Offset(0, 12),
    );
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
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 118),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildActionGrid(),
                  const SizedBox(height: 24),
                  _buildTodayOverview(),
                  const SizedBox(height: 22),
                  _buildNextAppointment(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = _mapOf(_profile['user']);
    final profile = _mapOf(_profile['profile']);
    final name = (user['fullName'] ?? _doctorName).toString();
    final specialty =
        (profile['specialization'] ?? profile['serviceType'] ?? '')
            .toString()
            .trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 106,
          height: 106,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _cardColor,
            shape: BoxShape.circle,
            boxShadow: [_softShadow(opacity: 0.05)],
          ),
          child: ClipOval(
            child: profileAvatarOrPlaceholder(
              imageUrl:
                  profileImageUrlFromMap(user) ??
                  profileImageUrlFromMap(profile),
              size: 98,
              placeholderColor: AppColors.primary,
              placeholderIcon: Icons.medical_services_outlined,
              iconSize: 48,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()},',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _doctorDisplayName(name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                specialty.isEmpty
                    ? context.dtr('doctor.profile.specialization')
                    : specialty,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _buildHeaderActions(),
      ],
    );
  }

  Widget _buildHeaderActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        _roundIcon(
          Icons.language_rounded,
          () => localeController.toggleDoctor(),
          color: const Color(0xFF0F8B8D),
        ),
        ListenableBuilder(
          listenable: themeController,
          builder: (context, _) {
            return _roundIcon(
              themeController.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              () => themeController.toggle(),
              color: themeController.isDark
                  ? const Color(0xFFFFC928)
                  : const Color(0xFF132D5B),
            );
          },
        ),
        _notificationButton(),
      ],
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: color ?? _primaryText, size: 30),
        ),
      ),
    );
  }

  Widget _notificationButton() {
    final count = notificationCenter.unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _roundIcon(
          count > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_rounded,
          _openNotifications,
          color: AppColors.primary,
        ),
        if (count > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF1744),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _pageColor, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionGrid() {
    final pending = _toInt(_stats['pendingRequests']);
    final today = _toInt(_stats['todayAppointments']);
    final patients = _toInt(_stats['totalPatients']);
    final earnings = _toDouble(_stats['totalEarnings']);
    final rating = _toDouble(_stats['averageRating']);

    final cards = [
      _DashboardAction(
        title: context.dtr('doctor.dashboard.actionRequests'),
        icon: Icons.medical_services_rounded,
        badge: pending > 0 ? '$pending' : null,
        subtitle: pending > 0
            ? context.dtr(
                'doctor.dashboard.pendingCount',
                args: {'count': '$pending'},
              )
            : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RequestsListScreen(status: 'pending'),
          ),
        ),
      ),
      _DashboardAction(
        title: context.dtr('doctor.dashboard.actionMySchedule'),
        icon: Icons.calendar_month_rounded,
        subtitle: context.dtr(
          'doctor.dashboard.plansCount',
          args: {'count': '$today'},
        ),
        onTap: () => setState(() => _selectedIndex = 1),
      ),
      _DashboardAction(
        title: context.dtr('doctor.dashboard.actionMyPatients'),
        icon: Icons.groups_2_outlined,
        subtitle: patients > 0
            ? context.dtr(
                'doctor.dashboard.totalCount',
                args: {'count': '$patients'},
              )
            : null,
        onTap: () => setState(() => _selectedIndex = 2),
      ),
      _DashboardAction(
        title: context.dtr('doctor.dashboard.actionEarnings'),
        icon: Icons.account_balance_wallet_rounded,
        subtitle: earnings > 0 ? earnings.toStringAsFixed(0) : null,
        onTap: () => _selectDashboardTab(3),
      ),
      _DashboardAction(
        title: context.dtr('doctor.dashboard.actionReviews'),
        icon: Icons.star_border_rounded,
        subtitle: rating > 0 ? rating.toStringAsFixed(1) : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DoctorRatingsScreen()),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 760
            ? 5
            : constraints.maxWidth >= 480
            ? 3
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) => _actionCard(cards[index]),
        );
      },
    );
  }

  Widget _actionCard(_DashboardAction action) {
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [_softShadow(opacity: 0.045)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(action.icon, color: AppColors.primary, size: 42),
                  if (action.badge != null)
                    Positioned(
                      top: -12,
                      right: -14,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF1744),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _cardColor, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          action.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (action.subtitle != null) ...[
                const SizedBox(height: 9),
                Text(
                  action.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayOverview() {
    final pending = _toInt(_stats['pendingRequests']);
    final today = _toInt(_stats['todayAppointments']);
    final completed = _toInt(_stats['completedRequests']);
    final canceled = _requests.where((item) {
      final status = item is Map ? (item['status'] ?? '').toString() : '';
      return status.toLowerCase().contains('cancel');
    }).length;

    return _sectionCard(
      title: context.dtr('doctor.dashboard.todaysOverview'),
      action: context.dtr('doctor.dashboard.viewAllPlain'),
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RequestsListScreen()),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final itemWidth = compact
              ? (constraints.maxWidth - 12) / 2
              : (constraints.maxWidth - 36) / 4;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _overviewTile(
                width: itemWidth,
                value: '$pending',
                label: context.dtr('doctor.dashboard.newRequests'),
                icon: Icons.person_add_alt_1_outlined,
                color: const Color(0xFF1899D6),
                background: const Color(0xFFEFF4FF),
              ),
              _overviewTile(
                width: itemWidth,
                value: '$today',
                label: context.dtr('doctor.dashboard.todaysVisits'),
                icon: Icons.biotech_outlined,
                color: AppColors.primary,
                background: const Color(0xFFF2F8F4),
              ),
              _overviewTile(
                width: itemWidth,
                value: '$completed',
                label: context.dtr('doctor.dashboard.completed'),
                icon: Icons.directions_walk_rounded,
                color: const Color(0xFFF5A400),
                background: const Color(0xFFFFF6E8),
              ),
              _overviewTile(
                width: itemWidth,
                value: '$canceled',
                label: context.dtr('doctor.dashboard.canceled'),
                icon: Icons.person_off_outlined,
                color: const Color(0xFFFF375F),
                background: const Color(0xFFFFEEF2),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _overviewTile({
    required double width,
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: _softColor(background),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _isDark ? 0.07 : 0.62),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _primaryText,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _secondaryText,
              fontSize: 14,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextAppointment() {
    final appointment = _nextAppointment;

    return _sectionCard(
      title: context.dtr('doctor.dashboard.nextAppointment'),
      action: context.dtr('doctor.dashboard.viewAllPlain'),
      onAction: () => setState(() => _selectedIndex = 1),
      child: appointment == null
          ? _emptyAppointment()
          : _nextAppointmentRow(appointment),
    );
  }

  Widget _nextAppointmentRow(Map<String, dynamic> item) {
    final patientName = _cleanText(item['patientName']);
    final serviceType = _cleanText(item['serviceType']);
    final status = _cleanText(item['status']);
    final location =
        _cleanText(item['visitAddress']) ??
        _cleanText(item['location']) ??
        _cleanText(item['locationNote']);
    final imageUrl =
        profileImageUrlFromMap(item) ??
        profileImageUrlFromMap(_mapOf(item['patient']));

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            _formatTime(item['scheduledAt'] ?? item['requestedDate']),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _secondaryText,
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _softColor(const Color(0xFFE7F7F2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: profileAvatarOrPlaceholder(
            imageUrl: imageUrl,
            size: 60,
            placeholderColor: AppColors.primary,
            placeholderIcon: Icons.person_rounded,
            iconSize: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patientName ?? context.dtr('doctor.common.notSet'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                serviceType ?? context.dtr('doctor.common.notSet'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location ?? context.dtr('doctor.common.notSet'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _statusBadge(status ?? ''),
      ],
    );
  }

  Widget _emptyAppointment() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _softColor(const Color(0xFFE7F7F2)),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.dtr('doctor.dashboard.noAppointmentsToday'),
              style: TextStyle(
                color: _secondaryText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String action,
    required VoidCallback onAction,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_softShadow(opacity: 0.045)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: Text(action),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
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
      constraints: const BoxConstraints(minWidth: 70),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _softColor(background),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
            onTap: _selectDashboardTab,
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

  Map<String, dynamic> _mapOf(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  Map<String, dynamic>? get _nextAppointment {
    final now = DateTime.now();
    final appointments =
        _requests
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) {
              final status = (item['status'] ?? '').toString().toLowerCase();
              final date = DateTime.tryParse(
                (item['scheduledAt'] ?? item['requestedDate'] ?? '').toString(),
              );
              return date != null &&
                  date.isAfter(now) &&
                  (status == 'pending' || status == 'confirmed');
            })
            .toList()
          ..sort((a, b) {
            final aDate = DateTime.parse(
              (a['scheduledAt'] ?? a['requestedDate']).toString(),
            );
            final bDate = DateTime.parse(
              (b['scheduledAt'] ?? b['requestedDate']).toString(),
            );
            return aDate.compareTo(bDate);
          });

    return appointments.isEmpty ? null : appointments.first;
  }

  // Kept for the existing Records flow; its dashboard shortcut is hidden.
  // ignore: unused_element
  void _openRecords() {
    final appointment = _nextAppointment;
    final patientId = appointment == null
        ? ''
        : (appointment['patientUserId'] ?? appointment['patientId'] ?? '')
              .toString();

    if (patientId.isEmpty) {
      setState(() => _selectedIndex = 2);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalRecordScreen(patientId: patientId),
      ),
    );
  }

  String? _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _doctorDisplayName(String name) {
    final clean = name.trim().isEmpty
        ? context.dtr('doctor.dashboard.defaultDoctorName')
        : name.trim();
    final lower = clean.toLowerCase();
    if (lower.startsWith('dr.') || clean.startsWith('د.')) return clean;
    return context.dtr('doctor.dashboard.doctorPrefix', args: {'name': clean});
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
    final suffix = date.hour >= 12
        ? context.dtr('doctor.dashboard.timePm')
        : context.dtr('doctor.dashboard.timeAm');
    return '$hour:$minute\n$suffix';
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.title,
    required this.icon,
    required this.onTap,
    this.badge,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;
  final String? subtitle;
}

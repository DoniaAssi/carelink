import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/features/nurse/models/nurse_dashboard_model.dart';
import 'package:carelink/features/nurse/services/nurse_dashboard_repository.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';

import 'nurse_patients.dart';
import 'nurse_activity_screen.dart';
import 'nurse_earnings_screen.dart';
import 'nurse_profile.dart';
import 'nurse_schedule_screen.dart';
import 'nurse_service_requests.dart';
import 'nurse_ui.dart';
import 'nurse_visit_reports.dart';

class NurseDashboard extends StatefulWidget {
  const NurseDashboard({super.key, required this.user, this.initialIndex = 0});

  final User user;
  final int initialIndex;

  @override
  State<NurseDashboard> createState() => _NurseDashboardState();
}

class _NurseDashboardState extends State<NurseDashboard> {
  late final NurseDashboardController dashboardController;
  Timer? dashboardSyncTimer;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    dashboardController = NurseDashboardController(user: widget.user);
    _loadUiSettings();
    dashboardController.load();
    dashboardSyncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted || selectedIndex != 0) return;
      dashboardController.refresh();
    });
  }

  @override
  void dispose() {
    dashboardSyncTimer?.cancel();
    dashboardController.dispose();
    super.dispose();
  }

  Future<void> _loadUiSettings() async {
    await NurseUi.loadSettings(widget.user.userId);
  }

  Future<void> _decideRate(String decision) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiService.baseUrl}/nurse/rate-status/${widget.user.userId}/decision',
        ),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'decision': decision}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = body is Map<String, dynamic>
            ? body['error']?.toString()
            : null;
        throw Exception(message ?? 'Failed to update rate decision');
      }
      await dashboardController.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'accepted'
                ? 'Hourly rate accepted. Your work tools are unlocked.'
                : 'Hourly rate rejected. Your work tools remain locked.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        drawer: _drawer(),
        body: IndexedStack(
          index: selectedIndex,
          children: [
            _homePage(),
            NurseScheduleScreen(user: widget.user),
            NursePatients(user: widget.user),
            NurseEarningsScreen(user: widget.user),
            ActivityScreen(
              user: widget.user,
              showBottomNavigation: false,
              onRateAccepted: () {
                dashboardController.refresh();
                setState(() => selectedIndex = 0);
              },
            ),
            NurseProfile(user: widget.user),
          ],
        ),
        bottomNavigationBar: _bottomNav(),
      ),
    );
  }

  Widget _homePage() {
    return AnimatedBuilder(
      animation: dashboardController,
      builder: (context, _) {
        final model = dashboardController.model;
        return SafeArea(
          child: RefreshIndicator(
          color: const Color(0xFF0F766E),
            onRefresh: dashboardController.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 104),
              children: [
                if (dashboardController.isLoading)
                  _loadingDashboard()
                else if (dashboardController.error != null || model == null)
                  _errorDashboard()
                else
                  _dashboardContent(model),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dashboardContent(NurseDashboardModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dashboardHeader(model.notificationCount),
        const SizedBox(height: 18),
        _greeting(model),
        const SizedBox(height: 20),
        if (!model.canWork) ...[
          _rateGateCard(model),
        ] else ...[
          _quickGrid(),
          const SizedBox(height: 26),
          _upcomingVisitsSection(model),
          const SizedBox(height: 22),
          _motivationBanner(),
        ],
      ],
    );
  }

  Widget _rateGateCard(NurseDashboardModel model) {
    final hasRate = model.approvedHourlyRate > 0;
    final status = model.rateApprovalStatus.toLowerCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _modernShadow,
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  NurseUi.t('Hourly Rate Approval'),
                  style: TextStyle(
                    color: NurseUi.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasRate
                ? 'Admin approved your rate: ${_money(model.approvedHourlyRate)}/hour'
                : model.rateGateMessage,
            style: TextStyle(
              color: NurseUi.text,
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (hasRate) ...[
            const SizedBox(height: 8),
            Text(
              'Specialization: ${model.specialization}',
              style: TextStyle(
                color: NurseUi.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (hasRate && status != 'rejected') ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _decideRate('accepted'),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(NurseUi.t('Accept Rate')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _decideRate('rejected'),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(NurseUi.t('Reject')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      side: const BorderSide(color: Color(0xFFB91C1C)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dashboardHeader(int notificationCount) {
    return Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 22),
            color: const Color(0xFF0F766E),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        const Spacer(),
        NurseModeControls(
          providerUserId: widget.user.userId,
          onChanged: () => setState(() {}),
        ),
        _notificationButton(notificationCount),
      ],
    );
  }

  Widget _notificationButton(int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, size: 22),
          color: NurseUi.text,
          onPressed: () => setState(() => selectedIndex = 4),
        ),
        if (count > 0) Positioned(right: 4, top: 3, child: _smallBadge(count)),
      ],
    );
  }

  Widget _greeting(NurseDashboardModel model) {
    final name = _firstNameFrom(model.nurseName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          NurseUi.isArabic.value ? 'مرحبا، $name' : 'Hello, Nurse $name',
          style: TextStyle(
            color: NurseUi.text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 7),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: NurseUi.isArabic.value ? 'لديك ' : 'You have '),
              TextSpan(
                text: '${model.upcomingVisitsCount}',
                style: TextStyle(
                  color: Color(0xFF0F766E),
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: NurseUi.isArabic.value
                    ? ' زيارات قادمة اليوم.'
                    : ' upcoming visits today.',
              ),
            ],
          ),
          style: TextStyle(
            color: NurseUi.text,
            fontSize: 11.5,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _quickGrid() {
    final actions = [
      (
        Icons.calendar_month_outlined,
        NurseUi.t('My Schedule'),
        () => setState(() => selectedIndex = 1),
      ),
      (
        Icons.assignment_outlined,
        NurseUi.t('All Requests'),
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NurseServiceRequests(user: widget.user),
          ),
        ).then((_) => dashboardController.refresh()),
      ),
      (
        Icons.people_outline_rounded,
        NurseUi.t('Patients'),
        () => setState(() => selectedIndex = 2),
      ),
      (
        Icons.insert_chart_outlined,
        NurseUi.t('Reports'),
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NurseVisitReports(user: widget.user),
          ),
        ),
      ),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.86,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];
        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: item.$3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: NurseUi.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NurseUi.border),
              boxShadow: _modernShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.$1,
                    color: const Color(0xFF0F766E),
                    size: 17,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    item.$2,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: NurseUi.text,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _upcomingVisitsSection(NurseDashboardModel model) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              NurseUi.t('Upcoming Visits'),
              style: TextStyle(
                color: NurseUi.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NurseServiceRequests(user: widget.user),
                  ),
                ).then((_) => dashboardController.refresh());
              },
              iconAlignment: IconAlignment.end,
              label: Text(
                NurseUi.t('View All'),
                style: TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF0F766E),
                size: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: _modernCardDecoration(radius: 12),
          child: model.upcomingVisits.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 42),
                  child: Center(
                    child: Text(
                      NurseUi.t('No upcoming visits today'),
                      style: TextStyle(
                        color: NurseUi.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < model.upcomingVisits.length; i++) ...[
                      _visitRow(model.upcomingVisits[i]),
                      if (i != model.upcomingVisits.length - 1)
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _visitRow(VisitModel visit) {
    final isPending = visit.status.toLowerCase() == 'pending';
    return InkWell(
      onTap: () => _openRequest(visit.request),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFE6F7F4),
              child: Text(
                visit.patientInitial,
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: NurseUi.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    visit.serviceType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: NurseUi.muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFF14B8A6),
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          visit.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: NurseUi.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFF0F766E),
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      visit.time,
                      style: TextStyle(
                        color: NurseUi.text,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _visitStatusBadge(
                  isPending ? 'Pending' : 'Accepted',
                  isPending ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                  isPending ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF0F766E),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  Widget _motivationBanner() {
    return Container(
      width: double.infinity,
      height: 90,
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 0),
      decoration: BoxDecoration(
        color: NurseUi.softSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NurseUi.border),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  NurseUi.isArabic.value ? 'أنت تقومين بعمل رائع!' : "You're doing great!",
                  style: TextStyle(
                    color: NurseUi.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  NurseUi.isArabic.value
                      ? 'رعايتك تحدث فرقًا كبيرًا.'
                      : 'Your care makes a big difference.',
                  style: TextStyle(
                    color: NurseUi.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(right: 4, bottom: 0, child: _nurseIllustration()),
        ],
      ),
    );
  }

  Widget _nurseIllustration() {
    return SizedBox(
      width: 88,
      height: 82,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            right: 8,
            top: 0,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF0F766E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 48,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFF0F766E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const Icon(
                Icons.local_hospital,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          Positioned(
            bottom: 31,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD7C2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 56,
            child: Container(
              width: 34,
              height: 15,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  color: Color(0xFF0F766E),
                  size: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            _SkeletonBox(width: 42, height: 42, radius: 14),
            Spacer(),
            _SkeletonBox(width: 42, height: 42, radius: 14),
          ],
        ),
        const SizedBox(height: 36),
        const _SkeletonBox(width: 280, height: 38, radius: 12),
        const SizedBox(height: 14),
        const _SkeletonBox(width: 250, height: 24, radius: 10),
        const SizedBox(height: 32),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          childAspectRatio: 0.96,
          children: const [
            _SkeletonBox(radius: 22),
            _SkeletonBox(radius: 22),
            _SkeletonBox(radius: 22),
            _SkeletonBox(radius: 22),
          ],
        ),
        const SizedBox(height: 36),
        const _SkeletonBox(width: 210, height: 28, radius: 10),
        const SizedBox(height: 18),
        const _SkeletonBox(height: 300, radius: 22),
      ],
    );
  }

  Widget _errorDashboard() {
    return Column(
      children: [
        _dashboardHeader(0),
        const SizedBox(height: 130),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: _modernCardDecoration(radius: 24),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                NurseUi.t('Failed to load dashboard data'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: dashboardController.load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
                child: Text(NurseUi.t('Retry')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _drawer() {
    return Drawer(
      backgroundColor: NurseUi.surface,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: _avatar(widget.user.fullName, radius: 24),
              title: Text(
                widget.user.fullName,
                style: TextStyle(
                  color: NurseUi.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                NurseUi.t('Nurse'),
                style: TextStyle(color: NurseUi.muted),
              ),
            ),
            Divider(color: NurseUi.border),
            _drawerItem(
              Icons.home_rounded,
              NurseUi.t('Home'),
              0,
            ),
            _drawerItem(
              Icons.calendar_month_rounded,
              NurseUi.t('Sessions'),
              1,
            ),
            _drawerItem(
              Icons.people_outline_rounded,
              NurseUi.t('Patients'),
              2,
            ),
            _drawerItem(
              Icons.account_balance_wallet_outlined,
              NurseUi.t('Earnings'),
              3,
            ),
            _drawerItem(
              Icons.notifications_none_rounded,
              NurseUi.t('Notifications'),
              4,
            ),
            _drawerItem(
              Icons.person_rounded,
              NurseUi.t('Profile'),
              5,
            ),
          ],
        ),
      ),
    );
  }
  Widget _drawerItem(IconData icon, String label, int index) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0F766E)),
      title: Text(
        label,
        style: TextStyle(color: NurseUi.text, fontWeight: FontWeight.w800),
      ),
      onTap: () {
        Navigator.pop(context);
        if (!_canOpenTab(index)) {
          _showRateLockedMessage();
          setState(() => selectedIndex = 0);
          return;
        }
        setState(() => selectedIndex = index);
      },
    );
  }

  bool _canOpenTab(int index) {
    final canWork = dashboardController.model?.canWork == true;
    if (canWork) return true;
    return index == 0 || index == 4 || index == 5;
  }

  void _showRateLockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Accept your admin-set hourly rate before using nurse services.',
        ),
      ),
    );
  }

  void _openRequest(ServiceRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDetailsScreen(
          request: request,
          currentUser: widget.user,
          providerUserId: widget.user.userId,
          onChanged: dashboardController.refresh,
        ),
      ),
    );
  }

  Widget _visitStatusBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _smallBadge(int count) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: Color(0xFFEF4444),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          count > 9 ? '9+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _avatar(String name, {double radius = 34}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFDDF2EF),
      child: Text(
        name.trim().isEmpty ? 'N' : name.trim()[0].toUpperCase(),
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _bottomNav() {
    final items = [
      (Icons.home_outlined, NurseUi.t('Home')),
      (Icons.calendar_month_outlined, NurseUi.t('Sessions')),
      (Icons.people_outline_rounded, NurseUi.t('Patients')),
      (Icons.account_balance_wallet_outlined, NurseUi.t('Earnings')),
      (Icons.notifications_none_rounded, NurseUi.t('Alerts')),
      (Icons.person_outline_rounded, NurseUi.t('Profile')),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NurseUi.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (!_canOpenTab(i)) {
                      _showRateLockedMessage();
                      setState(() => selectedIndex = 0);
                      return;
                    }
                    setState(() => selectedIndex = i);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].$1,
                        color: selectedIndex == i
                            ? AppColors.primaryDark
                            : NurseUi.muted,
                        size: 21,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selectedIndex == i
                              ? AppColors.primaryDark
                              : NurseUi.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  String _firstNameFrom(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'Nurse';
    return clean.split(RegExp(r'\s+')).first;
  }

  String _money(num value) {
    final fixed = value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$fixed ILS';
  }

  BoxDecoration _modernCardDecoration({required double radius}) {
    return NurseUi.cardDecoration(radius: radius);
  }

  List<BoxShadow> get _modernShadow => NurseUi.softShadow;
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, this.height, required this.radius});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.45, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeInOut,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE6F7F4),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}



import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/features/notifications/notifications_screen.dart';
import 'package:carelink/features/nurse/models/nurse_dashboard_model.dart';
import 'package:carelink/features/nurse/services/nurse_dashboard_repository.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';

import 'nurse_patients.dart';
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
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/nurse/settings/${widget.user.userId}'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      NurseUi.isDarkMode.value = data['darkMode'] == true;
      NurseUi.isArabic.value = data['language'] == 'Arabic';
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: const Color(0xFFF4FAF9),
        drawer: _drawer(),
        body: IndexedStack(
          index: selectedIndex,
          children: [
            _homePage(),
            NurseScheduleScreen(user: widget.user),
            NursePatients(user: widget.user),
            NurseVisitReports(user: widget.user),
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
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 112),
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
        const SizedBox(height: 34),
        _greeting(model),
        const SizedBox(height: 30),
        _quickGrid(),
        const SizedBox(height: 34),
        _upcomingVisitsSection(model),
        const SizedBox(height: 32),
        _motivationBanner(),
      ],
    );
  }

  Widget _dashboardHeader(int notificationCount) {
    return Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 34),
            color: const Color(0xFF0F766E),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        const Spacer(),
        _notificationButton(notificationCount),
      ],
    );
  }

  Widget _notificationButton(int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, size: 32),
          color: const Color(0xFF0F172A),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(userId: widget.user.userId),
              ),
            ).then((_) => dashboardController.refresh());
          },
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
          'Hello, Nurse $name \u{1F44B}',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'You have '),
              TextSpan(
                text: '${model.upcomingVisitsCount}',
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const TextSpan(text: ' upcoming visits today.'),
            ],
          ),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _quickGrid() {
    final actions = [
      (
        Icons.calendar_month_outlined,
        'My Schedule',
        () => setState(() => selectedIndex = 1),
      ),
      (
        Icons.assignment_outlined,
        'All Requests',
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NurseServiceRequests(user: widget.user),
          ),
        ).then((_) => dashboardController.refresh()),
      ),
      (
        Icons.people_outline_rounded,
        'Patients',
        () => setState(() => selectedIndex = 2),
      ),
      (
        Icons.insert_chart_outlined,
        'Reports',
        () => setState(() => selectedIndex = 3),
      ),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 0.96,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];
        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: item.$3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: _modernShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F4),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    item.$1,
                    color: const Color(0xFF0F766E),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    item.$2,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
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
            const Text(
              'Upcoming Visits',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 23,
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
              label: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF0F766E),
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          decoration: _modernCardDecoration(radius: 24),
          child: model.upcomingVisits.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 42),
                  child: Center(
                    child: Text(
                      'No upcoming visits today',
                      style: TextStyle(
                        color: Color(0xFF64748B),
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
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        child: Row(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: const Color(0xFFE6F7F4),
              child: Text(
                visit.patientInitial,
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    visit.serviceType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFF14B8A6),
                        size: 19,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          visit.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFF0F766E),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      visit.time,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _visitStatusBadge(
                  isPending ? 'Pending' : 'Confirmed',
                  isPending ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                  isPending ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
                ),
              ],
            ),
            const SizedBox(width: 22),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF0F766E),
              size: 25,
            ),
          ],
        ),
      ),
    );
  }

  Widget _motivationBanner() {
    return Container(
      width: double.infinity,
      height: 142,
      padding: const EdgeInsets.fromLTRB(34, 24, 18, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7F4),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're doing great!",
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Your care makes a big difference.',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 17,
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
      width: 150,
      height: 132,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            right: 18,
            top: 0,
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFF0F766E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 78,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFF0F766E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: const Icon(Icons.local_hospital, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 52,
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD7C2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 93,
            child: Container(
              width: 54,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  color: Color(0xFF0F766E),
                  size: 18,
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
              const Text(
                'Failed to load dashboard data',
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
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _drawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: _avatar(widget.user.fullName, radius: 24),
              title: Text(
                widget.user.fullName,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('Nurse'),
            ),
            const Divider(),
            _drawerItem(Icons.home_rounded, 'Home', 0),
            _drawerItem(Icons.calendar_month_rounded, 'Schedule', 1),
            _drawerItem(Icons.people_outline_rounded, 'Patients', 2),
            _drawerItem(Icons.insert_chart_outlined, 'Reports', 3),
            _drawerItem(Icons.person_rounded, 'Profile', 4),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, int index) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0F766E)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      onTap: () {
        Navigator.pop(context);
        setState(() => selectedIndex = index);
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _smallBadge(int count) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFFEF4444),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          count > 9 ? '9+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
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
      (Icons.home_rounded, 'Home'),
      (Icons.calendar_month_rounded, 'Schedule'),
      (Icons.groups_rounded, 'Patients'),
      (Icons.folder_copy_outlined, 'Reports'),
      (Icons.person_rounded, 'Profile'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
                  onTap: () => setState(() => selectedIndex = i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].$1,
                        color: selectedIndex == i
                            ? AppColors.primaryDark
                            : const Color(0xFF90A4AE),
                        size: 23,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          color: selectedIndex == i
                              ? AppColors.primaryDark
                              : const Color(0xFF90A4AE),
                          fontSize: 11,
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

  BoxDecoration _modernCardDecoration({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: _modernShadow,
    );
  }

  List<BoxShadow> get _modernShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.045),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/features/notifications/notifications_screen.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/chat_repository.dart';
import 'package:carelink/shared/services/service_request_service.dart';

import 'nurse_messages_screen.dart';
import 'nurse_patients.dart';
import 'nurse_payments.dart';
import 'nurse_profile.dart';
import 'nurse_schedule_screen.dart';
import 'nurse_service_requests.dart';
import 'nurse_settings.dart';
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
  int selectedIndex = 0;
  int pendingRequests = 0;
  int todaysVisits = 0;
  int waitingReports = 0;
  int completedVisits = 0;
  int unreadMessages = 0;
  List<ServiceRequest> requests = [];
  final ChatRepository chatRepository = ChatRepository();

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    _loadUiSettings();
    _loadDashboard();
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

  Future<void> _loadDashboard() async {
    try {
      final statsResponse = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/nurse/dashboard/${widget.user.userId}',
        ),
      );
      final loadedRequests = await ServiceRequestService.getProviderRequests(
        widget.user.userId,
      );
      final loadedUnread = await chatRepository.getUnreadCount(
        widget.user.userId,
      );
      if (!mounted) return;
      if (statsResponse.statusCode >= 200 && statsResponse.statusCode < 300) {
        final data = jsonDecode(statsResponse.body) as Map<String, dynamic>;
        pendingRequests = _parseInt(data['pendingRequests']);
        todaysVisits = _parseInt(data['todaysVisits']);
        waitingReports = _parseInt(data['waitingReports']);
        completedVisits = _parseInt(data['completedVisits']);
      }
      setState(() {
        requests = loadedRequests;
        unreadMessages = loadedUnread;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
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
    final upcoming = _upcomingVisit;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          children: [
            _topActions(showBack: false),
            const SizedBox(height: 18),
            Row(
              children: [
                _avatar(widget.user.fullName),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning, $_firstName',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF151823),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Nurse',
                        style: TextStyle(
                          color: Color(0xFF607D8B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFE9D7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Available',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded),
                      color: AppColors.primaryDark,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                NotificationsScreen(userId: widget.user.userId),
                          ),
                        );
                      },
                    ),
                    if (pendingRequests > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3347),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              pendingRequests > 9 ? '9' : '$pendingRequests',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _quickGrid(),
            const SizedBox(height: 18),
            _overviewCard(),
            const SizedBox(height: 16),
            _upcomingCard(upcoming),
          ],
        ),
      ),
    );
  }

  Widget _topActions({required bool showBack}) {
    return Row(
      children: [
        if (showBack)
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => selectedIndex = 0),
          )
        else
          const Spacer(),
        const Spacer(),
        NurseModeControls(providerUserId: widget.user.userId),
      ],
    );
  }

  Widget _quickGrid() {
    final actions = [
      (
        Icons.assignment_outlined,
        'Requests',
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NurseServiceRequests(user: widget.user),
          ),
        ),
        0,
      ),
      (
        Icons.calendar_month_outlined,
        'My Schedule',
        () => setState(() => selectedIndex = 1),
        0,
      ),
      (
        Icons.groups_rounded,
        'Patients',
        () => setState(() => selectedIndex = 2),
        0,
      ),
      (
        Icons.description_outlined,
        'Reports',
        () => setState(() => selectedIndex = 3),
        0,
      ),
      (
        Icons.folder_copy_outlined,
        'Care Plan',
        () => setState(() => selectedIndex = 2),
        0,
      ),
      (
        Icons.chat_bubble_outline_rounded,
        'Messages',
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NurseMessagesScreen(user: widget.user),
          ),
        ).then((_) => _loadDashboard()),
        unreadMessages,
      ),
      (
        Icons.paid_outlined,
        'Earnings',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NursePayments(user: widget.user)),
        ),
        0,
      ),
      (
        Icons.more_horiz_rounded,
        'More',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NurseSettings(user: widget.user)),
        ),
        0,
      ),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];
        return GestureDetector(
          onTap: item.$3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _shadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(item.$1, color: AppColors.primaryDark, size: 23),
                    if (item.$4 > 0)
                      Positioned(
                        right: -10,
                        top: -10,
                        child: UnreadBadge(count: item.$4),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  item.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF607D8B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _overviewCard() {
    return _whiteCard(
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "Today's Overview",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => selectedIndex = 1),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat(Icons.access_time, todaysVisits, 'Total Visits'),
              _miniStat(Icons.calendar_month, pendingRequests, 'Upcoming'),
              _miniStat(Icons.timer, _inProgressCount, 'In Progress'),
              _miniStat(Icons.check_circle, completedVisits, 'Completed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, int value, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF607D8B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _upcomingCard(ServiceRequest? request) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming Visit',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (request == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Text(
                  'No upcoming visits yet',
                  style: TextStyle(
                    color: Color(0xFF78909C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else
            InkWell(
              onTap: () => _openRequest(request),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  SizedBox(
                    width: 62,
                    child: Text(
                      _time(request.scheduledDate),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _avatar(request.patientName, radius: 25),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.patientName.isEmpty
                              ? 'Patient'
                              : request.patientName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          request.serviceType.isEmpty
                              ? 'Home visit'
                              : request.serviceType,
                          style: const TextStyle(
                            color: Color(0xFF607D8B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          request.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(
                    nurseRequestRequiresDecision(request) ? 'New' : 'Today',
                    nurseRequestRequiresDecision(request)
                        ? const Color(0xFFDCEBFF)
                        : const Color(0xFFBFE9D7),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _shadow,
      ),
      child: child,
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
          onChanged: _loadDashboard,
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w900,
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

  ServiceRequest? get _upcomingVisit {
    final upcoming =
        requests
            .where(
              (r) =>
                  nurseRequestIsAccepted(r) || nurseRequestRequiresDecision(r),
            )
            .toList()
          ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  int get _inProgressCount =>
      requests.where((r) => r.status == 'in_progress').length;

  String get _firstName {
    final name = widget.user.fullName.trim();
    if (name.isEmpty) return 'Nurse';
    return name.split(RegExp(r'\s+')).first;
  }

  String _time(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m\n${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<BoxShadow> get _shadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.045),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

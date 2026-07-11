import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/profile_avatar.dart';
import 'package:carelink/features/nurse/models/nurse_dashboard_model.dart';
import 'package:carelink/features/nurse/services/nurse_dashboard_repository.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/provider_profile_service.dart';
import 'package:carelink/shared/widgets/carelink_floating_bottom_nav.dart';

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
  String? nurseProfileImageUrl;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    dashboardController = NurseDashboardController(user: widget.user);
    _loadUiSettings();
    _loadProfileHeader();
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

  Future<void> _loadProfileHeader() async {
    final profile = await ProviderProfileService.getProfile(widget.user.userId);
    if (!mounted || profile == null) return;
    final json = profile.toJson();
    setState(() {
      nurseProfileImageUrl = profileImageUrlFromMap(json);
    });
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
            color: AppColors.primaryDark,
            onRefresh: dashboardController.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
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
        _homeHeader(model, notificationCount: model.notificationCount),
        const SizedBox(height: 16),
        if (!model.canWork) ...[
          _rateGateCard(model),
        ] else ...[
          _quickGrid(model),
          const SizedBox(height: 16),
          _upcomingVisitsSection(model),
          const SizedBox(height: 16),
          _dashboardSummaryCard(model),
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

  Widget _homeHeader(
    NurseDashboardModel? model, {
    required int notificationCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final avatarSize = compact ? 38.0 : 42.0;
        return SizedBox(
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: () => setState(() => selectedIndex = 5),
                customBorder: const CircleBorder(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NurseUi.surface,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.6,
                        ),
                        boxShadow: NurseUi.softShadow,
                      ),
                      child: ClipOval(
                        child: profileAvatarOrPlaceholder(
                          imageUrl: nurseProfileImageUrl,
                          size: avatarSize - 4,
                          placeholderColor: AppColors.primary,
                          placeholderIcon: Icons.person,
                          iconSize: 22,
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      end: 1,
                      bottom: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: NurseUi.background,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _timeGreeting(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NurseUi.heroTitleStyle.copyWith(
                              fontSize: compact ? 16 : 17,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(
                              alpha: NurseUi.isDarkMode.value ? 0.18 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            NurseUi.t('Nurse'),
                            maxLines: 1,
                            style: NurseUi.textStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.primary,
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _todayLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NurseUi.textStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: NurseUi.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NurseModeControls(
                    providerUserId: widget.user.userId,
                    onChanged: () => setState(() {}),
                  ),
                  _notificationButton(notificationCount),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _notificationButton(int count) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            iconSize: 23,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            color: AppColors.primary,
            onPressed: () => setState(() => selectedIndex = 4),
          ),
          if (count > 0)
            Positioned(right: -1, top: -1, child: _smallBadge(count)),
        ],
      ),
    );
  }

  Widget _quickGrid(NurseDashboardModel model) {
    final patientCount = model.allRequests
        .map((r) => r.patientId.trim().isEmpty ? r.patientName : r.patientId)
        .toSet()
        .length;
    final actions = [
      (
        Icons.calendar_month_outlined,
        NurseUi.t('My Schedule'),
        '${model.upcomingVisitsCount} ${NurseUi.t('Today')}',
        () => setState(() => selectedIndex = 1),
      ),
      (
        Icons.assignment_outlined,
        NurseUi.t('Requests'),
        '${model.pendingRequestsCount} ${NurseUi.t('Pending')}',
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
        '$patientCount ${NurseUi.label('Total', 'إجمالي')}',
        () => setState(() => selectedIndex = 2),
      ),
      (
        Icons.insert_chart_outlined,
        NurseUi.t('Reports'),
        '${model.completedVisitsCount} ${NurseUi.t('Completed')}',
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NurseVisitReports(user: widget.user),
          ),
        ),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _quickActionCard(
              icon: actions[i].$1,
              title: actions[i].$2,
              stat: actions[i].$3,
              onTap: actions[i].$4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String stat,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            color: NurseUi.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: NurseUi.border.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: NurseUi.palette.cardShadowColor(
                  NurseUi.isDarkMode.value ? 0.24 : 0.04,
                ),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: NurseUi.isDarkMode.value ? 0.18 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: NurseUi.textStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stat,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: NurseUi.textStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: NurseUi.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upcomingVisitsSection(NurseDashboardModel model) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: NurseUi.palette.upcomingIconGradient,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              NurseUi.t('Upcoming Visits'),
              style: NurseUi.pageTitleStyle.copyWith(fontSize: 18),
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
                style: NurseUi.bodyStyle.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.primary,
                size: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: _modernCardDecoration(radius: 20),
          child: model.upcomingVisits.isEmpty
              ? _emptyUpcomingVisitsCard()
              : Column(
                  children: [
                    for (var i = 0; i < model.upcomingVisits.length; i++) ...[
                      _visitRow(model.upcomingVisits[i]),
                      if (i != model.upcomingVisits.length - 1)
                        Divider(height: 1, color: NurseUi.border),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _emptyUpcomingVisitsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: NurseUi.palette.upcomingIconGradient,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            NurseUi.label('No upcoming visits', '\u0644\u0627 \u062a\u0648\u062c\u062f \u0632\u064a\u0627\u0631\u0627\u062a \u0642\u0627\u062f\u0645\u0629'),
            textAlign: TextAlign.center,
            style: NurseUi.sectionTitleStyle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 3),
          Text(
            NurseUi.label(
              "You're all caught up for today.",
              '\u0623\u0646\u0647\u064a\u062a\u0650 \u0643\u0644 \u0634\u064a\u0621 \u0644\u0647\u0630\u0627 \u0627\u0644\u064a\u0648\u0645.',
            ),
            textAlign: TextAlign.center,
            style: NurseUi.textStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: NurseUi.muted,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => selectedIndex = 1),
            icon: const Icon(Icons.calendar_today_outlined, size: 14),
            label: Text(NurseUi.label('View Schedule', '\u0639\u0631\u0636 \u0627\u0644\u062c\u062f\u0648\u0644')),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: NurseUi.textStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitRow(VisitModel visit) {
    final isPending = visit.status.toLowerCase() == 'pending';
    return InkWell(
      onTap: () => _openRequest(visit.request),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: NurseUi.palette.upcomingIconGradient,
                ),
                shape: BoxShape.circle,
              ),
              child: Text(
                visit.patientInitial,
                style: NurseUi.textStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NurseUi.textStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    visit.serviceType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NurseUi.textStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: NurseUi.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          visit.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NurseUi.textStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: NurseUi.muted,
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
                    Icon(
                      Icons.access_time_rounded,
                      color: AppColors.primaryDark,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      visit.time,
                      style: NurseUi.textStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                _visitStatusBadge(
                  isPending
                      ? NurseUi.label(
                          'Pending',
                          '\u0642\u064a\u062f \u0627\u0644\u0627\u0646\u062a\u0638\u0627\u0631',
                        )
                      : NurseUi.label(
                          'Accepted',
                          '\u0645\u0642\u0628\u0648\u0644',
                        ),
                  isPending
                      ? const Color(0xFFF59E0B).withValues(
                          alpha: NurseUi.isDarkMode.value ? 0.18 : 0.14,
                        )
                      : const Color(0xFF22C55E).withValues(
                          alpha: NurseUi.isDarkMode.value ? 0.18 : 0.14,
                        ),
                  isPending ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: NurseUi.muted.withValues(alpha: 0.7),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardSummaryCard(NurseDashboardModel model) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NurseUi.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: NurseUi.palette.cardShadowColor(
              NurseUi.isDarkMode.value ? 0.24 : 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: NurseUi.isDarkMode.value ? 0.18 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.today_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  NurseUi.label("Today's Schedule", 'جدول اليوم'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NurseUi.sectionTitleStyle.copyWith(fontSize: 15),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => selectedIndex = 1),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: NurseUi.textStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(NurseUi.label('Quick View', 'عرض سريع')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryStat(
                '${model.upcomingVisitsCount}',
                NurseUi.label("Today's appointments", 'مواعيد اليوم'),
              ),
              _summaryDivider(),
              _summaryStat(
                '${model.pendingRequestsCount}',
                NurseUi.label('Pending requests', 'طلبات معلقة'),
              ),
              _summaryDivider(),
              _summaryStat(
                '${model.completedVisitsCount}',
                NurseUi.label('Completed visits', 'زيارات مكتملة'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: NurseUi.textStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: NurseUi.textStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: NurseUi.muted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: NurseUi.border.withValues(alpha: 0.8),
    );
  }

  Widget _loadingDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            _SkeletonBox(width: 50, height: 50, radius: 25),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 150, height: 18, radius: 8),
                  SizedBox(height: 7),
                  _SkeletonBox(width: 112, height: 14, radius: 7),
                  SizedBox(height: 6),
                  _SkeletonBox(width: 130, height: 12, radius: 6),
                ],
              ),
            ),
            SizedBox(width: 10),
            _SkeletonBox(width: 34, height: 34, radius: 17),
            SizedBox(width: 8),
            _SkeletonBox(width: 34, height: 34, radius: 17),
            SizedBox(width: 8),
            _SkeletonBox(width: 34, height: 34, radius: 17),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: const [
            Expanded(child: _SkeletonBox(height: 92, radius: 18)),
            SizedBox(width: 8),
            Expanded(child: _SkeletonBox(height: 92, radius: 18)),
            SizedBox(width: 8),
            Expanded(child: _SkeletonBox(height: 92, radius: 18)),
            SizedBox(width: 8),
            Expanded(child: _SkeletonBox(height: 92, radius: 18)),
          ],
        ),
        const SizedBox(height: 24),
        const _SkeletonBox(width: 210, height: 24, radius: 10),
        const SizedBox(height: 12),
        const _SkeletonBox(height: 180, radius: 18),
        const SizedBox(height: 16),
        const _SkeletonBox(height: 120, radius: 18),
      ],
    );
  }

  Widget _errorDashboard() {
    return Column(
      children: [
        _homeHeader(null, notificationCount: 0),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: NurseUi.textStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
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

  Widget _bottomNav() {
    final items = [
      CarelinkFloatingNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: NurseUi.t('Home'),
      ),
      CarelinkFloatingNavItem(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month_rounded,
        label: NurseUi.t('Sessions'),
      ),
      CarelinkFloatingNavItem(
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: NurseUi.t('Patients'),
      ),
      CarelinkFloatingNavItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        label: NurseUi.t('Earnings'),
      ),
      CarelinkFloatingNavItem(
        icon: Icons.notifications_none_rounded,
        activeIcon: Icons.notifications_rounded,
        label: NurseUi.t('Alerts'),
      ),
      CarelinkFloatingNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: NurseUi.t('Profile'),
      ),
    ];
    return CarelinkFloatingBottomNav(
      items: items,
      currentIndex: selectedIndex,
      onTap: (index) {
        if (selectedIndex == index) return;
        if (!_canOpenTab(index)) {
          _showRateLockedMessage();
          setState(() => selectedIndex = 0);
          return;
        }
        setState(() => selectedIndex = index);
      },
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (NurseUi.isArabic.value) {
      if (hour < 12) {
        return '\u0635\u0628\u0627\u062d \u0627\u0644\u062e\u064a\u0631';
      }
      return '\u0645\u0633\u0627\u0621 \u0627\u0644\u062e\u064a\u0631';
    }
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _todayLabel() {
    final now = DateTime.now();
    if (NurseUi.isArabic.value) {
      const days = [
        '\u0627\u0644\u0627\u062b\u0646\u064a\u0646',
        '\u0627\u0644\u062b\u0644\u0627\u062b\u0627\u0621',
        '\u0627\u0644\u0623\u0631\u0628\u0639\u0627\u0621',
        '\u0627\u0644\u062e\u0645\u064a\u0633',
        '\u0627\u0644\u062c\u0645\u0639\u0629',
        '\u0627\u0644\u0633\u0628\u062a',
        '\u0627\u0644\u0623\u062d\u062f',
      ];
      const months = [
        '\u064a\u0646\u0627\u064a\u0631',
        '\u0641\u0628\u0631\u0627\u064a\u0631',
        '\u0645\u0627\u0631\u0633',
        '\u0623\u0628\u0631\u064a\u0644',
        '\u0645\u0627\u064a\u0648',
        '\u064a\u0648\u0646\u064a\u0648',
        '\u064a\u0648\u0644\u064a\u0648',
        '\u0623\u063a\u0633\u0637\u0633',
        '\u0633\u0628\u062a\u0645\u0628\u0631',
        '\u0623\u0643\u062a\u0648\u0628\u0631',
        '\u0646\u0648\u0641\u0645\u0628\u0631',
        '\u062f\u064a\u0633\u0645\u0628\u0631',
      ];
      return '${days[now.weekday - 1]}\u060c ${now.day} ${months[now.month - 1]}';
    }
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
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

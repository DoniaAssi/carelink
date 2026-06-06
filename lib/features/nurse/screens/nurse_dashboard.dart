import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/notifications/notifications_screen.dart';
import 'nurse_payments.dart';
import 'nurse_availability.dart';
import 'nurse_profile.dart';
import 'nurse_recommendations.dart';
import 'nurse_service_requests.dart';
import 'nurse_settings.dart';
import 'nurse_ui.dart';
import 'nurse_visit_reports.dart';

class NurseDashboard extends StatefulWidget {
  final User user;

  const NurseDashboard({super.key, required this.user});

  @override
  State<NurseDashboard> createState() => _NurseDashboardState();
}

class _NurseDashboardState extends State<NurseDashboard> {
  int selectedIndex = 0;
  int pendingRequests = 0;
  int todaysVisits = 0;
  int waitingReports = 0;
  int completedVisits = 0;
  double weeklyEarnings = 0;

  @override
  void initState() {
    super.initState();
    _loadUiSettings();
    _loadDashboardStats();
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

  Future<void> _loadDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/nurse/dashboard/${widget.user.userId}'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      var week = _parseDouble(data['weeklyEarnings']);
      try {
        final summaryResponse = await http.get(
          Uri.parse(
            '${ApiService.baseUrl}/nurse/payments/${widget.user.userId}/summary',
          ),
        );
        if (summaryResponse.statusCode >= 200 &&
            summaryResponse.statusCode < 300) {
          final summary = jsonDecode(summaryResponse.body) as Map<String, dynamic>;
          week = _parseDouble(summary['thisWeek']);
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        pendingRequests = _parseInt(data['pendingRequests']);
        todaysVisits = _parseInt(data['todaysVisits']);
        waitingReports = _parseInt(data['waitingReports']);
        completedVisits = _parseInt(data['completedVisits']);
        weeklyEarnings = week;
      });
    } catch (_) {}
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(userId: widget.user.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive((context) => Scaffold(
      backgroundColor: NurseUi.background,
      appBar: AppBar(
        title: Text(NurseUi.label('Care Link - Nurse', 'كير لينك - ممرضة')),
        backgroundColor: NurseUi.background,
        foregroundColor: NurseUi.text,
        elevation: 0,
        actions: [
          NurseModeControls(providerUserId: widget.user.userId),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: _openNotifications,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: NurseUi.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              label: NurseUi.label('Dashboard', 'الرئيسية'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.assignment_rounded),
              label: NurseUi.label('Services', 'الخدمات'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.edit_note_rounded),
              label: NurseUi.label('Reports', 'التقارير'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.payments_rounded),
              label: NurseUi.label('Payments', 'الدفع'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.notifications_rounded),
              label: NurseUi.label('Notifications', 'الإشعارات'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_rounded),
              label: NurseUi.label('Settings', 'الإعدادات'),
            ),
          ],
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() => selectedIndex = index);
            if (index == 0) _loadDashboardStats();
          },
          selectedItemColor: AppColors.primaryDark,
          unselectedItemColor: NurseUi.muted,
          backgroundColor: NurseUi.surface,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    ));
  }

  Widget _buildBody() {
    switch (selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return NurseServiceRequests(user: widget.user);
      case 2:
        return NurseVisitReports(user: widget.user);
      case 3:
        return NursePayments(user: widget.user);
      case 4:
        return NotificationsScreen(userId: widget.user.userId);
      case 5:
        return NurseSettings(user: widget.user);
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                  color: AppColors.primary.withOpacity(0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        NurseUi.label(
                          'Welcome, ${widget.user.fullName}',
                          'أهلًا، ${widget.user.fullName}',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        NurseUi.label(
                          'Manage requests, visits, reports, and payments in one place.',
                          'تابعي الطلبات والزيارات والتقارير والدفع من مكان واحد.',
                        ),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            NurseUi.label('Quick Overview', 'نظرة سريعة'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: NurseUi.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  NurseUi.label('Pending Requests', 'طلبات معلقة'),
                  '$pendingRequests',
                  Icons.pending_actions_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  NurseUi.label('Today Visits', 'زيارات اليوم'),
                  '$todaysVisits',
                  Icons.calendar_month_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  NurseUi.label('Completed', 'مكتملة'),
                  '$completedVisits',
                  Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  NurseUi.label('This Week', '\u0647\u0630\u0627 \u0627\u0644\u0623\u0633\u0628\u0648\u0639'),
                  '\$${weeklyEarnings.toStringAsFixed(0)}',
                  Icons.payments_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  NurseUi.label('Waiting Reports', 'تقارير مطلوبة'),
                  '$waitingReports',
                  Icons.assignment_late_rounded,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            NurseUi.label('Quick Actions', 'إجراءات سريعة'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: NurseUi.text,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActionCard(
            icon: Icons.person_outline_rounded,
            title: NurseUi.label('Profile', 'الملف المهني'),
            subtitle: NurseUi.label(
              'Update your professional profile',
              'تحديث بياناتك المهنية',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NurseProfile(user: widget.user),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildQuickActionCard(
            icon: Icons.assignment_rounded,
            title: NurseUi.label('My Assigned Services', 'الخدمات المعيّنة'),
            subtitle: NurseUi.label(
              'Accept requests, start visits, and submit reports',
              'قبول الطلبات وبدء الزيارات وإرسال التقارير',
            ),
            onTap: () => setState(() => selectedIndex = 1),
          ),
          const SizedBox(height: 10),
          _buildQuickActionCard(
            icon: Icons.edit_note_rounded,
            title: NurseUi.label('Submit Report', 'إرسال تقرير'),
            subtitle: NurseUi.label(
              'Document completed visits',
              'توثيق الزيارات المكتملة',
            ),
            onTap: () => setState(() => selectedIndex = 2),
          ),
          const SizedBox(height: 10),
          _buildQuickActionCard(
            icon: Icons.payments_rounded,
            title: NurseUi.label('Payment History', 'سجل الدفع'),
            subtitle: NurseUi.label(
              'View earnings and payments',
              'عرض الأرباح والمدفوعات',
            ),
            onTap: () => setState(() => selectedIndex = 3),
          ),
          const SizedBox(height: 10),
          _buildQuickActionCard(
            icon: Icons.schedule_rounded,
            title: NurseUi.label('Availability', 'أوقات الفراغ'),
            subtitle: NurseUi.label(
              'Set the time you are free',
              'حددي الوقت الذي تكونين فيه متاحة',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NurseAvailability(user: widget.user),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildQuickActionCard(
            icon: Icons.settings_rounded,
            title: NurseUi.label('Settings', 'الإعدادات'),
            subtitle: NurseUi.label(
              'Manage profile and preferences',
              'إدارة الملف والتفضيلات',
            ),
            onTap: () => setState(() => selectedIndex = 4),
          ),
          const SizedBox(height: 10),
          _buildQuickActionCard(
            icon: Icons.auto_awesome_rounded,
            title: NurseUi.label('Recommendations', 'التوصيات'),
            subtitle: NurseUi.label(
              'Review nearby patient matches',
              'مراجعة المرضى القريبين المناسبين',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NurseRecommendations(user: widget.user),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: NurseUi.muted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NurseUi.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: NurseUi.border.withOpacity(0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: NurseUi.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: NurseUi.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.primaryDark,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

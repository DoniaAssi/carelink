import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/patient/screens/patient_home_screen.dart';
import 'package:carelink/features/patient/screens/schedule_screen.dart';
import 'package:carelink/features/patient/screens/patient_care_hub_screen.dart';
import 'package:carelink/features/patient/screens/medical_records_screen.dart';
import 'package:carelink/features/patient/screens/profile_screen.dart';

class PatientNavigationShell extends StatefulWidget {
  final String userId;
  final String? displayName;
  final int initialTab;

  const PatientNavigationShell({
    super.key,
    this.userId = '',
    this.displayName,
    int initialTab = 0,
    int? initialIndex,
  }) : initialTab = initialIndex ?? initialTab;

  static void switchTab(BuildContext context, int index) {
    final state = context
        .findAncestorStateOfType<_PatientNavigationShellState>();
    if (state != null) {
      state.setTabIndex(index);
    }
  }

  @override
  State<PatientNavigationShell> createState() => _PatientNavigationShellState();
}

class _PatientNavigationShellState extends State<PatientNavigationShell> {
  late int currentIndex;
  late String currentUserId;
  String? currentDisplayName;
  bool isRestoringSession = false;

  void setTabIndex(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialTab;
    currentUserId = widget.userId;
    currentDisplayName = widget.displayName;

    if (currentUserId.isEmpty) {
      _restoreSession();
    }
  }

  Future<void> _restoreSession() async {
    setState(() => isRestoringSession = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('session_user_id') ?? '';
      final savedName = prefs.getString('session_display_name');
      if (savedId.isEmpty) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
        return;
      }
      setState(() {
        currentUserId = savedId;
        currentDisplayName = savedName;
        isRestoringSession = false;
      });
    } catch (_) {
      setState(() => isRestoringSession = false);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  bool get _isArabic => localeController.isArabic;

  String _t(String en, String ar) {
    return _isArabic ? ar : en;
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    if (isRestoringSession) {
      return Scaffold(
        backgroundColor: p.pageBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> screens = [
      PatientHomeScreen(userId: currentUserId, displayName: currentDisplayName),
      ScheduleScreen(patientUserId: currentUserId),
      PatientCareHubScreen(patientUserId: currentUserId),
      MedicalRecordsScreen(patientId: currentUserId),
      ProfileScreen(userId: currentUserId),
    ];

    return ListenableBuilder(
      listenable: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        return Directionality(
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: PopScope(
            canPop: currentIndex == 0,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (currentIndex != 0) {
                setState(() {
                  currentIndex = 0;
                });
              }
            },
            child: Scaffold(
              backgroundColor: p.pageBg,
              body: IndexedStack(index: currentIndex, children: screens),
              bottomNavigationBar: _buildFloatingBottomNav(p),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingBottomNav(CarelinkPalette p) {
    return Material(
      elevation: 18,
      shadowColor: Colors.black12,
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        decoration: BoxDecoration(
          color: p.navBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            selectedItemColor: AppColors.primary,
            unselectedItemColor: p.navUnselected,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_rounded, size: 23),
                activeIcon: const Icon(
                  Icons.home_rounded,
                  size: 23,
                  color: AppColors.primary,
                ),
                label: _t('Home', 'الرئيسية'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month_rounded, size: 23),
                activeIcon: const Icon(
                  Icons.calendar_month_rounded,
                  size: 23,
                  color: AppColors.primary,
                ),
                label: _t('Bookings', 'حجوزاتي'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.favorite_border_rounded, size: 23),
                activeIcon: const Icon(
                  Icons.favorite_rounded,
                  size: 23,
                  color: AppColors.primary,
                ),
                label: _t('My care', 'رعايتي'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.folder_outlined, size: 23),
                activeIcon: const Icon(
                  Icons.folder_rounded,
                  size: 23,
                  color: AppColors.primary,
                ),
                label: _t('Records', 'السجل الطبي'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline_rounded, size: 23),
                activeIcon: const Icon(
                  Icons.person_rounded,
                  size: 23,
                  color: AppColors.primary,
                ),
                label: _t('Profile', 'الملف الشخصي'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

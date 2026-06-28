import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';
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
      return PatientScaffold(
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
            child: PatientScaffold(
              extendBody: true,
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
    final items = [
      _PatientNavItem(
        icon: Icons.home_rounded,
        activeIcon: Icons.home_rounded,
        label: _t('Home', 'الرئيسية'),
      ),
      _PatientNavItem(
        icon: Icons.calendar_month_rounded,
        activeIcon: Icons.calendar_month_rounded,
        label: _t('Bookings', 'حجوزاتي'),
      ),
      _PatientNavItem(
        icon: Icons.favorite_border_rounded,
        activeIcon: Icons.favorite_rounded,
        label: _t('My care', 'رعايتي'),
      ),
      _PatientNavItem(
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder_rounded,
        label: _t('Records', 'السجل الطبي'),
      ),
      _PatientNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: _t('Profile', 'الملف الشخصي'),
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: p.isDark ? p.navBackground : Colors.white,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = items.length;
            final itemWidth = constraints.maxWidth / count;
            final visualIndex = _isArabic
                ? count - 1 - currentIndex
                : currentIndex;
            
            // Smaller pill width for elegance
            final pillWidth = itemWidth * 0.75;
            final pillHeight = 48.0;
            final leftOffset = (visualIndex * itemWidth) + ((itemWidth - pillWidth) / 2);

            return Stack(
              alignment: Alignment.center,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: leftOffset,
                  top: (68 - pillHeight) / 2,
                  width: pillWidth,
                  height: pillHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(
                        alpha: p.isDark ? 0.15 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final selected = index == currentIndex;
                    return Expanded(
                      child: _PatientFloatingNavButton(
                        item: item,
                        selected: selected,
                        palette: p,
                        onTap: () {
                          if (currentIndex == index) return;
                          setState(() => currentIndex = index);
                        },
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PatientNavItem {
  const _PatientNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _PatientFloatingNavButton extends StatefulWidget {
  const _PatientFloatingNavButton({
    required this.item,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final _PatientNavItem item;
  final bool selected;
  final CarelinkPalette palette;
  final VoidCallback onTap;

  @override
  State<_PatientFloatingNavButton> createState() =>
      _PatientFloatingNavButtonState();
}

class _PatientFloatingNavButtonState extends State<_PatientFloatingNavButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? const Color(0xFF0F766E)
        : widget.palette.isDark
        ? widget.palette.navUnselected
        : const Color(0xFF94A3B8);
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : (widget.selected ? 1.04 : 1),
        duration: const Duration(milliseconds: 190),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: AppColors.primary.withValues(alpha: 0.10),
          highlightColor: AppColors.primary.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Icon(
                    widget.selected ? widget.item.activeIcon : widget.item.icon,
                    key: ValueKey('${widget.item.label}-${widget.selected}'),
                    size: widget.selected ? 25 : 22,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: color,
                    fontSize: widget.selected ? 11.5 : 10.5,
                    fontWeight: widget.selected
                        ? FontWeight.w900
                        : FontWeight.w600,
                  ),
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

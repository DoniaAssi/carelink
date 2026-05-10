import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/patient_typography.dart';
import 'package:carelink/core/profile_avatar.dart';

/// Which tab is active in the shared patient 4-slot bottom bar.
enum PatientShellTab { home, care, chat, profile }

/// Shared layout tokens for all patient footers.
abstract final class PatientFooterSpecs {
  static const double floatingNavRadius = 24;
  static const EdgeInsets floatingNavMargin = EdgeInsets.fromLTRB(
    14,
    0,
    14,
    14,
  );
  static const double navIconSize = 24;
}

/// Floating pill wrapper used for the main 4-tab bar (matches patient home).
class PatientFloatingNavShell extends StatelessWidget {
  const PatientFloatingNavShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Material(
      elevation: 10,
      shadowColor: Colors.black26,
      color: Colors.transparent,
      child: Container(
        margin: PatientFooterSpecs.floatingNavMargin,
        decoration: BoxDecoration(
          color: p.navBackground,
          borderRadius: BorderRadius.circular(
            PatientFooterSpecs.floatingNavRadius,
          ),
          border: Border.all(color: p.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.isDark ? 0.28 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Same 4-tab floating footer on Home, My care, Chat, Medical record hub, Profile.
class PatientMainBottomNav extends StatelessWidget {
  const PatientMainBottomNav({
    super.key,
    required this.selected,
    required this.profileImageUrl,
    required this.onHome,
    required this.onCare,
    required this.onChat,
    required this.onProfile,
  });

  final PatientShellTab selected;
  final String? profileImageUrl;
  final VoidCallback onHome;
  final VoidCallback onCare;
  final VoidCallback onChat;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return PatientFloatingNavShell(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              PatientNavTab(
                dense: true,
                iconSize: 20,
                icon: Icons.home_outlined,
                label: context.tr('patient.navHome'),
                selected: selected == PatientShellTab.home,
                showUnderline: selected == PatientShellTab.home,
                onTap: selected == PatientShellTab.home ? null : onHome,
              ),
              PatientNavTab(
                dense: true,
                iconSize: 20,
                icon: Icons.healing_outlined,
                label: context.tr('patient.navCare'),
                selected: selected == PatientShellTab.care,
                showUnderline: selected == PatientShellTab.care,
                onTap: selected == PatientShellTab.care ? null : onCare,
              ),
              PatientNavTab(
                dense: true,
                iconSize: 20,
                icon: Icons.chat_bubble_outline_rounded,
                label: context.tr('patient.navChat'),
                selected: selected == PatientShellTab.chat,
                showUnderline: selected == PatientShellTab.chat,
                onTap: selected == PatientShellTab.chat ? null : onChat,
              ),
              PatientNavProfileTab(
                dense: true,
                avatarSize: 28,
                imageUrl: profileImageUrl,
                label: context.tr('patient.navProfile'),
                selected: selected == PatientShellTab.profile,
                onTap: selected == PatientShellTab.profile ? null : onProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One slot in a custom [Row] bottom nav (Messages, Medical records, etc.).
class PatientNavTab extends StatelessWidget {
  const PatientNavTab({
    super.key,
    this.icon,
    this.iconWidget,
    required this.label,
    required this.selected,
    this.onTap,
    this.showUnderline = false,
    this.iconSize = PatientFooterSpecs.navIconSize,
    this.dense = false,
  }) : assert(icon != null || iconWidget != null, 'Provide icon or iconWidget');

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool showUnderline;
  final double iconSize;

  /// Tighter icons/labels (~56–60dp bar feel) for compact shells (e.g. My care hub).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final primary = AppColors.primary;
    final baseColor = selected ? primary : p.navUnselected;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 10,
          vertical: dense ? 4 : 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget ?? Icon(icon!, color: baseColor, size: iconSize),
            SizedBox(height: dense ? 4 : 6),
            Text(
              label,
              style: context.patientTx.overline.copyWith(
                fontSize: dense ? 10 : null,
                height: dense ? 1.05 : null,
                color: baseColor,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (showUnderline) ...[
              SizedBox(height: dense ? 3 : 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? (dense ? 22 : 26) : 0,
                height: dense ? 2.5 : 3,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Profile tab with circular avatar (same metrics as other slots).
class PatientNavProfileTab extends StatelessWidget {
  const PatientNavProfileTab({
    super.key,
    required this.imageUrl,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.avatarSize = 34,
    this.dense = false,
  });

  final String? imageUrl;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final double avatarSize;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final primary = AppColors.primary;
    final color = selected ? primary : p.navUnselected;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 10,
          vertical: dense ? 4 : 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.surfaceSoft,
                border: Border.all(color: p.stroke),
              ),
              child: ClipOval(
                child: profileAvatarOrPlaceholder(
                  imageUrl: imageUrl,
                  size: avatarSize,
                  placeholderColor: AppColors.primary,
                  placeholderIcon: Icons.person_rounded,
                  iconSize: avatarSize * 0.52,
                ),
              ),
            ),
            SizedBox(height: dense ? 4 : 6),
            Text(
              label,
              style: context.patientTx.overline.copyWith(
                fontSize: dense ? 10 : null,
                height: dense ? 1.05 : null,
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky footer — matches [CarelinkTrustFooterBar] / intro row: surface strip + hairline only.
class PatientFlowActionBar extends StatelessWidget {
  const PatientFlowActionBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final footerSurface = Theme.of(context).brightness == Brightness.dark
        ? p.navBackground
        : p.surface;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: footerSurface,
          border: Border(top: BorderSide(color: p.stroke)),
        ),
        child: child,
      ),
    );
  }
}

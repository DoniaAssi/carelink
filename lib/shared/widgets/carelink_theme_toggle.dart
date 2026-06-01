import 'package:flutter/material.dart';

import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';

/// Toggles [localeController] ([en] <-> [ar]). The global overlay pins this on every route.
class CarelinkLocaleIconButton extends StatelessWidget {
  const CarelinkLocaleIconButton({
    super.key,
    this.color,
    this.tooltip,
    this.omitTooltip = false,
  });

  final Color? color;
  final String? tooltip;
  final bool omitTooltip;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, child) {
        final arabic = localeController.isArabic;
        final tip = tooltip ?? (arabic ? 'English' : 'Arabic');
        final button = IconButton(
          onPressed: () => localeController.toggle(),
          icon: Icon(Icons.language_rounded, color: color),
          iconSize: 23,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          padding: EdgeInsets.zero,
          tooltip: omitTooltip ? null : tip,
        );
        if (omitTooltip) {
          return Semantics(button: true, label: tip, child: button);
        }
        return button;
      },
    );
  }
}

Widget carelinkLocaleThemeChipRow({
  Key? rowKey,
  Color? iconColor,
  double gap = 6,
}) {
  return Row(
    key: rowKey,
    mainAxisSize: MainAxisSize.min,
    children: [
      CarelinkLocaleIconButton(color: iconColor),
      SizedBox(width: gap),
      CarelinkThemeIconButton(color: iconColor),
    ],
  );
}

class PatientHeaderActions extends StatelessWidget {
  const PatientHeaderActions({
    super.key,
    this.showLanguage = true,
    this.showTheme = true,
    this.color,
  });

  final bool showLanguage;
  final bool showTheme;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLanguage)
          CarelinkLocaleIconButton(color: color),
        if (showTheme)
          CarelinkThemeIconButton(color: color),
      ],
    );
  }
}

class PatientTopActions extends StatelessWidget implements PreferredSizeWidget {
  const PatientTopActions({
    super.key,
    this.showBack = false,
    this.showNotification = false,
    this.showAiRobot = false,
    this.showLanguage = true,
    this.showTheme = true,
    this.onBack,
  });

  final bool showBack;
  final bool showNotification;
  final bool showAiRobot;
  final bool showLanguage;
  final bool showTheme;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final ar = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Back button (if enabled)
          if (showBack)
            IconButton(
              icon: Icon(
                ar ? Icons.arrow_forward : Icons.arrow_back,
                color: primaryColor,
              ),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          else
            const SizedBox(width: 48),
          
          // Right side: Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showNotification)
                IconButton(
                  icon: Icon(Icons.notifications_outlined, color: primaryColor),
                  onPressed: () {
                    // Triggers notifications or profile page
                  },
                ),
              if (showAiRobot)
                IconButton(
                  icon: Icon(Icons.smart_toy_outlined, color: primaryColor),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/find-provider',
                    );
                  },
                ),
              if (showLanguage)
                CarelinkLocaleIconButton(color: primaryColor),
              if (showTheme)
                CarelinkThemeIconButton(color: primaryColor),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}

Widget carelinkGlobalLocaleOverlay(BuildContext context) {
  return const SizedBox.shrink();
}

class CarelinkThemeIconButton extends StatelessWidget {
  const CarelinkThemeIconButton({
    super.key,
    this.color,
    this.omitTooltip = false,
  });

  final Color? color;
  final bool omitTooltip;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, child) {
        final isDark = themeController.isDark;
        final tip = isDark ? 'Light mode' : 'Dark mode';
        final button = IconButton(
          onPressed: () => themeController.toggle(),
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: color,
          ),
          iconSize: 23,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          padding: EdgeInsets.zero,
          tooltip: omitTooltip ? null : tip,
        );
        if (omitTooltip) {
          return Semantics(button: true, label: tip, child: button);
        }
        return button;
      },
    );
  }
}

List<Widget> carelinkAppBarActions([List<Widget>? other]) {
  return [
    if (other != null) ...other,
    const CarelinkLocaleIconButton(),
    const CarelinkThemeIconButton(),
  ];
}

import 'package:flutter/material.dart';

import 'package:carelink/core/app_localizations.dart';
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
        final l10n = CarelinkL10n(localeController.locale);
        final tip = tooltip ??
            (arabic
                ? l10n.t('language.switchToEnglish')
                : l10n.t('language.switchToArabic'));
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

Widget carelinkGlobalLocaleOverlay(BuildContext context) {
  final isDark = themeController.isDark;
  final background = isDark ? const Color(0xFF263238) : const Color(0xFFFFFFFF);
  final foreground = isDark ? const Color(0xFFF5FBFC) : const Color(0xFF1F2933);
  return SafeArea(
    child: Align(
      alignment: AlignmentDirectional.topEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 10, top: 2),
        child: Material(
          elevation: 3,
          shadowColor: Colors.black45,
          borderRadius: BorderRadius.circular(999),
          color: background.withValues(alpha: 0.94),
          clipBehavior: Clip.antiAlias,
          child: IconTheme(
            data: IconThemeData(color: foreground, size: 24),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CarelinkLocaleIconButton(omitTooltip: true),
                SizedBox(width: 2),
                CarelinkThemeIconButton(omitTooltip: true),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
      listenable: Listenable.merge([themeController, localeController]),
      builder: (context, child) {
        final isDark = themeController.isDark;
        final l10n = CarelinkL10n(localeController.locale);
        final tip = l10n.t(isDark ? 'theme.light' : 'theme.dark');
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

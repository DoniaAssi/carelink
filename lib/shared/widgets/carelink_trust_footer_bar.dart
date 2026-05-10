import 'package:flutter/material.dart';

import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/intro_tokens.dart';

/// Three-column footer from [IntroScreen] — unified brand strip for onboarding / checkout.
class CarelinkTrustFooterBar extends StatelessWidget {
  const CarelinkTrustFooterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final footerBg =
        isDark ? p.navBackground : p.surface;
    final text = p.inkDark;
    final muted = p.inkMuted;
    final stroke = p.stroke;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: footerBg,
        border: Border(top: BorderSide(color: stroke)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CarelinkTrustFooterItem(
                leading: const _ShieldLockIcon(),
                title: context.tr('intro.securePrivate'),
                subtitle: context.tr('intro.securePrivateSubtitle'),
                textColor: text,
                mutedColor: muted,
              ),
            ),
            _BarDivider(color: stroke),
            Expanded(
              child: CarelinkTrustFooterItem(
                icon: Icons.bolt_outlined,
                title: context.tr('intro.aiPowered'),
                subtitle: context.tr('intro.aiPoweredSubtitle'),
                textColor: text,
                mutedColor: muted,
              ),
            ),
            _BarDivider(color: stroke),
            Expanded(
              child: CarelinkTrustFooterItem(
                icon: Icons.public_outlined,
                title: context.tr('intro.anywhereAccess'),
                subtitle: context.tr('intro.anywhereAccessSubtitle'),
                textColor: text,
                mutedColor: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal for tests / reuse outside the triple strip.
class CarelinkTrustFooterItem extends StatelessWidget {
  const CarelinkTrustFooterItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.mutedColor,
    this.icon,
    this.leading,
  }) : assert((icon == null) != (leading == null));

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Center(
              child: leading ?? Icon(icon!, size: 23, color: textColor),
            ),
          ),
          SizedBox(width: isArabic ? 6 : 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: IntroTokens.t(
                    size: isArabic ? 10 : 11,
                    weight: FontWeight.w700,
                    color: textColor,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: IntroTokens.t(
                    size: isArabic ? 7.8 : 8.5,
                    weight: FontWeight.w300,
                    color: mutedColor,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarDivider extends StatelessWidget {
  const _BarDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(width: 1, thickness: 1, color: color);
  }
}

class _ShieldLockIcon extends StatelessWidget {
  const _ShieldLockIcon();

  @override
  Widget build(BuildContext context) {
    final c = CarelinkPalette.of(context).inkDark;
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 26, color: c),
          Icon(Icons.lock_outline_rounded, size: 11, color: c),
        ],
      ),
    );
  }
}

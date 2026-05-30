import 'package:flutter/material.dart';

import 'package:carelink/core/carelink_palette.dart';

/// Brand logos: [carelink_logo_light] (وضع فاتح) و [carelink_logo_dark] (وضع داكن).
class CarelinkBrandLogo extends StatelessWidget {
  const CarelinkBrandLogo({
    super.key,
    this.height = 36,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.fallbackTextColor,
    this.forceDarkLogo = false,
  });

  final double height;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  /// لون أيقونة/نص الاحتياط عند فشل التحميل (مثلاً أبيض فوق ترويسة تركواز).
  final Color? fallbackTextColor;
  final bool forceDarkLogo;

  @override
  Widget build(BuildContext context) {
    final isDark =
        forceDarkLogo || Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? 'assets/images/carelink_logo_dark.png'
        : 'assets/images/carelink_logo_light.png';
    final fallback =
        fallbackTextColor ?? Theme.of(context).colorScheme.onSurface;

    return Image.asset(
      primary,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/images/carelink_logo.png',
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_rounded,
              color: fallback,
              size: (height * 0.75).clamp(20.0, 40.0),
            ),
            const SizedBox(width: 6),
            Text(
              'CareLink',
              style: TextStyle(
                color: fallback,
                fontSize: (height * 0.55).clamp(14.0, 22.0),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// عنوان AppBar: شعار + نص (نفس الثيم لكل الصفحات).
class CarelinkAppBarTitle extends StatelessWidget {
  const CarelinkAppBarTitle(
    this.title, {
    super.key,
    this.logoHeight = 24,
    this.forceDarkLogo = false,
    this.titleColor,
    this.logoFallbackColor,
  });

  final String title;
  final double logoHeight;
  final bool forceDarkLogo;
  final Color? titleColor;
  final Color? logoFallbackColor;

  factory CarelinkAppBarTitle.forPatient(
    BuildContext context,
    String title, {
    double logoHeight = 24,
  }) {
    final p = CarelinkPalette.of(context);
    return CarelinkAppBarTitle(
      title,
      logoHeight: logoHeight,
      titleColor: p.inkDark,
      logoFallbackColor: p.inkDark,
      forceDarkLogo: p.isDark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseTitle =
        theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
    final defaultFg =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final fg = titleColor ?? defaultFg;
    final style = (baseTitle ?? const TextStyle()).copyWith(color: fg);
    final logoFb = logoFallbackColor ?? fg;
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        CarelinkBrandLogo(
          height: logoHeight,
          fallbackTextColor: logoFb,
          forceDarkLogo: forceDarkLogo,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// عنوان بسطر رئيسي + وصف (مثلاً اختيار الموقع، مراجعة الحجز).
class CarelinkAppBarTitleWithSubtitle extends StatelessWidget {
  const CarelinkAppBarTitleWithSubtitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.logoHeight = 30,
    this.forceDarkLogo = false,
    this.titleColor,
    this.subtitleColor,
    this.logoFallbackColor,
  });

  final String title;
  final String subtitle;
  final double logoHeight;
  final bool forceDarkLogo;
  final Color? titleColor;
  final Color? subtitleColor;
  final Color? logoFallbackColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final defaultFg = t.appBarTheme.foregroundColor ?? t.colorScheme.onSurface;
    final fg = titleColor ?? defaultFg;
    final subFg = subtitleColor ?? fg.withValues(alpha: 0.72);
    final baseTitle = t.appBarTheme.titleTextStyle;
    final logoFb = logoFallbackColor ?? fg;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CarelinkBrandLogo(
          height: logoHeight,
          fallbackTextColor: logoFb,
          forceDarkLogo: forceDarkLogo,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: baseTitle?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: baseTitle?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: subFg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

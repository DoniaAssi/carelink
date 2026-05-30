import 'package:flutter/material.dart';

import 'package:carelink/core/carelink_palette.dart';

/// Brand page surfaces matching [IntroScreen]: soft vertical gradient over [CarelinkPalette].
abstract final class CarelinkBrandSurfaces {
  static const List<double> pageGradientStops = [0.0, 0.28, 0.62, 1.0];

  static List<Color> pageGradientColors(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        p.pageBg,
        p.headerDeep,
        p.headerSoft.withValues(alpha: 0.72),
        p.pageBg,
      ];
    }
    return [p.pageBg, p.surface, p.surfaceSoft, p.pageBg];
  }
}

/// Full-screen intro-style gradient (stack under content / backdrop).
class CarelinkBrandPageGradient extends StatelessWidget {
  const CarelinkBrandPageGradient({
    super.key,
    required this.child,
    this.expandChild = false,
  });

  final Widget child;

  /// When true, paints behind full screen (use under [Stack] / [Expanded] roots).
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: CarelinkBrandSurfaces.pageGradientColors(context),
          stops: CarelinkBrandSurfaces.pageGradientStops,
        ),
      ),
      child: child,
    );
    if (!expandChild) return box;
    return SizedBox.expand(child: box);
  }
}

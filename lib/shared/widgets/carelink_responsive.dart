import 'package:flutter/material.dart';

/// Applies a conservative typography scale on narrow CareLink mobile layouts.
///
/// The app still respects the platform text-size preference, while very narrow
/// screens receive a small reduction so translated labels do not collide with
/// adjacent controls.
class CarelinkResponsiveScope extends StatelessWidget {
  const CarelinkResponsiveScope({super.key, required this.child});

  final Widget child;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= 320) return 12;
    if (width < 400) return 16;
    return 20;
  }

  @override
  Widget build(BuildContext context) {
    if (_CarelinkResponsiveMarker.maybeOf(context)) return child;
    final mediaQuery = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : mediaQuery.size.width;
        final narrowScreenScale = width <= 320
            ? 0.88
            : width < 360
            ? 0.93
            : width < 400
            ? 0.97
            : 1.0;
        final preferredScale = mediaQuery.textScaler.scale(1);
        final effectiveScale = (preferredScale * narrowScreenScale).clamp(
          0.82,
          1.18,
        );

        return _CarelinkResponsiveMarker(
          child: MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(effectiveScale),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _CarelinkResponsiveMarker extends InheritedWidget {
  const _CarelinkResponsiveMarker({required super.child});

  static bool maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CarelinkResponsiveMarker>() !=
      null;

  @override
  bool updateShouldNotify(_CarelinkResponsiveMarker oldWidget) => false;
}

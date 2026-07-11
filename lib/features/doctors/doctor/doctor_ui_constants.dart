import 'package:flutter/material.dart';

class DoctorUiConstants {
  const DoctorUiConstants._();

  static const Color doctorBackground = Color(0xFFEFF7EF);
}

class DoctorTypographyScope extends StatelessWidget {
  const DoctorTypographyScope({super.key, required this.child});

  final Widget child;

  static const double _phoneScale = 0.88;

  @override
  Widget build(BuildContext context) {
    if (_DoctorTypographyMarker.maybeOf(context)) return child;

    final mediaQuery = MediaQuery.of(context);
    final preferredScale = mediaQuery.textScaler.scale(1);
    final effectiveScale = (preferredScale * _phoneScale).clamp(0.82, 1.08);

    return _DoctorTypographyMarker(
      child: MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: TextScaler.linear(effectiveScale),
        ),
        child: child,
      ),
    );
  }
}

class _DoctorTypographyMarker extends InheritedWidget {
  const _DoctorTypographyMarker({required super.child});

  static bool maybeOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_DoctorTypographyMarker>() !=
        null;
  }

  @override
  bool updateShouldNotify(_DoctorTypographyMarker oldWidget) => false;
}

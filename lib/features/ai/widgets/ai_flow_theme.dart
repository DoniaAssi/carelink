import 'package:flutter/material.dart';

/// Accent palette for the graduation “AI recommendation + medical record” flow
/// (white surfaces, blue actions — as in the reference mock video).
abstract final class AiFlowTheme {
  static const Color primaryBlue = Color(0xFF06958E);
  static const Color primaryBlueDark = Color(0xFF05736F);
  static const Color cardStroke = Color(0xFFE3EEF0);
  static const Color softTeal = Color(0xFFE8F7F6);

  static Color pageBackground(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color text(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color mutedText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color stroke(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color softAccent(BuildContext context) => primaryBlue.withValues(
    alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.10,
  );
}

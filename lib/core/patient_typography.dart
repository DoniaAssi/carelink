import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:carelink/core/app_colors.dart';

/// Unified Inter scale for all patient flows (light/dark via [ThemeExtension]).
@immutable
class PatientTypographyTokens extends ThemeExtension<PatientTypographyTokens> {
  const PatientTypographyTokens({
    required this.display,
    required this.headline,
    required this.section,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.bodySmall,
    required this.caption,
    required this.overline,
    required this.brand,
    required this.label,
    required this.listPrimary,
  });

  /// Large hero / feature titles (e.g. home greeting block).
  final TextStyle display;

  /// Screen title, major headings (replaces 20–22pt ad‑hoc).
  final TextStyle headline;

  /// Section headers (“Documented visits”, panels).
  final TextStyle section;

  /// Card titles, prominent row labels.
  final TextStyle title;

  /// Secondary line under a title (muted).
  final TextStyle subtitle;

  /// Main paragraph and form descriptions.
  final TextStyle body;

  /// Supporting lines, list secondary text.
  final TextStyle bodySmall;

  /// Meta, timestamps, helper lines.
  final TextStyle caption;

  /// Fine print, tab hints.
  final TextStyle overline;

  /// Teal emphasis (visit type, links).
  final TextStyle brand;

  /// Chip / badge / compact label.
  final TextStyle label;

  /// List item primary (name line).
  final TextStyle listPrimary;

  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    required Color color,
    double height = 1.4,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static const Color _inkLight = AppColors.textDark;
  static const Color _mutedLight = Color(0xFF5C6C73);
  static const Color _inkDark = Color(0xFFF5FBFC);
  static const Color _mutedDark = Color(0xFF8FA7AE);

  factory PatientTypographyTokens.light() {
    return PatientTypographyTokens(
      display: _inter(
        size: 22,
        weight: FontWeight.w800,
        color: _inkLight,
        height: 1.12,
        letterSpacing: -0.4,
      ),
      headline: _inter(
        size: 20,
        weight: FontWeight.w800,
        color: _inkLight,
        height: 1.2,
        letterSpacing: -0.35,
      ),
      section: _inter(
        size: 18,
        weight: FontWeight.w800,
        color: _inkLight,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      title: _inter(
        size: 17,
        weight: FontWeight.w700,
        color: _inkLight,
        height: 1.22,
        letterSpacing: -0.25,
      ),
      subtitle: _inter(
        size: 15,
        weight: FontWeight.w400,
        color: _mutedLight,
        height: 1.5,
      ),
      body: _inter(
        size: 15,
        weight: FontWeight.w400,
        color: _inkLight,
        height: 1.5,
      ),
      bodySmall: _inter(
        size: 13,
        weight: FontWeight.w500,
        color: _inkLight,
        height: 1.4,
      ),
      caption: _inter(
        size: 12,
        weight: FontWeight.w500,
        color: _mutedLight,
        height: 1.35,
      ),
      overline: _inter(
        size: 10.5,
        weight: FontWeight.w600,
        color: _mutedLight,
        height: 1.25,
      ),
      brand: _inter(
        size: 14,
        weight: FontWeight.w600,
        color: AppColors.primary,
        height: 1.4,
      ),
      label: _inter(
        size: 12,
        weight: FontWeight.w700,
        color: _inkLight,
        height: 1.2,
      ),
      listPrimary: _inter(
        size: 17,
        weight: FontWeight.w800,
        color: _inkLight,
        height: 1.2,
      ),
    );
  }

  /// Material roles for [ThemeData.textTheme] (patient + app baseline).
  TextTheme asMaterialTextTheme() {
    return TextTheme(
      displayLarge: display,
      headlineMedium: headline,
      headlineSmall: section,
      titleLarge: title,
      titleMedium: subtitle,
      titleSmall: caption,
      bodyLarge: body,
      bodyMedium: bodySmall,
      bodySmall: caption,
      labelLarge: label,
      labelMedium: overline,
      labelSmall: overline,
    );
  }

  factory PatientTypographyTokens.dark() {
    return PatientTypographyTokens(
      display: _inter(
        size: 22,
        weight: FontWeight.w800,
        color: _inkDark,
        height: 1.12,
        letterSpacing: -0.4,
      ),
      headline: _inter(
        size: 20,
        weight: FontWeight.w800,
        color: _inkDark,
        height: 1.2,
        letterSpacing: -0.35,
      ),
      section: _inter(
        size: 18,
        weight: FontWeight.w800,
        color: _inkDark,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      title: _inter(
        size: 17,
        weight: FontWeight.w700,
        color: _inkDark,
        height: 1.22,
        letterSpacing: -0.25,
      ),
      subtitle: _inter(
        size: 15,
        weight: FontWeight.w400,
        color: _mutedDark,
        height: 1.5,
      ),
      body: _inter(
        size: 15,
        weight: FontWeight.w400,
        color: _inkDark,
        height: 1.5,
      ),
      bodySmall: _inter(
        size: 13,
        weight: FontWeight.w500,
        color: _inkDark,
        height: 1.4,
      ),
      caption: _inter(
        size: 12,
        weight: FontWeight.w500,
        color: _mutedDark,
        height: 1.35,
      ),
      overline: _inter(
        size: 10.5,
        weight: FontWeight.w600,
        color: _mutedDark,
        height: 1.25,
      ),
      brand: _inter(
        size: 14,
        weight: FontWeight.w600,
        color: const Color(0xFF4DD4C8),
        height: 1.4,
      ),
      label: _inter(
        size: 12,
        weight: FontWeight.w700,
        color: _inkDark,
        height: 1.2,
      ),
      listPrimary: _inter(
        size: 17,
        weight: FontWeight.w800,
        color: _inkDark,
        height: 1.2,
      ),
    );
  }

  @override
  PatientTypographyTokens copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? section,
    TextStyle? title,
    TextStyle? subtitle,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? caption,
    TextStyle? overline,
    TextStyle? brand,
    TextStyle? label,
    TextStyle? listPrimary,
  }) {
    return PatientTypographyTokens(
      display: display ?? this.display,
      headline: headline ?? this.headline,
      section: section ?? this.section,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      body: body ?? this.body,
      bodySmall: bodySmall ?? this.bodySmall,
      caption: caption ?? this.caption,
      overline: overline ?? this.overline,
      brand: brand ?? this.brand,
      label: label ?? this.label,
      listPrimary: listPrimary ?? this.listPrimary,
    );
  }

  @override
  PatientTypographyTokens lerp(
    ThemeExtension<PatientTypographyTokens>? other,
    double t,
  ) {
    if (other is! PatientTypographyTokens) return this;
    return PatientTypographyTokens(
      display: TextStyle.lerp(display, other.display, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      section: TextStyle.lerp(section, other.section, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      subtitle: TextStyle.lerp(subtitle, other.subtitle, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      overline: TextStyle.lerp(overline, other.overline, t)!,
      brand: TextStyle.lerp(brand, other.brand, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      listPrimary: TextStyle.lerp(listPrimary, other.listPrimary, t)!,
    );
  }
}

extension PatientTypographyContext on BuildContext {
  PatientTypographyTokens get patientTx {
    return Theme.of(this).extension<PatientTypographyTokens>() ??
        PatientTypographyTokens.light();
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_app_theme.dart';
import 'package:carelink/core/carelink_palette.dart';

/// Single entry point for Material 3 theming + shared patient layout metrics.
///
/// Wire [MaterialApp] with [AppTheme.light] / [AppTheme.dark]. Patient screens
/// should prefer these tokens and helpers over ad-hoc values so the UI stays
/// aligned with the product reference (deep teal `#00796B`, cool grey scaffold).
abstract final class AppTheme {
  // --- Brand colors (screenshot-aligned) ---
  static const Color primaryTeal = AppColors.primary; // #00796B
  static const Color primaryTealDark = AppColors.primaryDark;
  static const Color scaffoldBackground = AppColors.background; // off-white grey
  static const Color inkSecondary = AppColors.textLight;

  /// Feature cards (`AI care match`, etc.).
  static const double cardBorderRadius = 24;

  /// Default horizontal inset for stacked patient cards + headers.
  static const double screenPaddingH = 16;

  /// Slightly wider horizontal inset for airy dashboards (My care hub).
  static const double screenPaddingComfort = 18;

  /// Space under scroll content when using [PatientFloatingNavShell].
  static const double scrollBottomPaddingOverFab = 118;

  static ThemeData _withPatientChrome(ThemeData base) {
    final shape24 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardBorderRadius),
    );
    final ct = base.cardTheme;
    final elevated = ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.38),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      shape: const StadiumBorder(),
      textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
    );
    final filled = FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      shape: const StadiumBorder(),
      textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        color: ct.color,
        surfaceTintColor: ct.surfaceTintColor,
        elevation: 0,
        margin: ct.margin ?? EdgeInsets.zero,
        clipBehavior: ct.clipBehavior,
        shadowColor: ct.shadowColor,
        shape: shape24,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: elevated),
      filledButtonTheme: FilledButtonThemeData(style: filled),
    );
  }

  /// Light patient theme (Inter + patient typography extension from base).
  static ThemeData get light => _withPatientChrome(CarelinkAppTheme.light);

  /// Dark patient theme.
  static ThemeData get dark => _withPatientChrome(CarelinkAppTheme.dark);

  // --- Text styles keyed to screenshot hierarchy (also applied via Theme) ---

  /// Large bold line: **Hi, Name** hero.
  static TextStyle patientHeroHiName(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return GoogleFonts.inter(
      color: p.inkDark,
      fontSize: 19,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
  }

  /// My Care hub header — prominent but balanced (≤ reference scale).
  static TextStyle careHubHeaderGreeting(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return GoogleFonts.inter(
      color: p.inkDark,
      fontSize: 17,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.25,
    );
  }

  /// Main headline inside slim hub cards (~18–20sp).
  static TextStyle careHubCardHeadline(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return GoogleFonts.inter(
      color: p.inkDark,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.2,
    );
  }

  /// Body / descriptions on hub (~12–14sp).
  static TextStyle careHubCardBody(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.inter(
      color: dark ? p.inkMuted : const Color(0xFF61737E),
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.42,
    );
  }

  /// Tighter captions (12sp) for shortcuts.
  static TextStyle careHubShortcutCaption(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.inter(
      color: dark ? p.inkMuted : const Color(0xFF61737E),
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.38,
    );
  }

  /// Grid card titles (appointment / records tiles).
  static TextStyle careHubShortcutTitle(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return GoogleFonts.inter(
      color: p.inkDark,
      fontSize: 15,
      fontWeight: FontWeight.w800,
      height: 1.12,
      letterSpacing: -0.2,
    );
  }

  /// Smaller muted line under hero (e.g. “Good evening, welcome back!”).
  static TextStyle patientHeroSubtitle(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return GoogleFonts.inter(
      color: p.inkMuted,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
  }

  /// Bold title row inside teal-accent cards (`AI care match`).
  static TextStyle aiFeatureCardTitle(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: p.inkDark,
    );
  }

  /// Standard section title (“Provider Specialty”, …).
  static TextStyle sectionTitle(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: p.inkDark,
    );
  }

  /// Muted description copy inside white dashboard cards (reference grey).
  static TextStyle cardMutedBody(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: dark ? p.inkMuted : const Color(0xFF61737E),
    );
  }

  /// Bold row / card title (dark ink).
  static TextStyle cardPrimaryTitle(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: p.inkDark,
    );
  }

  static List<BoxShadow> patientCardShadow(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.22 : 0.06),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static Color patientCardBorderColor(CarelinkPalette p) =>
      p.isDark ? const Color(0xFF18424B) : const Color(0xFFE3EAF0);

  static Color patientIconSoftFill(CarelinkPalette p) =>
      p.isDark ? const Color(0xFF103942) : const Color(0xFFE7F6F3);
}

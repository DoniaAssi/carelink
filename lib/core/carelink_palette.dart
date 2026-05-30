import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared light/dark tokens for all CareLink screens (replaces ad-hoc colors).
class CarelinkPalette {
  const CarelinkPalette({
    required this.brightness,
    required this.pageBg,
    required this.surface,
    required this.surfaceSoft,
    required this.headerDeep,
    required this.headerSoft,
    required this.inkDark,
    required this.inkMuted,
    required this.stroke,
    required this.navBackground,
    required this.navUnselected,
    required this.upcomingIconGradient,
    required this.starChipBg,
    required this.filterSurface,
  });

  final Brightness brightness;
  final Color pageBg;
  final Color surface;
  final Color surfaceSoft;
  final Color headerDeep;
  final Color headerSoft;
  final Color inkDark;
  final Color inkMuted;
  final Color stroke;
  final Color navBackground;
  final Color navUnselected;
  final List<Color> upcomingIconGradient;
  final Color starChipBg;
  final Color filterSurface;

  bool get isDark => brightness == Brightness.dark;

  factory CarelinkPalette.of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? CarelinkPalette.dark()
        : CarelinkPalette.light();
  }

  factory CarelinkPalette.light() {
    return CarelinkPalette(
      brightness: Brightness.light,
      pageBg: AppColors.background,
      surface: Colors.white,
      surfaceSoft: const Color(0xFFF0F7F5),
      headerDeep: AppColors.primaryDark,
      headerSoft: AppColors.primary,
      inkDark: AppColors.textDark,
      inkMuted: const Color(0xFF5C6C73),
      stroke: AppColors.border,
      navBackground: Colors.white,
      navUnselected: const Color(0xFF9AA8B0),
      upcomingIconGradient: const [
        Color(0xFFE6F7F5),
        Color(0xFFD8F2EF),
      ],
      starChipBg: const Color(0xFFFFF8E8),
      filterSurface: Colors.white,
    );
  }

  factory CarelinkPalette.dark() {
    return CarelinkPalette(
      brightness: Brightness.dark,
      pageBg: const Color(0xFF01161E),
      surface: const Color(0xFF0A252E),
      surfaceSoft: const Color(0xFF0D2E38),
      headerDeep: const Color(0xFF001018),
      headerSoft: const Color(0xFF0A2E35),
      inkDark: const Color(0xFFF5FBFC),
      inkMuted: const Color(0xFF8FA7AE),
      stroke: const Color(0xFF1E3A44),
      navBackground: const Color(0xFF0A252E),
      navUnselected: const Color(0xFF6B7F88),
      upcomingIconGradient: const [
        Color(0xFF143A40),
        Color(0xFF0A252E),
      ],
      starChipBg: const Color(0xFF2A2418),
      filterSurface: const Color(0xFF0F2F38),
    );
  }

  Color specialtyCardBackground(String title) {
    final key = title.trim().toLowerCase();
    if (isDark) {
      if (key.contains('home nursing') || key.contains('nursing')) {
        return const Color(0xFF152E32);
      }
      if (key.contains('wound')) return const Color(0xFF1A2535);
      if (key.contains('injection')) return const Color(0xFF252030);
      if (key.contains('elderly')) return const Color(0xFF152A22);
      if (key.contains('doctor') || key.contains('consult')) {
        return const Color(0xFF2A1F24);
      }
      if (key.contains('follow')) return const Color(0xFF2A2518);
      if (key.contains('cardio')) return const Color(0xFF2A1F22);
      if (key.contains('neuro')) return const Color(0xFF1A2230);
      if (key.contains('dental')) return const Color(0xFF221E2E);
      if (key.contains('pediatric')) return const Color(0xFF152A22);
      return const Color(0xFF15282E);
    }
    if (key.contains('home nursing') || key.contains('nursing')) {
      return const Color(0xFFEAF6F6);
    }
    if (key.contains('wound')) return const Color(0xFFEFF4FC);
    if (key.contains('injection')) return const Color(0xFFF4F0FC);
    if (key.contains('elderly')) return const Color(0xFFF1F7EE);
    if (key.contains('doctor') || key.contains('consult')) {
      return const Color(0xFFFBEFF1);
    }
    if (key.contains('follow')) return const Color(0xFFFCF3EA);
    if (key.contains('cardio')) return const Color(0xFFFDEFF1);
    if (key.contains('neuro')) return const Color(0xFFEFF4FC);
    if (key.contains('dental')) return const Color(0xFFF7F4FF);
    if (key.contains('pediatric')) return const Color(0xFFF1F7EE);
    return const Color(0xFFF3F7FA);
  }

  Color specialtyIconColor(String title) {
    final key = title.trim().toLowerCase();
    if (key.contains('home nursing') || key.contains('nursing')) {
      return const Color(0xFF1FA6A4);
    }
    if (key.contains('wound')) return const Color(0xFF4A90E2);
    if (key.contains('injection')) return const Color(0xFF7D57C2);
    if (key.contains('elderly')) return const Color(0xFF4EAA3A);
    if (key.contains('doctor') || key.contains('consult')) {
      return const Color(0xFFC45770);
    }
    if (key.contains('follow')) return const Color(0xFFDA8A2F);
    if (key.contains('cardio')) return const Color(0xFFCC5A72);
    if (key.contains('neuro')) return const Color(0xFF3F7FD4);
    if (key.contains('dental')) return const Color(0xFF7D57C2);
    if (key.contains('pediatric')) return const Color(0xFF4EAA3A);
    return AppColors.primary;
  }

  Color decorOrbColor(double alpha) =>
      AppColors.primary.withValues(alpha: isDark ? alpha * 0.6 : alpha);

  Color cardShadowColor(double alpha) =>
      Colors.black.withValues(alpha: isDark ? alpha * 1.2 : alpha);
}

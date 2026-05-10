import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_app_theme.dart';
import 'package:carelink/shared/services/api_service.dart';

class NurseUi {
  static final ValueNotifier<bool> isDarkMode = ValueNotifier(false);
  static final ValueNotifier<bool> isArabic = ValueNotifier(false);

  static Color get background =>
      isDarkMode.value ? const Color(0xFF0F172A) : AppColors.background;
  static Color get surface =>
      isDarkMode.value ? const Color(0xFF111827) : Colors.white;
  static Color get text =>
      isDarkMode.value ? Colors.white : AppColors.textDark;
  static Color get muted =>
      isDarkMode.value ? const Color(0xFFCBD5E1) : AppColors.textLight;
  static Color get border =>
      isDarkMode.value ? const Color(0xFF334155) : AppColors.border;
  static Color get softSurface =>
      isDarkMode.value ? const Color(0xFF1E293B) : Colors.grey.shade50;

  static TextDirection get direction =>
      isArabic.value ? TextDirection.rtl : TextDirection.ltr;

  static String label(String english, String arabic) {
    return isArabic.value ? arabic : english;
  }

  static Widget reactive(Widget Function(BuildContext context) builder) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, _, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: isArabic,
          builder: (context, _, child) {
            final baseTheme = isDarkMode.value
                ? CarelinkAppTheme.dark
                : CarelinkAppTheme.light;
            return Theme(
              data: baseTheme.copyWith(
                scaffoldBackgroundColor: background,
                cardColor: surface,
                colorScheme: baseTheme.colorScheme.copyWith(
                  primary: AppColors.primary,
                  secondary: AppColors.primaryDark,
                  surface: surface,
                  onSurface: text,
                ),
                appBarTheme: baseTheme.appBarTheme.copyWith(
                  backgroundColor: background,
                  foregroundColor: text,
                  elevation: 0,
                ),
                bottomNavigationBarTheme: baseTheme.bottomNavigationBarTheme.copyWith(
                  backgroundColor: surface,
                  selectedItemColor: AppColors.primaryDark,
                  unselectedItemColor: muted,
                ),
                inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
                  labelStyle: TextStyle(color: muted),
                  hintStyle: TextStyle(color: muted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              child: Directionality(
                textDirection: direction,
                child: builder(context),
              ),
            );
          },
        );
      },
    );
  }
}

class NurseModeControls extends StatelessWidget {
  final VoidCallback? onChanged;
  final String? providerUserId;

  const NurseModeControls({super.key, this.onChanged, this.providerUserId});

  Future<void> _persistIfPossible() async {
    final userId = providerUserId;
    if (userId == null || userId.isEmpty) return;
    try {
      await http.put(
        Uri.parse('${ApiService.baseUrl}/nurse/settings/$userId'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'darkMode': NurseUi.isDarkMode.value,
          'language': NurseUi.isArabic.value ? 'Arabic' : 'English',
        }),
      );
    } catch (_) {}
  }

  void _handleChanged() {
    onChanged?.call();
    _persistIfPossible();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NurseUi.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: NurseUi.isArabic,
          builder: (context, isArabic, _) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: NurseUi.label(
                      'Dark mode',
                      '\u0627\u0644\u0648\u0636\u0639 \u0627\u0644\u062f\u0627\u0643\u0646',
                    ),
                    child: Transform.scale(
                      scale: 0.78,
                      child: Switch(
                        value: isDark,
                        onChanged: (value) {
                          NurseUi.isDarkMode.value = value;
                          _handleChanged();
                        },
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.primaryDark,
                        inactiveThumbColor: const Color(0xFF1E293B),
                        inactiveTrackColor: const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: NurseUi.label(
                      'Change language',
                      '\u062a\u063a\u064a\u064a\u0631 \u0627\u0644\u0644\u063a\u0629',
                    ),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.language_rounded,
                        color: isArabic ? AppColors.primaryDark : Colors.lightBlue,
                      ),
                      onPressed: () {
                        NurseUi.isArabic.value = !isArabic;
                        _handleChanged();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

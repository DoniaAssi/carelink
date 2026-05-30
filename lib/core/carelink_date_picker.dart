import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Today at 00:00 local time — use for [DatePickerDialog.lastDate] so "tomorrow" is not selectable.
DateTime carelinkTodayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// CareLink (teal) styling for [showDatePicker] — rounded dialog, mint surface, selected day in primary.
class CarelinkDatePickerTheme {
  static Widget wrap(BuildContext context, Widget? child) {
    if (child == null) return const SizedBox.shrink();
    final base = Theme.of(context);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: const Color(0xFFF3F8F6),
      onSurface: AppColors.textDark,
      onSurfaceVariant: const Color(0xFF5F7380),
      surfaceContainerHighest: const Color(0xFFE8F0F0),
    );
    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFF3F8F6),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: const Color(0xFFF3F8F6),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          headerForegroundColor: AppColors.textDark,
          weekdayStyle: const TextStyle(
            color: Color(0xFF5F7380),
            fontWeight: FontWeight.w600,
          ),
          dayForegroundColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFFC5CED1);
            }
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return AppColors.textDark;
          }),
          dayBackgroundColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return Colors.transparent;
          }),
          todayForegroundColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return AppColors.primary;
          }),
          todayBackgroundColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return AppColors.primary.withValues(alpha: 0.12);
          }),
          yearForegroundColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return AppColors.textDark;
          }),
          yearBackgroundColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return Colors.transparent;
          }),
        ),
      ),
      child: child,
    );
  }
}

/// Date of birth: future days are disabled; [lastDate] is today (local date).
Future<DateTime?> showCarelinkDateOfBirthPicker(
  BuildContext context, {
  String? currentIsoDate,
  int defaultYearsBack = 18,
}) async {
  final today = carelinkTodayDate();
  final first = DateTime(1900, 1, 1);
  late DateTime initial;
  if (currentIsoDate != null && currentIsoDate.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(currentIsoDate.trim());
    initial = parsed ??
        DateTime(today.year - defaultYearsBack, today.month, today.day);
  } else {
    initial = DateTime(today.year - defaultYearsBack, today.month, today.day);
  }
  if (initial.isAfter(today)) initial = today;
  if (initial.isBefore(first)) initial = first;

  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: today,
    helpText: 'Select date',
    cancelText: 'Cancel',
    confirmText: 'OK',
    builder: (context, child) => CarelinkDatePickerTheme.wrap(context, child),
  );
}

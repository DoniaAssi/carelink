import 'package:flutter/widgets.dart';

import 'package:carelink/core/app_localizations.dart';

class AppointmentTimeUtils {
  static DateTime? parseBackendDateTime(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;

    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return null;

    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  static DateTime? normalize(DateTime? date) {
    if (date == null) return null;
    return date.isUtc ? date.toLocal() : date;
  }

  static String formatDate(
    BuildContext context,
    DateTime? date, {
    String? fallback,
    bool numeric = false,
  }) {
    final local = normalize(date);
    if (local == null) {
      return fallback ?? context.tr('common.dateUnavailable');
    }

    if (numeric) {
      return '${local.day}/${local.month}/${local.year}';
    }

    final months = context.l10n.isArabic ? _monthsAr : _monthsEn;
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  static String formatTime(
    BuildContext context,
    DateTime? date, {
    String? fallback,
    bool twoDigitHour = false,
  }) {
    final local = normalize(date);
    if (local == null) {
      return fallback ?? context.tr('common.timeUnavailable');
    }

    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final hour = twoDigitHour ? hour12.toString().padLeft(2, '0') : '$hour12';
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12
        ? (context.l10n.isArabic ? 'م' : 'PM')
        : (context.l10n.isArabic ? 'ص' : 'AM');

    return '$hour:$minute $suffix';
  }

  static String formatDateTime(BuildContext context, DateTime? date) {
    return '${formatDate(context, date)} - ${formatTime(context, date)}';
  }

  static const List<String> _monthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _monthsAr = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
}

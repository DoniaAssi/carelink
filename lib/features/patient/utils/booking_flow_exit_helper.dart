import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';

class BookingFlowExitHelper {
  const BookingFlowExitHelper._();

  static Future<void> exitToHome({
    required BuildContext context,
    required String patientUserId,
    required bool hasProgress,
  }) async {
    FocusScope.of(context).unfocus();

    if (hasProgress) {
      final l10n = context.l10n;
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: l10n.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(l10n.t('booking.exit.title')),
            content: Text(l10n.t('booking.exit.message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('booking.exit.stay')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('booking.exit.leave')),
              ),
            ],
          ),
        ),
      );
      if (shouldLeave != true || !context.mounted) return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = patientUserId.trim().isNotEmpty
        ? patientUserId.trim()
        : prefs.getString('session_user_id') ?? '';
    final displayName = prefs.getString('session_display_name');

    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/patient-home',
      (route) => false,
      arguments: {
        'userId': userId,
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName,
        'initialTab': 0,
      },
    );
  }

  static Widget action({
    required BuildContext context,
    required String patientUserId,
    required bool hasProgress,
  }) {
    return IconButton(
      tooltip: context.tr('booking.exit.tooltip'),
      color: AppColors.primary,
      icon: const Icon(Icons.home_outlined),
      onPressed: () => exitToHome(
        context: context,
        patientUserId: patientUserId,
        hasProgress: hasProgress,
      ),
    );
  }
}

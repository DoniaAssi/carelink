import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/core/patient_typography.dart';

class PatientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PatientAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showBack = true,
    this.showLanguage = true,
    this.showTheme = true,
    this.showNotification = false,
    this.showMessages = false,
    this.showAiRobot = false,
    this.actions,
    this.onBack,
    this.onMessageTap,
  });

  final String? title;
  final Widget? titleWidget;
  final bool showBack;
  final bool showLanguage;
  final bool showTheme;
  final bool showNotification;
  final bool showMessages;
  final bool showAiRobot;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final VoidCallback? onMessageTap;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title:
          titleWidget ??
          (title != null
              ? Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.patientTx.headline.copyWith(
                    color: AppColors.primary,
                  ),
                )
              : null),
      centerTitle: false,
      leading: showBack
          ? IconButton(
              icon: const BackButtonIcon(),
              color: AppColors.primary,
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
      actions: [
        if (showNotification)
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: AppColors.primary),
            iconSize: 24,
            onPressed: () {
              // Triggers notifications or profile page
            },
          ),
        if (showMessages)
          IconButton(
            icon: Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.primary,
            ),
            iconSize: 24,
            onPressed: onMessageTap ?? () {},
          ),
        if (showAiRobot)
          IconButton(
            icon: Icon(Icons.smart_toy_outlined, color: AppColors.primary),
            iconSize: 24,
            onPressed: () {
              Navigator.pushNamed(context, '/find-provider');
            },
          ),
        if (actions != null) ...actions!,
        if (showLanguage || showTheme)
          PatientHeaderActions(
            showLanguage: showLanguage,
            showTheme: showTheme,
            color: AppColors.primary,
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

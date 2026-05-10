import 'package:flutter/material.dart';

import 'package:carelink/core/app_theme.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';

/// Reusable home-style header: **CareLink** logo, greeting block, bell action.
///
/// Pair with decorative layers (optional) from the caller — this widget is the
/// content column only so it stacks cleanly inside a [Stack].
class CarelinkPatientDashboardHeader extends StatelessWidget {
  const CarelinkPatientDashboardHeader({
    super.key,
    required this.hiTitle,
    required this.subtitle,
    required this.avatar,
    this.onAvatarTap,
    required this.onNotificationTap,
    this.showNotificationBadge = true,
  });

  final String hiTitle;
  final String subtitle;
  final Widget avatar;

  /// Usually opens edit profile / photo.
  final VoidCallback? onAvatarTap;

  final VoidCallback onNotificationTap;
  final bool showNotificationBadge;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CarelinkBrandLogo(
              height: 30,
              fallbackTextColor: p.inkDark,
              forceDarkLogo: p.isDark,
            ),
            const Spacer(),
            InkWell(
              onTap: onNotificationTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.stroke),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: p.inkDark,
                        size: 22,
                      ),
                    ),
                    if (showNotificationBadge)
                      const Positioned(
                        right: 10,
                        top: 10,
                        child: _NotificationDot(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: onAvatarTap == null
                  ? avatar
                  : InkWell(
                      onTap: onAvatarTap,
                      borderRadius: BorderRadius.circular(32),
                      child: avatar,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hiTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.patientHeroHiName(context),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.patientHeroSubtitle(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationDot extends StatelessWidget {
  const _NotificationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFFFF6B6B),
        shape: BoxShape.circle,
      ),
    );
  }
}

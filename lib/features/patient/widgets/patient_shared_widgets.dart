import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';

export 'package:carelink/shared/widgets/patient_app_bar.dart';

class PatientPressable extends StatefulWidget {
  const PatientPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.enabled = true,
    this.hoverScale = 1.01,
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 180),
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool enabled;
  final double hoverScale;
  final double pressedScale;
  final Duration duration;

  @override
  State<PatientPressable> createState() => _PatientPressableState();
}

class _PatientPressableState extends State<PatientPressable> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _interactive => widget.enabled && widget.onTap != null;

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (!_interactive || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final scale = _pressed
        ? widget.pressedScale
        : (_hovered ? widget.hoverScale : 1.0);
    final overlayAlpha = _pressed ? 0.11 : (_hovered ? 0.05 : 0.0);

    return MouseRegion(
      cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: scale,
          duration: widget.duration,
          curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
          child: Material(
            color: Colors.transparent,
            borderRadius: widget.borderRadius,
            elevation: _pressed ? 3 : (_hovered ? 2 : 0),
            shadowColor: AppColors.primary.withValues(
              alpha: p.isDark ? 0.20 : 0.12,
            ),
            child: InkWell(
              onTap: _interactive ? widget.onTap : null,
              borderRadius: widget.borderRadius,
              splashColor: AppColors.primary.withValues(
                alpha: p.isDark ? 0.16 : 0.10,
              ),
              highlightColor: AppColors.primary.withValues(
                alpha: p.isDark ? 0.10 : 0.06,
              ),
              hoverColor: AppColors.primary.withValues(
                alpha: p.isDark ? 0.08 : 0.04,
              ),
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: Stack(
                  children: [
                    widget.child,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: widget.duration,
                          curve: Curves.easeOutCubic,
                          color: AppColors.primary.withValues(
                            alpha: p.isDark
                                ? overlayAlpha * 1.35
                                : overlayAlpha,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Styled Primary Button following design system
class PatientPrimaryButton extends StatelessWidget {
  const PatientPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.height = 48,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final btnChild = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          );

    return _PatientButtonMotion(
      enabled: !isLoading && onPressed != null,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(key: ValueKey(isLoading), child: btnChild),
          ),
        ),
      ),
    );
  }
}

/// Styled Secondary Button following design system
class PatientSecondaryButton extends StatelessWidget {
  const PatientSecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.height = 48,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _PatientButtonMotion(
      enabled: onPressed != null,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientButtonMotion extends StatefulWidget {
  const _PatientButtonMotion({
    required this.child,
    required this.enabled,
    required this.borderRadius,
  });

  final Widget child;
  final bool enabled;
  final BorderRadius borderRadius;

  @override
  State<_PatientButtonMotion> createState() => _PatientButtonMotionState();
}

class _PatientButtonMotionState extends State<_PatientButtonMotion> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 170),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(borderRadius: widget.borderRadius),
          child: widget.child,
        ),
      ),
    );
  }
}

class PatientAnimatedListItem extends StatelessWidget {
  const PatientAnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 320),
  });

  final Widget child;
  final int index;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + Duration(milliseconds: (index.clamp(0, 6)) * 35),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Standardized Card container for the Patient module
class PatientCard extends StatelessWidget {
  const PatientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.22 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) {
      return Container(margin: margin, child: cardContent);
    }

    return Container(
      margin: margin,
      child: PatientPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: cardContent,
      ),
    );
  }
}

/// Standardized Service Card representing a quick service option
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return PatientCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: p.inkDark,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized loading indicator screen/state
class PatientLoadingState extends StatelessWidget {
  const PatientLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: TextStyle(color: p.inkMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standardized empty placeholder state
class PatientEmptyState extends StatelessWidget {
  const PatientEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.folder_open_outlined,
    this.actionLabel,
    this.onActionPressed,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: p.inkMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: p.inkMuted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: 24),
              PatientPrimaryButton(
                onPressed: onActionPressed,
                label: actionLabel!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

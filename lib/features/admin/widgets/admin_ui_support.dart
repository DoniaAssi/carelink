import 'package:flutter/material.dart';

import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/patient_typography.dart';
import 'package:carelink/core/profile_avatar.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

final Listenable adminUiSettings = Listenable.merge([
  localeController,
  themeController,
]);

const adminTeal = Color(0xFF0F766E);
const adminDanger = Color(0xFFDC3545);
const adminWarning = Color(0xFFF59E0B);
const adminSuccess = Color(0xFF22A06B);

ThemeData adminCareTheme(BuildContext context) {
  final base = Theme.of(context);
  final p = CarelinkPalette.of(context);
  final roundedCard = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(22),
    side: BorderSide(color: p.stroke),
  );
  return base.copyWith(
    textTheme: context.patientTx.asMaterialTextTheme(),
    scaffoldBackgroundColor: p.pageBg,
    cardColor: p.surface,
    canvasColor: p.surface,
    dividerColor: p.stroke,
    colorScheme: base.colorScheme.copyWith(
      primary: adminTeal,
      surface: p.surface,
      onSurface: p.inkDark,
      error: adminDanger,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: roundedCard,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: p.cardShadowColor(.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: p.surfaceSoft,
      hintStyle: TextStyle(color: p.inkMuted),
      labelStyle: TextStyle(color: p.inkMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: adminTeal, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: adminDanger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: adminTeal,
        foregroundColor: base.colorScheme.onPrimary,
        disabledBackgroundColor: p.stroke,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: adminTeal,
        side: const BorderSide(color: adminTeal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: p.surface,
      selectedColor: adminTeal,
      side: BorderSide(color: p.stroke),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      labelStyle: TextStyle(color: p.inkDark, fontWeight: FontWeight.w700),
      secondaryLabelStyle: TextStyle(
        color: base.colorScheme.onPrimary,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class AdminAvatar extends StatelessWidget {
  const AdminAvatar({
    super.key,
    required this.data,
    required this.name,
    this.size = 48,
    this.icon = Icons.person_rounded,
  });

  final Map<String, dynamic> data;
  final String name;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: name,
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: profileAvatarOrPlaceholder(
            imageUrl: profileImageUrlFromMap(data),
            size: size,
            placeholderColor: adminTeal,
            placeholderIcon: icon,
            iconSize: size * .46,
          ),
        ),
      ),
    );
  }
}

class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => PatientLoadingState(
    message: message == null ? null : context.adminTr(message!),
  );
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onActionPressed,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) => PatientEmptyState(
    message: context.adminTr(message),
    icon: icon,
    actionLabel: actionLabel == null ? null : context.adminTr(actionLabel!),
    onActionPressed: onActionPressed,
  );
}

class AdminResponsiveActions extends StatelessWidget {
  const AdminResponsiveActions({
    super.key,
    required this.children,
    this.spacing = 10,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.25;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }
}

class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({super.key, required this.status, this.label});

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final color = switch (normalized) {
      'pending' || 'requested' || 'waiting' || 'under_review' => adminWarning,
      'approved' || 'accepted' || 'active' => adminSuccess,
      'rejected' || 'cancelled' || 'failed' => adminDanger,
      'paid' || 'processed' || 'completed' => adminTeal,
      _ => CarelinkPalette.of(context).inkMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: AdminLocalizedText(
        label ?? status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

extension AdminBuildContextX on BuildContext {
  String adminTr(String source) => l10n.admin(source);

  String adminError(Object error) {
    final raw = error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
    return raw.isEmpty ? adminTr('Request failed') : raw;
  }

  TextDirection get adminTextDirection =>
      localeController.isArabic ? TextDirection.rtl : TextDirection.ltr;

  IconData get adminBackIcon => localeController.isArabic
      ? Icons.arrow_forward_rounded
      : Icons.arrow_back_rounded;
}

class AdminGlobalControls extends StatelessWidget {
  const AdminGlobalControls({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 10, 18, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [PatientHeaderActions()],
      ),
    );
  }
}

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onMenu,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: context.adminTr(onBack != null ? 'Back' : 'Menu'),
          onPressed: onBack ?? onMenu,
          icon: Icon(
            onBack != null ? context.adminBackIcon : Icons.menu_rounded,
            color: p.inkDark,
            size: 22,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminLocalizedText(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.patientTx.headline.copyWith(color: p.inkDark),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                AdminLocalizedText(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.patientTx.caption.copyWith(color: p.inkMuted),
                ),
              ],
            ],
          ),
        ),
        if (onRefresh != null)
          IconButton(
            tooltip: context.adminTr('Refresh'),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: adminTeal, size: 21),
          ),
        const PatientHeaderActions(),
      ],
    );
  }
}

/// Localizes legacy Admin copy while preserving every existing widget/action.
/// It also maps the old neutral text colors onto the shared light/dark palette.
class AdminLocalizedText extends StatelessWidget {
  const AdminLocalizedText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final sourceColor = style?.color;
    final effectiveColor = _neutralTone(sourceColor, p);
    final effectiveTextAlign = switch (textAlign) {
      TextAlign.left || TextAlign.right => TextAlign.start,
      _ => textAlign,
    };
    final effectiveStyle = effectiveColor == null
        ? style
        : (style ?? const TextStyle()).copyWith(color: effectiveColor);
    return Text(
      context.adminTr(data),
      style: effectiveStyle,
      strutStyle: strutStyle,
      textAlign: effectiveTextAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }

  Color? _neutralTone(Color? color, CarelinkPalette p) {
    if (color == null) return null;
    const darkNeutrals = {0xFF0D1B2A, 0xFF183236, 0xFF102A2E};
    const mutedNeutrals = {
      0xFF5C7180,
      0xFF64787C,
      0xFF6B7C86,
      0xFF6D7F83,
      0xFF6F8589,
      0xFF718388,
      0xFF7A8A8E,
      0xFF7B8D91,
      0xFF84969B,
      0xFF9AA8AB,
      0xFFB5C2C4,
    };
    if (darkNeutrals.contains(color.toARGB32())) return p.inkDark;
    if (mutedNeutrals.contains(color.toARGB32())) return p.inkMuted;
    return null;
  }
}

import 'package:flutter/material.dart';

import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

final Listenable adminUiSettings = Listenable.merge([
  localeController,
  themeController,
]);

extension AdminBuildContextX on BuildContext {
  String adminTr(String source) => l10n.admin(source);

  String adminError(Object error) =>
      l10n.userMessage(error, fallbackKey: 'common.error.generic');

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
        children: [
          PatientHeaderActions(),
        ],
      ),
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

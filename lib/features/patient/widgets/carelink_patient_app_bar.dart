import 'package:flutter/material.dart';

import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

/// AppBar للمريض: خلفية [CarelinkPalette.surface]، نصوص [inkDark]، وإجراءات اللغة/الثيم
/// مثل الصفحة الرئيسية (بدل شريط تركواز ثابت من [ThemeData.appBarTheme]).
AppBar carelinkPatientAppBar(
  BuildContext context, {
  required Widget title,
  bool automaticallyImplyLeading = true,
  Widget? leading,
  PreferredSizeWidget? bottom,
  List<Widget>? extraActions,
  bool centerTitle = true,
}) {
  final p = CarelinkPalette.of(context);
  final baseTitle = Theme.of(context).textTheme.titleLarge;

  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    backgroundColor: p.surface,
    foregroundColor: p.inkDark,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    iconTheme: IconThemeData(color: p.inkDark),
    actionsIconTheme: IconThemeData(color: p.inkDark),
    titleTextStyle: baseTitle?.copyWith(
      color: p.inkDark,
      fontWeight: FontWeight.w700,
      fontSize: 18,
    ),
    centerTitle: centerTitle,
    title: title,
    bottom: bottom,
    actions: carelinkAppBarActions(extraActions),
  );
}

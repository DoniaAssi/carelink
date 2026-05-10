import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';

/// Teal circular arrow control (dashboard / list rows).
class CarelinkTealCircleArrow extends StatelessWidget {
  const CarelinkTealCircleArrow({
    super.key,
    this.diameter = 40,
    this.iconSize = 22,
    this.softBackground,
  });

  final double diameter;
  final double iconSize;

  /// Defaults to mint soft fill from palette.
  final Color? softBackground;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final soft = softBackground ?? p.surfaceSoft;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: soft,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        color: AppColors.primary,
        size: iconSize,
      ),
    );
  }
}

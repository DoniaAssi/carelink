import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';

/// Compact step dots + connectors for multi-step auth flows.
class StepProgressIndicator extends StatelessWidget {
  const StepProgressIndicator({
    super.key,
    required this.currentStepIndex,
    this.stepCount = 2,
  });

  final int currentStepIndex;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < stepCount; i++) ...[
          _StepDot(active: i <= currentStepIndex, index: i + 1),
          if (i < stepCount - 1)
            Container(
              width: 32,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i < currentStepIndex
                    ? AppColors.primary
                    : p.stroke,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.active, required this.index});

  final bool active;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.primary : p.surface,
        border: Border.all(
          color: active ? AppColors.primary : p.stroke,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$index',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: active ? Colors.white : p.inkMuted,
        ),
      ),
    );
  }
}

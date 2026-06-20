import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';

enum BookingFlowStep { provider, dateTime, location, review }

class BookingStepIndicator extends StatelessWidget {
  final BookingFlowStep currentStep;

  const BookingStepIndicator({super.key, required this.currentStep});

  static const _labelKeys = <String>[
    'booking.step.provider',
    'booking.step.dateTime',
    'booking.step.location',
    'booking.step.review',
  ];

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final currentIndex = currentStep.index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Column(
        children: [
          Row(
            children: List.generate(_labelKeys.length * 2 - 1, (i) {
              if (i.isOdd) {
                final connectorIndex = (i - 1) ~/ 2;
                final isPassed = connectorIndex < currentIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: isPassed
                        ? AppColors.primary
                        : p.stroke,
                  ),
                );
              }

              final index = i ~/ 2;
              final isDone = index < currentIndex;
              final isCurrent = index == currentIndex;
              return _StepDot(
                label: '${index + 1}',
                done: isDone,
                current: isCurrent,
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(_labelKeys.length, (index) {
              final isCurrent = index == currentIndex;
              final isDone = index < currentIndex;
              final color = isCurrent
                  ? AppColors.primary
                  : isDone
                  ? p.inkDark.withValues(alpha: 0.8)
                  : p.inkMuted;
              return Expanded(
                child: Text(
                  context.tr(_labelKeys[index]),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: isCurrent || isDone ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool current;

  const _StepDot({
    required this.label,
    required this.done,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    
    Color bgColor;
    Color iconColor;
    Color borderColor;
    
    if (done || current) {
      bgColor = AppColors.primary;
      iconColor = Colors.white;
      borderColor = AppColors.primary;
    } else {
      bgColor = Colors.transparent;
      iconColor = p.inkMuted;
      borderColor = p.stroke;
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : Text(
              label,
              style: TextStyle(
                color: iconColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

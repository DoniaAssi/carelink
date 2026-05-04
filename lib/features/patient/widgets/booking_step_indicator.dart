import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';

enum BookingFlowStep { service, dateTime, location, details, review }

class BookingStepIndicator extends StatelessWidget {
  final BookingFlowStep currentStep;

  const BookingStepIndicator({super.key, required this.currentStep});

  static const _labels = <String>[
    'Service',
    'Date & Time',
    'Location',
    'Details',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final currentIndex = currentStep.index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          Row(
            children: List.generate(_labels.length * 2 - 1, (i) {
              if (i.isOdd) {
                final connectorIndex = (i - 1) ~/ 2;
                final active = connectorIndex < currentIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.42)
                        : p.stroke,
                  ),
                );
              }

              final index = i ~/ 2;
              final isDone = index < currentIndex;
              final isCurrent = index == currentIndex;
              final bg = isDone || isCurrent
                  ? AppColors.primary
                  : p.surfaceSoft;
              return _StepDot(
                label: '${index + 1}',
                done: isDone,
                current: isCurrent,
                color: bg,
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_labels.length, (index) {
              final isDone = index < currentIndex;
              final isCurrent = index == currentIndex;
              final color = isCurrent
                  ? AppColors.primary
                  : isDone
                  ? p.inkDark.withValues(alpha: 0.72)
                  : p.inkMuted;
              return Expanded(
                child: Text(
                  _labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
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
  final Color color;

  const _StepDot({
    required this.label,
    required this.done,
    required this.current,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: current
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : Text(
              label,
              style: TextStyle(
                color: current ? Colors.white : p.inkMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

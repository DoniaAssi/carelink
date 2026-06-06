import 'package:flutter/material.dart';

class StepProgressIndicator extends StatelessWidget {
  const StepProgressIndicator({super.key, required this.currentStepIndex});

  final int currentStepIndex;

  @override
  Widget build(BuildContext context) {
    const total = 2;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i <= currentStepIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: active ? 26 : 12,
          height: 6,
          decoration: BoxDecoration(
            color: active ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';

class AiScoreBreakdown extends StatelessWidget {
  const AiScoreBreakdown({
    super.key,
    required this.breakdown,
    this.showHistory = true,
  });

  final ScoreBreakdown breakdown;
  final bool showHistory;

  @override
  Widget build(BuildContext context) {
    final rows = <_Row>[
      _Row('Location', breakdown.location),
      _Row('Specialization', breakdown.specialization),
      _Row('Availability', breakdown.availability),
      _Row('Rating', breakdown.rating),
      _Row('Experience', breakdown.experience),
      _Row('Medical compatibility', breakdown.medicalCompatibility),
      if (showHistory) _Row('History / loyalty', breakdown.history),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AiFlowTheme.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${(r.value * 100).round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AiFlowTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: r.value.clamp(0, 1),
                        backgroundColor: AiFlowTheme.cardStroke,
                        color: AiFlowTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Row {
  _Row(this.label, this.value);
  final String label;
  final double value;
}

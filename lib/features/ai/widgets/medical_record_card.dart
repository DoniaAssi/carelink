import 'package:flutter/material.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';

class MedicalRecordCard extends StatelessWidget {
  const MedicalRecordCard({super.key, required this.entry, this.onTap});

  final MedicalRecordEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AiFlowTheme.cardStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AiFlowTheme.ink,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.type.name,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AiFlowTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (entry.diagnosis.isNotEmpty)
                Text(
                  'Dx: ${entry.diagnosis}',
                  style: const TextStyle(fontSize: 12, color: AiFlowTheme.ink),
                ),
              if (entry.description.isNotEmpty)
                Text(
                  entry.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AiFlowTheme.inkMuted,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (entry.usedByAi)
                    _chip('Used by AI recommendations', true),
                  if (entry.privateLabel)
                    _chip('Private medical document', false),
                  if (entry.uploadedAfterVisit)
                    _chip('Uploaded after visit', false),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(entry.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AiFlowTheme.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary
            ? AiFlowTheme.primaryBlue.withValues(alpha: 0.1)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: primary ? AiFlowTheme.primaryBlue : AiFlowTheme.inkMuted,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month}-${d.day}';
  }
}

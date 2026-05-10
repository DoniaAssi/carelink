import 'package:flutter/material.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';
import 'package:carelink/shared/models/provider_model.dart';

class AppointmentSummaryCard extends StatelessWidget {
  const AppointmentSummaryCard({
    super.key,
    required this.provider,
    required this.dateLabel,
    required this.timeLabel,
    required this.reason,
    this.priceLabel,
  });

  final ProviderModel provider;
  final String dateLabel;
  final String timeLabel;
  final String reason;
  final String? priceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AiFlowTheme.cardStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider.fullName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AiFlowTheme.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            provider.specialization.isEmpty
                ? provider.role
                : provider.specialization,
            style: const TextStyle(
              color: AiFlowTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Divider(height: 22),
          _line(Icons.calendar_today_outlined, 'Date', dateLabel),
          const SizedBox(height: 8),
          _line(Icons.schedule_rounded, 'Time', timeLabel),
          const SizedBox(height: 8),
          _line(Icons.edit_note_rounded, 'Reason for visit', reason),
          if (priceLabel != null) ...[
            const SizedBox(height: 8),
            _line(Icons.payments_outlined, 'Estimated fee', priceLabel!),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AiFlowTheme.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                k,
                style: const TextStyle(
                  fontSize: 12,
                  color: AiFlowTheme.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                v,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AiFlowTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

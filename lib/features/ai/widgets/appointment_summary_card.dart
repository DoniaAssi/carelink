import 'package:flutter/material.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
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
    final dark = themeController.isDark;
    final ar = localeController.isArabic;

    final cardBg = dark ? Colors.grey[850]! : Colors.white;
    final themeColor = dark ? Colors.white : AiFlowTheme.ink;
    final helperColor = dark ? Colors.grey.shade400 : AiFlowTheme.inkMuted;
    final strokeColor = dark ? Colors.grey[750]! : AiFlowTheme.cardStroke;

    final dateKey = ar ? 'التاريخ' : 'Date';
    final timeKey = ar ? 'الوقت' : 'Time';
    final reasonKey = ar ? 'سبب الزيارة' : 'Reason for visit';
    final feeKey = ar ? 'الرسوم المقدرة' : 'Estimated fee';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: strokeColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider.fullName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: themeColor,
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
          Divider(height: 22, color: strokeColor),
          _line(Icons.calendar_today_outlined, dateKey, dateLabel, themeColor, helperColor),
          const SizedBox(height: 8),
          _line(Icons.schedule_rounded, timeKey, timeLabel, themeColor, helperColor),
          const SizedBox(height: 8),
          _line(Icons.edit_note_rounded, reasonKey, reason, themeColor, helperColor),
          if (priceLabel != null) ...[
            const SizedBox(height: 8),
            _line(Icons.payments_outlined, feeKey, priceLabel!, themeColor, helperColor),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String k, String v, Color themeColor, Color helperColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: helperColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                k,
                style: TextStyle(
                  fontSize: 12,
                  color: helperColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                v,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: themeColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

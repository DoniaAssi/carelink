import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder;
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
    final p = CarelinkPalette.of(context);
    final ar = localeController.isArabic;

    final dateKey = ar ? 'التاريخ' : 'Date';
    final timeKey = ar ? 'الوقت' : 'Time';
    final serviceKey = ar ? 'نوع الخدمة' : 'Service type';
    final feeKey = ar ? 'الرسوم المقدرة' : 'Estimated fee';
    final specialty = provider.specialization.trim().isNotEmpty
        ? provider.specialization.trim()
        : (ar ? 'مقدم رعاية عامة' : 'General Care Provider');
    final service = provider.serviceType.trim().isNotEmpty
        ? provider.serviceType.trim()
        : reason;
    final isDoctor = provider.role.toLowerCase() == 'doctor';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor(0.055),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.09),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: ClipOval(
                  child: profileAvatarOrPlaceholder(
                    imageUrl: provider.profileImageUrl,
                    size: 58,
                    placeholderColor: AppColors.primary,
                    placeholderIcon: isDoctor
                        ? Icons.medical_services_outlined
                        : Icons.local_hospital_outlined,
                    iconSize: 27,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: p.inkDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 26, color: p.stroke),
          Row(
            children: [
              Expanded(
                child: _detailTile(
                  p,
                  Icons.calendar_today_outlined,
                  dateKey,
                  dateLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _detailTile(
                  p,
                  Icons.schedule_rounded,
                  timeKey,
                  timeLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _detailTile(
                  p,
                  Icons.medical_services_outlined,
                  serviceKey,
                  service,
                ),
              ),
              if (priceLabel != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _detailTile(
                    p,
                    Icons.payments_outlined,
                    feeKey,
                    priceLabel!,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailTile(
    CarelinkPalette p,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.stroke.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: p.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.2,
              color: p.inkDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

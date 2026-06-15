import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/booking_request_model.dart';

class BookingProviderSummary extends StatelessWidget {
  const BookingProviderSummary({
    super.key,
    required this.request,
    this.compact = false,
  });

  final BookingRequestModel request;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final imageUrl = request.providerImageUrl.trim();
    final service = request.serviceType.trim();

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: compact ? 23 : 27,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
            child: imageUrl.isEmpty
                ? const Icon(
                    Icons.medical_services_rounded,
                    color: AppColors.primary,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.isArabic
                      ? 'الحجز مع ${request.providerName}'
                      : 'Booking with ${request.providerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _specialtyLabel(
                    context,
                    request.specialization.trim().isNotEmpty
                        ? request.specialization
                        : request.providerRole,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted, fontSize: 12.5),
                ),
                if (service.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _serviceLabel(context, service),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ],
      ),
    );
  }

  String _specialtyLabel(BuildContext context, String value) {
    if (value.trim().toLowerCase() == 'endocrinology') {
      return context.tr('specialty.endocrinology');
    }
    return value;
  }

  String _serviceLabel(BuildContext context, String value) {
    switch (value.trim().toLowerCase()) {
      case 'home nursing care':
        return context.tr('booking.service.homeNursing');
      case 'general doctor':
      case 'doctor consultation':
        return context.tr('booking.service.generalDoctor');
      case 'post-surgery care':
      case 'post surgery care':
        return context.tr('booking.service.postSurgery');
      case 'elderly care':
        return context.tr('booking.service.elderlyCare');
      case 'physiotherapy':
        return context.tr('booking.service.physiotherapy');
      case 'mental support':
      case 'mental health':
        return context.tr('booking.service.mentalSupport');
      default:
        return value;
    }
  }
}

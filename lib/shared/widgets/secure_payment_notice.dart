import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';

/// بيان توضيحي للمريض: دفع إلكتروني آمن (لا تخزين لأرقام البطاقة، اتصال مشفّر).
class SecurePaymentNotice extends StatelessWidget {
  const SecurePaymentNotice({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final pad = compact ? 10.0 : 12.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: p.isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: compact ? 22 : 24,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('securePayment.title'),
                  style: TextStyle(
                    fontSize: compact ? 13.5 : 14.5,
                    fontWeight: FontWeight.w800,
                    color: p.inkDark,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          _bullet(
            p,
            context.tr('securePayment.b1'),
            compact,
          ),
          _bullet(
            p,
            context.tr('securePayment.b2'),
            compact,
          ),
          _bullet(
            p,
            context.tr('securePayment.b3'),
            compact,
          ),
          _bullet(
            p,
            context.tr('securePayment.b4'),
            compact,
          ),
        ],
      ),
    );
  }

  Widget _bullet(CarelinkPalette p, String text, bool compact) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: compact ? 11.2 : 12,
                color: p.inkMuted,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/app_colors.dart';


/// Full-screen analysis state reused while the hybrid scorer ranks providers.
class AiRecommendationLoader extends StatefulWidget {
  const AiRecommendationLoader({super.key, this.isArabic = false});

  final bool isArabic;

  @override
  State<AiRecommendationLoader> createState() => _AiRecommendationLoaderState();
}

class _AiRecommendationLoaderState extends State<AiRecommendationLoader> {
  double _progress = 0.18;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted) return;
      setState(() {
        _progress = (_progress + 0.08).clamp(0.18, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final dark = p.isDark;
    final themeColor = p.inkDark;
    final loaderBg = p.pageBg;

    final steps = widget.isArabic
        ? const [
            'استقبل الطلب',
            'تحليل الحالة الصحية',
            'تحديد التخصص المطلوب',
            'مطابقة مقدمي الرعاية',
            'حساب نسبة التوافق',
            'ترتيب مقدمي الرعاية',
          ]
        : const [
            'Receiving Request',
            'Analyzing Health Condition',
            'Determining Required Specialization',
            'Matching Care Providers',
            'Calculating Compatibility Score',
            'Ranking Providers',
          ];

    return ColoredBox(
      color: loaderBg,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
          children: [
            SizedBox(
              height: 230,
              child: Image.asset(
                'assets/images/ai-robot.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Warning: Could not load assets/images/ai-robot.png');
                  return const Icon(
                    Icons.smart_toy_outlined,
                    size: 96,
                    color: AppColors.primary,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isArabic
                  ? 'نقارن حالتك مع مقدمي الرعاية المتاحين لاختيار الأنسب لك'
                  : 'We compare your case with available care providers to choose the best match.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dark ? Colors.blue[300] : AppColors.primary,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            ...steps.asMap().entries.map(
              (entry) {
                final idx = entry.key;
                final step = entry.value;
                final isDone = _progress >= (idx + 1) / 6.0;
                final isActive = _progress >= idx / 6.0 && _progress < (idx + 1) / 6.0;

                final Color iconBgColor = isDone
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : (isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent);
                final Widget leadingWidget = Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                    border: isDone ? null : Border.all(color: p.stroke),
                  ),
                  child: isDone
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.primary,
                        )
                      : (isActive
                          ? const Center(
                              child: SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                                ),
                              ),
                            )
                          : const SizedBox()),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Opacity(
                    opacity: isDone || isActive ? 1.0 : 0.5,
                    child: Row(
                      children: [
                        leadingWidget,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(
                              color: isActive ? AppColors.primary : themeColor,
                              fontSize: 15,
                              fontWeight: isActive || isDone ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isDone)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              widget.isArabic ? 'جاري التحليل...' : 'Analyzing...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dark ? Colors.blue[300] : AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 14,
                value: _progress,
                backgroundColor: p.stroke,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isArabic
                  ? 'قد يستغرق الأمر من 1 إلى 2 ثانية'
                  : 'This may take 1 to 2 seconds',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.inkMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

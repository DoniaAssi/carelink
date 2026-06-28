import os

filepath = r'lib/features/ai/widgets/ai_recommendation_loader.dart'

new_code = '''import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';

class AiRecommendationLoader extends StatefulWidget {
  const AiRecommendationLoader({super.key, this.isArabic = false});
  final bool isArabic;

  @override
  State<AiRecommendationLoader> createState() => _AiRecommendationLoaderState();
}

class _AiRecommendationLoaderState extends State<AiRecommendationLoader> with TickerProviderStateMixin {
  double _progress = 0.0;
  int _currentStepIndex = 0;

  late AnimationController _robotBreathing;
  late AnimationController _robotFloating;
  Timer? _masterTimer;

  final List<Map<String, String>> _arSteps = [
    {'title': 'فهم الحالة', 'subtitle': 'تم فهم تفاصيل الحالة بنجاح'},
    {'title': 'استخراج الاحتياج', 'subtitle': 'تم تحديد الاحتياج بدقة'},
    {'title': 'تحديد الخدمة المناسبة', 'subtitle': 'جاري تحديد أفضل خدمة لك'},
    {'title': 'مطابقة مقدمي الرعاية', 'subtitle': 'جاري البحث بين مقدمي الرعاية'},
    {'title': 'ترتيب النتائج', 'subtitle': 'جاري ترتيب النتائج حسب التوافق'},
  ];

  final List<Map<String, String>> _enSteps = [
    {'title': 'Understanding Case', 'subtitle': 'Case details successfully understood'},
    {'title': 'Extracting Needs', 'subtitle': 'Care needs precisely identified'},
    {'title': 'Determining Service', 'subtitle': 'Identifying the best service'},
    {'title': 'Matching Providers', 'subtitle': 'Searching among care providers'},
    {'title': 'Ranking Results', 'subtitle': 'Ranking results by compatibility'},
  ];

  @override
  void initState() {
    super.initState();
    _robotBreathing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _robotFloating = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    const totalDuration = 4500; // 4.5 seconds for analysis
    const tick = 50;
    int elapsed = 0;

    _masterTimer = Timer.periodic(const Duration(milliseconds: tick), (timer) {
      if (!mounted) return;
      elapsed += tick;
      setState(() {
        _progress = (elapsed / totalDuration).clamp(0.0, 1.0);
        
        if (_progress < 0.2) {
          _currentStepIndex = 0;
        } else if (_progress < 0.4) {
          _currentStepIndex = 1;
        } else if (_progress < 0.6) {
          _currentStepIndex = 2;
        } else if (_progress < 0.8) {
          _currentStepIndex = 3;
        } else {
          _currentStepIndex = 4;
        }
      });

      if (elapsed >= totalDuration) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _robotBreathing.dispose();
    _robotFloating.dispose();
    _masterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = widget.isArabic ? _arSteps : _enSteps;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thinking Robot
          Center(
            child: SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _robotBreathing,
                    builder: (context, child) {
                      return Container(
                        width: 140 + (_robotBreathing.value * 10),
                        height: 140 + (_robotBreathing.value * 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.05),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _robotFloating,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, -5 + (_robotFloating.value * 10)),
                        child: Image.asset(
                          'assets/images/ai_robot_illustration.png',
                          height: 120,
                          errorBuilder: (_, __, ___) => const Icon(Icons.psychology_rounded, size: 80, color: AppColors.primary),
                        ),
                      );
                    },
                  ),
                  Positioned(top: 20, left: 10, child: _buildOrbitingIcon(Icons.search_rounded)),
                  Positioned(bottom: 20, right: 10, child: _buildOrbitingIcon(Icons.monitor_heart_rounded)),
                  Positioned(top: 40, right: 10, child: _buildOrbitingIcon(Icons.psychology_rounded)),
                  Positioned(bottom: 40, left: 10, child: _buildOrbitingIcon(Icons.analytics_rounded)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Text(
            widget.isArabic ? 'جاري تحليل حالتك...' : 'Analyzing your case...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isArabic
                ? 'الذكاء الاصطناعي يعمل على فهم احتياجك واختيار أفضل مقدم رعاية مناسب.'
                : 'AI is working to understand your needs and choose the best care provider.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Progress Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isArabic ? 'التقدم الكلي' : 'Overall Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Timeline Stepper
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(steps.length, (index) {
                return _buildTimelineStep(
                  title: steps[index]['title']!,
                  subtitle: steps[index]['subtitle']!,
                  isActive: _currentStepIndex == index,
                  isCompleted: _currentStepIndex > index,
                  isLast: index == steps.length - 1,
                  scheme: scheme,
                );
              }),
            ),
          ),
          const SizedBox(height: 40),

          // Footer Time
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    widget.isArabic
                        ? 'الوقت المتوقع للانتهاء: 10 - 15 ثانية'
                        : 'Estimated time: 10 - 15 seconds',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOrbitingIcon(IconData icon) {
    return Icon(
      icon,
      color: AppColors.primary.withValues(alpha: 0.6),
      size: 20,
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
    required bool isLast,
    required ColorScheme scheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.primary
                    : (isActive ? AppColors.primary.withValues(alpha: 0.1) : scheme.surfaceContainerHighest),
                border: isActive ? Border.all(color: AppColors.primary, width: 2) : null,
              ),
              child: isCompleted
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : (isActive
                      ? const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : Icon(Icons.circle, color: scheme.onSurfaceVariant.withValues(alpha: 0.5), size: 8)),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isCompleted ? AppColors.primary : scheme.surfaceContainerHighest,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isActive || isCompleted ? FontWeight.w900 : FontWeight.w600,
                    color: isActive || isCompleted ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                  child: Text(title),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.primary : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  child: Text(subtitle),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
'''

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_code)
print("Updated ai_recommendation_loader.dart")

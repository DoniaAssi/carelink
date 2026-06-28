import os
import re

loader_path = r'lib/features/ai/widgets/ai_recommendation_loader.dart'
screen_path = r'lib/features/ai/screens/find_provider_screen.dart'

# 1. Update AiRecommendationLoader
loader_code = '''import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';

class AiRecommendationLoader extends StatefulWidget {
  const AiRecommendationLoader({super.key, this.isArabic = false});
  final bool isArabic;

  @override
  State<AiRecommendationLoader> createState() => _AiRecommendationLoaderState();
}

class _AiRecommendationLoaderState extends State<AiRecommendationLoader> with TickerProviderStateMixin {
  double _progress = 0.0;
  int _currentStepIndex = 0;
  int _currentMessageIndex = 0;
  bool _isSuccess = false;

  late AnimationController _robotBreathing;
  late AnimationController _robotFloating;
  late AnimationController _iconsOrbit;
  Timer? _masterTimer;
  Timer? _messageTimer;

  final List<String> _arSteps = [
    'استقبال الطلب',
    'تحليل الأعراض',
    'استخراج الكلمات المهمة',
    'تحديد الخدمة المناسبة',
    'مقارنة مقدمي الرعاية',
    'حساب نسبة التوافق',
    'ترتيب النتائج'
  ];

  final List<String> _enSteps = [
    'Receiving request',
    'Analyzing symptoms',
    'Extracting key terms',
    'Identifying required service',
    'Comparing care providers',
    'Calculating match score',
    'Ranking results'
  ];

  final List<String> _arMessages = [
    '🔍 تحليل الأعراض...',
    '🧠 فهم احتياجات الحالة...',
    '📊 مقارنة أكثر من 120 مقدم رعاية...',
    '📍 حساب المسافة...',
    '⭐ ترتيب النتائج...'
  ];

  final List<String> _enMessages = [
    '🔍 Analyzing symptoms...',
    '🧠 Understanding case needs...',
    '📊 Comparing over 120 providers...',
    '📍 Calculating distance...',
    '⭐ Ranking results...'
  ];

  @override
  void initState() {
    super.initState();
    _robotBreathing = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _robotFloating = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _iconsOrbit = AnimationController(vsync: this, duration: const Duration(milliseconds: 6000))..repeat();

    _messageTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!mounted) return;
      setState(() {
        _currentMessageIndex = (_currentMessageIndex + 1) % _arMessages.length;
      });
    });

    const totalDuration = 3700; // 3.7 seconds of loading
    const tick = 50;
    int elapsed = 0;

    _masterTimer = Timer.periodic(const Duration(milliseconds: tick), (timer) {
      if (!mounted) return;
      elapsed += tick;
      setState(() {
        if (elapsed >= totalDuration) {
          _progress = 1.0;
          _isSuccess = true;
          _currentStepIndex = _arSteps.length;
          timer.cancel();
          _messageTimer?.cancel();
        } else {
          _progress = elapsed / totalDuration;
          _currentStepIndex = (_progress * _arSteps.length).floor();
        }
      });
    });
  }

  @override
  void dispose() {
    _robotBreathing.dispose();
    _robotFloating.dispose();
    _iconsOrbit.dispose();
    _masterTimer?.cancel();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final dark = p.isDark;
    final themeColor = p.inkDark;
    
    final steps = widget.isArabic ? _arSteps : _enSteps;
    final messages = widget.isArabic ? _arMessages : _enMessages;

    return ColoredBox(
      color: p.pageBg,
      child: Stack(
        children: [
          // Background particles
          const Positioned.fill(child: CarelinkBackground()),
          
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              children: [
                _buildHero(),
                const SizedBox(height: 24),
                
                Text(
                  widget.isArabic ? 'يقوم الذكاء الاصطناعي بتحليل حالتك' : 'AI is analyzing your case',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isArabic ? 'يرجى الانتظار، يتم الآن اختيار أفضل مقدم رعاية لك.' : 'Please wait, selecting the best care provider for you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),

                // Premium Progress Card
                Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: p.stroke.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isSuccess)
                        _buildSuccessState()
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.isArabic ? 'نسبة التقدم' : 'Overall Progress',
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${(_progress * 100).toInt()}%',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Container(height: 10, color: p.stroke),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                height: 10,
                                width: MediaQuery.of(context).size.width * _progress,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.primary, AppColors.primaryDark],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isArabic ? 'حوالي 8 ثوانٍ' : 'Estimated time: ~8 seconds',
                          style: TextStyle(
                            color: p.inkMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        
                        // Steps
                        ...steps.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final isCompleted = idx < _currentStepIndex;
                          final isCurrent = idx == _currentStepIndex;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: (isCompleted || isCurrent) ? 1.0 : 0.4,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: isCompleted
                                      ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24)
                                      : (isCurrent
                                          ? const CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)
                                          : Icon(Icons.circle_outlined, color: p.stroke, size: 24)),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    entry.value,
                                    style: TextStyle(
                                      color: isCurrent ? AppColors.primary : themeColor,
                                      fontSize: 14,
                                      fontWeight: isCurrent || isCompleted ? FontWeight.w800 : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                if (!_isSuccess)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      messages[_currentMessageIndex],
                      key: ValueKey<int>(_currentMessageIndex),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, val, child) {
              return Transform.scale(
                scale: val,
                child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 72),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            widget.isArabic ? 'تم العثور على أفضل مقدم رعاية' : 'Best care provider found!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return AnimatedBuilder(
      animation: Listenable.merge([_robotBreathing, _robotFloating, _iconsOrbit]),
      builder: (context, child) {
        final floatOffset = math.sin(_robotFloating.value * 2 * math.pi) * 8;
        final scale = 1.0 + (_robotBreathing.value * 0.04);
        final orbitAngle = _iconsOrbit.value * 2 * math.pi;

        return SizedBox(
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glowing circular container
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.06),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              
              // Orbiting Icons
              _buildOrbitIcon(Icons.search_rounded, orbitAngle, 65),
              _buildOrbitIcon(Icons.health_and_safety_rounded, orbitAngle + (math.pi * 0.66), 65),
              _buildOrbitIcon(Icons.analytics_rounded, orbitAngle + (math.pi * 1.33), 65),

              // Robot Image
              Transform.translate(
                offset: Offset(0, floatOffset),
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    'assets/images/ai_robot_illustration.png',
                    fit: BoxFit.contain,
                    height: 100, // Reduced size by ~30%
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.smart_toy_rounded,
                      size: 70,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrbitIcon(IconData icon, double angle, double radius) {
    final x = math.cos(angle) * radius;
    final y = math.sin(angle) * radius;
    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 16),
      ),
    );
  }
}
'''

with open(loader_path, 'w', encoding='utf-8') as f:
    f.write(loader_code)

# 2. Update find_provider_screen.dart
with open(screen_path, 'r', encoding='utf-8') as f:
    screen_content = f.read()

# We need to replace the delay in _analyzeCase to ensure the loader gets 4.5 seconds
analyze_case_search = """    await Future<void>.delayed(const Duration(milliseconds: 2000));
    if (!mounted || !_aiRunning) return;

    final uid = _activeUserId ?? widget.userId ?? '';
    List<AIRecommendationResult> ranked = [];
    if (uid.isNotEmpty) {
      try {
        final payload = await _api.getProviderRecommendationsWithAnalysis(
          uid,
          query: _caseController.text.trim(),
        );"""

analyze_case_replace = """    final startTime = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || !_aiRunning) return;

    final uid = _activeUserId ?? widget.userId ?? '';
    List<AIRecommendationResult> ranked = [];
    if (uid.isNotEmpty) {
      try {
        final payload = await _api.getProviderRecommendationsWithAnalysis(
          uid,
          query: _caseController.text.trim(),
        );"""

screen_content = screen_content.replace(analyze_case_search, analyze_case_replace)

# Now we need to add the waiting logic after the API call finishes.
# The end of the try-catch block looks like this:
#       } catch (_) {
#         if (!mounted) return;
#         setState(() {
#           _fetchError = true;
#           _aiRunning = false;
#         });
#         return;
#       }
#     }
#
#     if (!mounted || !_aiRunning) return;
#
#     debugPrint('[AI_DEBUG] transition to results');

wait_logic_search = """      } catch (_) {
        if (!mounted) return;
        setState(() {
          _fetchError = true;
          _aiRunning = false;
        });
        return;
      }
    }

    if (!mounted || !_aiRunning) return;

    debugPrint('[AI_DEBUG] transition to results');"""

wait_logic_replace = """      } catch (_) {
        if (!mounted) return;
        setState(() {
          _fetchError = true;
          _aiRunning = false;
        });
        return;
      }
    }

    if (!mounted || !_aiRunning) return;

    // Ensure the premium loader gets exactly 4.5 seconds to show its full animation
    // including the 800ms success state at the end.
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 4500) - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    if (!mounted || !_aiRunning) return;

    debugPrint('[AI_DEBUG] transition to results');"""

screen_content = screen_content.replace(wait_logic_search, wait_logic_replace)

with open(screen_path, 'w', encoding='utf-8') as f:
    f.write(screen_content)

print("Files updated successfully.")

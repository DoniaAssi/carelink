import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';

/// Full-screen overlay messaging used while the hybrid scorer ranks providers.
class AiRecommendationLoader extends StatefulWidget {
  const AiRecommendationLoader({super.key});

  @override
  State<AiRecommendationLoader> createState() => _AiRecommendationLoaderState();
}

class _AiRecommendationLoaderState extends State<AiRecommendationLoader> {
  static const _lines = [
    'Analyzing your request…',
    'Checking medical compatibility…',
    'Ranking best providers…',
  ];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() => _i = (_i + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.92),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AiFlowTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              _lines[_i],
              key: ValueKey(_lines[_i]),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AiFlowTheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

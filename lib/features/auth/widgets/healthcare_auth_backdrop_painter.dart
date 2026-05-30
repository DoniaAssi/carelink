import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';

/// Soft healthcare waves + faint grid — shared by login and signup.
class HealthcareAuthBackdropPainter extends CustomPainter {
  HealthcareAuthBackdropPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final base = isDark ? const Color(0xFF03181F) : AppColors.background;
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        radius: 1.15,
        colors: [
          base,
          isDark ? const Color(0xFF05242D) : const Color(0xFFF5FBFA),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 56 : 48
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary.withValues(alpha: isDark ? 0.07 : 0.09);

    final p1 = Path()
      ..moveTo(-40, size.height * 0.18)
      ..cubicTo(
        size.width * 0.25,
        -20,
        size.width * 0.45,
        size.height * 0.42,
        size.width + 60,
        size.height * 0.06,
      );
    canvas.drawPath(p1, wave);

    final wave2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 48 : 40
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primaryDark.withValues(alpha: isDark ? 0.08 : 0.07);

    final p2 = Path()
      ..moveTo(size.width * 0.12, size.height + 56)
      ..cubicTo(
        size.width * 0.4,
        size.height * 0.68,
        size.width * 0.72,
        size.height * 0.92,
        size.width + 72,
        size.height * 0.48,
      );
    canvas.drawPath(p2, wave2);

    final dotPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.05);
    const step = 28.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        if (((x ~/ step) + (y ~/ step)) % 3 == 0) {
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant HealthcareAuthBackdropPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

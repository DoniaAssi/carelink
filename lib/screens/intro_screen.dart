import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:carelink/features/auth/login_screen.dart';

import '../core/app_colors.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final orbitalSize = math.min(
              size.width * 0.9,
              math.min(420.0, constraints.maxHeight * 0.53),
            );

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text(
                            'CARE\nLINK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              height: 0.95,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Get instant AI-powered health insights,\nbook trusted providers, and manage your care journey anywhere.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontSize: 16,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildGetStartedButton(context),
                          const SizedBox(height: 30),
                          Center(
                            child: SizedBox(
                              width: orbitalSize,
                              height: orbitalSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: orbitalSize * 0.86,
                                    height: orbitalSize * 0.86,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: orbitalSize * 0.62,
                                    height: orbitalSize * 0.62,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: orbitalSize * 0.32,
                                    height: orbitalSize * 0.32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.45,
                                        ),
                                        width: 3,
                                      ),
                                      image: const DecorationImage(
                                        image: AssetImage(
                                          'lib/assets/images/doctorportrait.jpg',
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  _buildOrbitAvatar(
                                    radius: orbitalSize * 0.43,
                                    angleDegrees: -28,
                                    size: orbitalSize * 0.19,
                                    imagePath:
                                        'lib/assets/images/nursemedical.jpg',
                                  ),
                                  _buildOrbitAvatar(
                                    radius: orbitalSize * 0.43,
                                    angleDegrees: 42,
                                    size: orbitalSize * 0.18,
                                    imagePath: 'lib/assets/images/medicine.jpg',
                                  ),
                                  _buildOrbitAvatar(
                                    radius: orbitalSize * 0.43,
                                    angleDegrees: 102,
                                    size: orbitalSize * 0.17,
                                    imagePath:
                                        'lib/assets/images/healthcare.jpg',
                                  ),
                                  _buildOrbitAvatar(
                                    radius: orbitalSize * 0.43,
                                    angleDegrees: 162,
                                    size: orbitalSize * 0.18,
                                    imagePath:
                                        'lib/assets/images/patientcare.jpg',
                                  ),
                                  _buildOrbitAvatar(
                                    radius: orbitalSize * 0.43,
                                    angleDegrees: 222,
                                    size: orbitalSize * 0.19,
                                    imagePath: 'lib/assets/images/image.jpg',
                                  ),
                                  _buildOrbitIcon(
                                    radius: orbitalSize * 0.34,
                                    angleDegrees: -90,
                                    size: orbitalSize * 0.12,
                                    icon: Icons.favorite_border,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGetStartedButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Get Started',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrbitAvatar({
    required double radius,
    required double angleDegrees,
    required double size,
    required String imagePath,
  }) {
    final angle = angleDegrees * (math.pi / 180);
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildOrbitIcon({
    required double radius,
    required double angleDegrees,
    required double size,
    required IconData icon,
  }) {
    final angle = angleDegrees * (math.pi / 180);
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryDark,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

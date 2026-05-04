import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/intro_tokens.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/features/auth/login_screen.dart';

/// Diameter of the hub–spoke diagram: ~90% width, cap by height; reference = large centerpiece.
double _orbitDiameter(double w, double h) {
  final byW = w * 0.90;
  final byH = h * 0.50;
  return math.min(byW, byH * 1.05).clamp(300.0, 452.0);
}

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  static const List<_OrbitFeature> _features = [
    _OrbitFeature(
      title: 'intro.aiInsights',
      subtitle: 'intro.aiInsightsSubtitle',
      imageAsset: 'assets/images/healthcare.jpg',
      icon: Icons.psychology_outlined,
    ),
    _OrbitFeature(
      title: 'intro.findProviders',
      subtitle: 'intro.findProvidersSubtitle',
      imageAsset: 'assets/images/nursemedical.jpg',
      icon: Icons.person_search_outlined,
    ),
    _OrbitFeature(
      title: 'intro.medications',
      subtitle: 'intro.medicationsSubtitle',
      imageAsset: 'assets/images/medicine.jpg',
      icon: Icons.medication_outlined,
    ),
    _OrbitFeature(
      title: 'intro.healthRecords',
      subtitle: 'intro.healthRecordsSubtitle',
      imageAsset: 'assets/images/patientcare.jpg',
      icon: Icons.description_outlined,
    ),
    _OrbitFeature(
      title: 'intro.labTests',
      subtitle: 'intro.labTestsSubtitle',
      imageAsset: 'assets/images/image2.jpg',
      icon: Icons.science_outlined,
    ),
    _OrbitFeature(
      title: 'intro.consultOnline',
      subtitle: 'intro.consultOnlineSubtitle',
      imageAsset: 'assets/images/image.jpg',
      icon: Icons.chat_bubble_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = _IntroTheme.of(context);
    final topPad = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: t.pageBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: t.backgroundGradient,
                stops: const [0.0, 0.28, 0.62, 1.0],
              ),
            ),
            child: Stack(
              children: [
                _BackgroundDecoration(width: w, height: h, topSafe: topPad),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SafeArea(
                        bottom: false,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _TopHeader(),
                              SizedBox(height: h * 0.04),
                              const _IntroHeadline(),
                              const SizedBox(height: 12),
                              Text(
                                context.tr('intro.subtitle'),
                                style: IntroTokens.t(
                                  size: 15,
                                  weight: FontWeight.w300,
                                  color: t.mutedText,
                                  height: 1.5,
                                  letter: 0.2,
                                ),
                              ),
                              const SizedBox(height: 28),
                              _GetStartedCta(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: math.max(20, h * 0.034)),
                              Center(
                                child: _OrbitShowcase(
                                  size: _orbitDiameter(w, h),
                                  features: _features,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(top: false, child: const _BottomBar()),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IntroTheme {
  const _IntroTheme({
    required this.isDark,
    required this.pageBg,
    required this.surface,
    required this.surfaceSoft,
    required this.stroke,
    required this.text,
    required this.mutedText,
    required this.accent,
    required this.accentEnd,
    required this.ctaText,
    required this.ctaIconColor,
    required this.bottomBar,
    required this.backgroundGradient,
  });

  final bool isDark;
  final Color pageBg;
  final Color surface;
  final Color surfaceSoft;
  final Color stroke;
  final Color text;
  final Color mutedText;
  final Color accent;
  final Color accentEnd;
  final Color ctaText;
  final Color ctaIconColor;
  final Color bottomBar;
  final List<Color> backgroundGradient;

  factory _IntroTheme.of(BuildContext context) {
    final p = CarelinkPalette.of(context);
    if (p.isDark) {
      return _IntroTheme(
        isDark: true,
        pageBg: p.pageBg,
        surface: p.surface,
        surfaceSoft: p.surfaceSoft,
        stroke: p.stroke,
        text: p.inkDark,
        mutedText: p.inkMuted,
        accent: AppColors.primary,
        accentEnd: const Color(0xFF2DD4E8),
        ctaText: Colors.white,
        ctaIconColor: AppColors.primaryDark,
        bottomBar: p.navBackground,
        backgroundGradient: [
          p.pageBg,
          p.headerDeep,
          p.headerSoft.withValues(alpha: 0.72),
          p.pageBg,
        ],
      );
    }

    return _IntroTheme(
      isDark: false,
      pageBg: p.pageBg,
      surface: p.surface,
      surfaceSoft: p.surfaceSoft,
      stroke: p.stroke,
      text: p.inkDark,
      mutedText: p.inkMuted,
      accent: AppColors.primary,
      accentEnd: AppColors.primaryDark,
      ctaText: Colors.white,
      ctaIconColor: AppColors.primaryDark,
      bottomBar: p.surface,
      backgroundGradient: [p.pageBg, p.surface, p.surfaceSoft, p.pageBg],
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    final t = _IntroTheme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final heart = (w * 0.11).clamp(42.0, 52.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CarelinkBrandLogo(
          height: (heart * 0.92).clamp(40.0, 56.0),
          fallbackTextColor: t.text,
          forceDarkLogo: t.isDark,
        ),
        const Spacer(),
        Flexible(child: _TrustPill(compact: w < 360)),
      ],
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = _IntroTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: t.isDark ? 0.78 : 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: compact ? 15 : 17,
            height: compact ? 15 : 17,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: t.text,
                  size: compact ? 15 : 17,
                ),
                Icon(Icons.check, size: compact ? 7.5 : 8, color: t.text),
              ],
            ),
          ),
          SizedBox(width: compact ? 4 : 5),
          Flexible(
            child: Text(
              context.tr('intro.trustPill'),
              textAlign: TextAlign.end,
              maxLines: 2,
              style: IntroTokens.t(
                size: compact ? 8.5 : 10.5,
                weight: FontWeight.w500,
                color: t.text,
                height: 1.2,
                letter: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroHeadline extends StatelessWidget {
  const _IntroHeadline();

  @override
  Widget build(BuildContext context) {
    final t = _IntroTheme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    // Reference: large bold white; second line: "connected."
    final fontSize = (w * 0.09).clamp(32.0, 38.0);
    final base = IntroTokens.t(
      size: fontSize,
      weight: FontWeight.w800,
      color: t.text,
      height: 1.1,
      letter: -0.3,
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '${context.tr('intro.headline1')}\n'),
          TextSpan(text: context.tr('intro.headline2')),
        ],
      ),
    );
  }
}

class _GetStartedCta extends StatelessWidget {
  const _GetStartedCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = _IntroTheme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    // مضمون تخطيط: عرض ≈٤٤–٥٨٪ من المساحة داخل الـ padding — أصغر من «ملء العرض».
    final btnWidth = (w - 40).clamp(220.0, 272.0);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: btnWidth,
            height: 50,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [t.accent, t.accentEnd],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: t.ctaIconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('intro.getStarted'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IntroTokens.t(
                        size: 16,
                        weight: FontWeight.w700,
                        color: t.ctaText,
                        letter: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitShowcase extends StatelessWidget {
  const _OrbitShowcase({required this.size, required this.features});

  final double size;
  final List<_OrbitFeature> features;

  @override
  Widget build(BuildContext context) {
    // Reference: large doctor hub (~36–40% of diagram), nodes ~64–80px, ring through node centers
    final t = _IntroTheme.of(context);
    final centerSize = (size * 0.38).clamp(120.0, 152.0);
    final imageSize = (size * 0.198).clamp(66.0, 80.0);
    final orbitRadius = (centerSize * 0.5 + imageSize * 0.5 + size * 0.045)
        .clamp(size * 0.33, size * 0.41);

    // Space below for labels of bottom satellites (avoids visual clip)
    final paintSize = size;
    const labelBand = 1.2;

    return SizedBox(
      width: size,
      height: paintSize * labelBand,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: SizedBox(
              width: size,
              height: paintSize,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size * 0.88,
                    height: size * 0.88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.surface.withValues(alpha: t.isDark ? 0.12 : 0.5),
                    ),
                  ),
                  Container(
                    width: size * 0.62,
                    height: size * 0.62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.accent.withValues(alpha: t.isDark ? 0.11 : 0.14),
                    ),
                  ),
                  CustomPaint(
                    size: Size(paintSize, paintSize),
                    painter: _DashedCirclePainter(
                      radius: orbitRadius,
                      color: t.mutedText.withValues(alpha: 0.62),
                    ),
                  ),
                  // Decorative heart on ring (12 o’clock)
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, -orbitRadius - 2),
                      child: Icon(Icons.favorite, size: 12, color: t.text),
                    ),
                  ),
                  // Center doctor (hero)
                  Container(
                    width: centerSize,
                    height: centerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: t.surface, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      image: const DecorationImage(
                        image: AssetImage('assets/images/doctorportrait.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  for (int i = 0; i < features.length; i++)
                    _OrbitItem(
                      feature: features[i],
                      index: i,
                      total: features.length,
                      radius: orbitRadius,
                      imageSize: imageSize,
                      parentSize: paintSize,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitItem extends StatelessWidget {
  const _OrbitItem({
    required this.feature,
    required this.index,
    required this.total,
    required this.radius,
    required this.imageSize,
    required this.parentSize,
  });

  final _OrbitFeature feature;
  final int index;
  final int total;
  final double radius;
  final double imageSize;
  final double parentSize;

  @override
  Widget build(BuildContext context) {
    final t = _IntroTheme.of(context);
    final angle = (-35 + index * (360 / total)) * math.pi / 180;
    final x = radius * math.cos(angle);
    final y = radius * math.sin(angle);

    return Transform.translate(
      offset: Offset(x, y),
      child: SizedBox(
        width: imageSize * 2.05,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.surface, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: DecorationImage(
                      image: AssetImage(feature.imageAsset),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: t.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.accent.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(feature.icon, size: 17, color: t.ctaIconColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                style: IntroTokens.t(size: 10.5, color: t.text, height: 1.3),
                children: [
                  TextSpan(
                    text: context.tr(feature.title),
                    style: IntroTokens.t(
                      size: 10.5,
                      weight: FontWeight.w800,
                      color: t.text,
                    ),
                  ),
                  TextSpan(
                    text: ' / ',
                    style: IntroTokens.t(
                      size: 10.5,
                      weight: FontWeight.w400,
                      color: t.mutedText,
                    ),
                  ),
                  TextSpan(
                    text: context.tr(feature.subtitle),
                    style: IntroTokens.t(
                      size: 10.5,
                      weight: FontWeight.w400,
                      color: t.mutedText,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitFeature {
  const _OrbitFeature({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String imageAsset;
  final IconData icon;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    final t = _IntroTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: t.bottomBar,
        border: Border(top: BorderSide(color: t.stroke)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _BottomItem(
                leading: const _ShieldLockIcon(),
                title: context.tr('intro.securePrivate'),
                subtitle: context.tr('intro.securePrivateSubtitle'),
              ),
            ),
            const _BarDivider(),
            Expanded(
              child: _BottomItem(
                icon: Icons.bolt_outlined,
                title: context.tr('intro.aiPowered'),
                subtitle: context.tr('intro.aiPoweredSubtitle'),
              ),
            ),
            const _BarDivider(),
            Expanded(
              child: _BottomItem(
                icon: Icons.public_outlined,
                title: context.tr('intro.anywhereAccess'),
                subtitle: context.tr('intro.anywhereAccessSubtitle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShieldLockIcon extends StatelessWidget {
  const _ShieldLockIcon();

  @override
  Widget build(BuildContext context) {
    final t = _IntroTheme.of(context);
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 26, color: t.text),
          Icon(Icons.lock_outline_rounded, size: 11, color: t.text),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.title,
    required this.subtitle,
    this.icon,
    this.leading,
  }) : assert(
         (icon == null) != (leading == null),
         'Provide either icon or leading',
       );

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = _IntroTheme.of(context);
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Center(
              child: leading ?? Icon(icon!, size: 23, color: t.text),
            ),
          ),
          SizedBox(width: isArabic ? 6 : 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: IntroTokens.t(
                    size: isArabic ? 10 : 11,
                    weight: FontWeight.w700,
                    color: t.text,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: IntroTokens.t(
                    size: isArabic ? 7.8 : 8.5,
                    weight: FontWeight.w300,
                    color: t.mutedText,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarDivider extends StatelessWidget {
  const _BarDivider();

  @override
  Widget build(BuildContext context) {
    final t = _IntroTheme.of(context);
    return VerticalDivider(width: 1, thickness: 1, color: t.stroke);
  }
}

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration({
    required this.width,
    required this.height,
    required this.topSafe,
  });

  final double width;
  final double height;
  final double topSafe;

  @override
  Widget build(BuildContext context) {
    final t = _IntroTheme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -width * 0.22,
          top: height * 0.18,
          child: _blob(context, width * 0.55),
        ),
        Positioned(
          left: -width * 0.25,
          bottom: height * 0.13,
          child: _blob(context, width * 0.45),
        ),
        // Soft organic highlight (reference: bottom-right curve)
        Positioned(
          right: -width * 0.12,
          bottom: -height * 0.06,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.18,
              child: Container(
                width: width * 0.52,
                height: width * 0.52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent,
                ),
              ),
            ),
          ),
        ),
        Positioned(right: 12, top: topSafe + 8, child: const _DotGrid()),
      ],
    );
  }

  Widget _blob(BuildContext context, double size) {
    return IgnorePointer(
      child: Opacity(
        opacity: 1,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _IntroTheme.of(context).surface.withValues(alpha: 0.34),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _DotGrid extends StatelessWidget {
  const _DotGrid();

  @override
  Widget build(BuildContext context) {
    final light = _IntroTheme.of(context).accent.withValues(alpha: 0.55);
    return Opacity(
      opacity: 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(9, (r) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (c) {
                return Padding(
                  padding: EdgeInsets.only(left: c == 0 ? 0.0 : 3),
                  child: Container(
                    width: 2.5,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: light,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    const dash = 7.0;
    const gap = 6.0;
    final circumference = 2 * math.pi * radius;
    final count = circumference ~/ (dash + gap);

    for (int i = 0; i < count; i++) {
      final start = i * (dash + gap) / radius;
      final end = start + dash / radius;

      final path = Path();
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        end - start,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.color != color;
  }
}

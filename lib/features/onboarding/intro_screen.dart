import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/intro_tokens.dart';
import 'package:carelink/features/auth/login_screen.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

/// Animated mobile splash. Auto-navigates to login after a 6 s branded
/// sequence. Keeps the CareLink doctor image, feature circles and green brand
/// identity. Animation timeline:
///   0.0-1.0 s : background blobs appear
///   1.0-2.0 s : CareLink logo fades in
///   2.0-3.5 s : hero doctor image scales and fades in
///   3.5-4.8 s : four floating feature bubbles appear
///   4.8-5.4 s : tagline and loading indicator fade in
///   5.4-6.0 s : splash fades out, then login fades in
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  // Primary sequence runs for 5.4 seconds, followed by a 0.6 second exit.
  late final AnimationController _intro;

  // Floating-bob loop controller (keeps ticking while splash is visible).
  late final AnimationController _float;

  // Exit fade-out controller that plays just before navigation.
  late final AnimationController _exit;

  late final Animation<double> _logoFade;
  late final Animation<double> _badgeFade;
  late final Animation<double> _heroScale;
  late final Animation<double> _heroFade;
  // Four separate fade animations – one per floating bubble.
  late final List<Animation<double>> _bubbleFades;
  late final Animation<double> _textFade;

  Timer? _navTimer;

  // ── Total durations ────────────────────────────────────────────────
  static const int _introDurationMs = 5400;
  static const int _exitDurationMs = 600;
  static const int _navAfterMs = _introDurationMs + _exitDurationMs;

  // The four medical features that float around the hero (existing assets).
  static const List<_SplashFeature> _features = [
    _SplashFeature(
      titleKey: 'intro.aiInsights',
      imageAsset: 'assets/images/healthcare.jpg',
      icon: Icons.auto_awesome_rounded,
      align: Alignment(-0.98, -0.72),
    ),
    _SplashFeature(
      titleKey: 'intro.findProviders',
      imageAsset: 'assets/images/nursemedical.jpg',
      icon: Icons.person_search_rounded,
      align: Alignment(0.98, -0.72),
    ),
    _SplashFeature(
      titleKey: 'intro.healthRecords',
      imageAsset: 'assets/images/patientcare.jpg',
      icon: Icons.folder_shared_rounded,
      align: Alignment(-0.98, 0.72),
    ),
    _SplashFeature(
      titleKey: 'intro.labTests',
      imageAsset: 'assets/images/image2.jpg',
      icon: Icons.science_rounded,
      align: Alignment(0.98, 0.72),
    ),
  ];

  @override
  void initState() {
    super.initState();

    // ── Main intro sequence ──────────────────────────────────────────
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _introDurationMs),
    );

    // ── Smooth floating-bob loop ─────────────────────────────────────
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // ── Exit fade-out ────────────────────────────────────────────────
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _exitDurationMs),
    );

    _logoFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.1852, 0.3704, curve: Curves.easeOut),
    );

    _badgeFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.2037, 0.3889, curve: Curves.easeOut),
    );

    _heroFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.3704, 0.6481, curve: Curves.easeOut),
    );
    _heroScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.3704, 0.6481, curve: Curves.easeOutBack),
      ),
    );

    _bubbleFades = List.generate(4, (i) {
      final start = 0.6481 + i * 0.0556;
      final end = (start + 0.0833).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _intro,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _textFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.8889, 1.0, curve: Curves.easeOut),
    );

    // ── Kick off sequence ────────────────────────────────────────────
    _intro.forward();

    // Begin exit fade when intro is done, then navigate.
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _exit.forward();
      }
    });
    _navTimer = Timer(const Duration(milliseconds: _navAfterMs), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        settings: const RouteSettings(name: '/login'),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _intro.dispose();
    _float.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _SplashTheme.of(context);

    return AnimatedBuilder(
      animation: _exit,
      builder: (context, child) {
        // Fade the entire screen out as the exit animation plays.
        return Opacity(
          opacity: (1.0 - _exit.value).clamp(0.0, 1.0),
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: t.pageBg,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: t.backgroundGradient,
              stops: const [0.0, 0.42, 1.0],
            ),
          ),
          child: Stack(
            children: [
              _SoftBlobs(accent: t.accent),
              const PositionedDirectional(
                top: 8,
                end: 8,
                child: SafeArea(
                  child: PatientHeaderActions(color: AppColors.primary),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final diagram = math.min(
                      c.maxWidth * 0.84,
                      c.maxHeight * 0.46,
                    );
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── Top: logo (0.8 s–1.6 s) ──────────────────
                          FadeTransition(
                            opacity: _logoFade,
                            child: CarelinkBrandLogo(
                              height: 40,
                              fallbackTextColor: t.text,
                              forceDarkLogo: t.isDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Trust badge appears just after logo.
                          FadeTransition(
                            opacity: _badgeFade,
                            child: _TrustBadge(t: t),
                          ),

                          // ── Center: hero image (1.6 s–2.8 s) ─────────
                          Expanded(
                            child: Center(
                              child: FadeTransition(
                                opacity: _heroFade,
                                child: ScaleTransition(
                                  scale: _heroScale,
                                  child: _HeroShowcase(
                                    t: t,
                                    diagram: diagram.clamp(260.0, 380.0),
                                    features: _features,
                                    float: _float,
                                    // Pass individual bubble animations so
                                    // they can appear staggered (2.8–3.8 s).
                                    bubbleFades: _bubbleFades,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ── Bottom: tagline (3.8 s–4.8 s) ────────────
                          FadeTransition(
                            opacity: _textFade,
                            child: Column(
                              children: [
                                _Headline(t: t),
                                const SizedBox(height: 12),
                                Text(
                                  context.tr('intro.subtitle'),
                                  textAlign: TextAlign.center,
                                  style: IntroTokens.t(
                                    size: 14,
                                    weight: FontWeight.w400,
                                    color: t.mutedText,
                                    height: 1.5,
                                    letter: 0.1,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      t.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Theme ─────────────────────────────

class _SplashTheme {
  const _SplashTheme({
    required this.isDark,
    required this.pageBg,
    required this.surface,
    required this.stroke,
    required this.text,
    required this.mutedText,
    required this.accent,
    required this.accentEnd,
    required this.backgroundGradient,
  });

  final bool isDark;
  final Color pageBg;
  final Color surface;
  final Color stroke;
  final Color text;
  final Color mutedText;
  final Color accent;
  final Color accentEnd;
  final List<Color> backgroundGradient;

  factory _SplashTheme.of(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final accent = AppColors.primary;
    if (p.isDark) {
      return _SplashTheme(
        isDark: true,
        pageBg: p.pageBg,
        surface: p.surface,
        stroke: p.stroke,
        text: p.inkDark,
        mutedText: p.inkMuted,
        accent: accent,
        accentEnd: const Color(0xFF2DD4E8),
        backgroundGradient: [
          p.pageBg,
          Color.alphaBlend(accent.withValues(alpha: 0.10), p.pageBg),
          p.pageBg,
        ],
      );
    }
    return _SplashTheme(
      isDark: false,
      pageBg: p.pageBg,
      surface: p.surface,
      stroke: p.stroke,
      text: p.inkDark,
      mutedText: p.inkMuted,
      accent: accent,
      accentEnd: AppColors.primaryDark,
      // Soft green gradient tones.
      backgroundGradient: [
        Color.alphaBlend(accent.withValues(alpha: 0.05), p.pageBg),
        Color.alphaBlend(accent.withValues(alpha: 0.12), p.surface),
        Color.alphaBlend(accent.withValues(alpha: 0.04), p.pageBg),
      ],
    );
  }
}

// ─────────────────────────── Trust badge ──────────────────────────

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.t});

  final _SplashTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: t.isDark ? 0.7 : 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 15, color: t.accent),
          const SizedBox(width: 6),
          Text(
            context.tr('intro.trustPill'),
            style: IntroTokens.t(
              size: 11.5,
              weight: FontWeight.w700,
              color: t.text,
              letter: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Headline ─────────────────────────────

class _Headline extends StatelessWidget {
  const _Headline({required this.t});

  final _SplashTheme t;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final size = (w * 0.085).clamp(28.0, 34.0);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${context.tr('intro.headline1')} ',
            style: IntroTokens.t(
              size: size,
              weight: FontWeight.w800,
              color: t.text,
              height: 1.15,
              letter: -0.3,
            ),
          ),
          TextSpan(
            text: context.tr('intro.headline2'),
            style: IntroTokens.t(
              size: size,
              weight: FontWeight.w800,
              color: t.accent,
              height: 1.15,
              letter: -0.3,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ─────────────────────── Hero glass showcase ──────────────────────

class _HeroShowcase extends StatelessWidget {
  const _HeroShowcase({
    required this.t,
    required this.diagram,
    required this.features,
    required this.float,
    required this.bubbleFades,
  });

  final _SplashTheme t;
  final double diagram;
  final List<_SplashFeature> features;
  final Animation<double> float;

  /// Individual opacity animations for each floating bubble (staggered).
  final List<Animation<double>> bubbleFades;

  @override
  Widget build(BuildContext context) {
    final heroSize = diagram * 0.46;
    final bubbleSize = diagram * 0.22;

    return SizedBox(
      width: diagram,
      height: diagram,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Soft concentric green halo.
          Container(
            width: diagram * 0.9,
            height: diagram * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: t.isDark ? 0.08 : 0.10),
            ),
          ),
          // Glassmorphism card behind the hero.
          ClipRRect(
            borderRadius: BorderRadius.circular(diagram * 0.16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: diagram * 0.72,
                height: diagram * 0.72,
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: t.isDark ? 0.18 : 0.55),
                  borderRadius: BorderRadius.circular(diagram * 0.16),
                  border: Border.all(
                    color: t.surface.withValues(alpha: t.isDark ? 0.25 : 0.7),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: t.accent.withValues(alpha: 0.16),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Hero doctor image (existing asset).
          Container(
            width: heroSize,
            height: heroSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.surface, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
              image: const DecorationImage(
                image: AssetImage('assets/images/doctorportrait.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Floating feature bubbles – each fades in individually (staggered).
          for (int i = 0; i < features.length; i++)
            Align(
              alignment: features[i].align,
              child: FadeTransition(
                opacity: bubbleFades[i],
                child: _FeatureBubble(
                  t: t,
                  feature: features[i],
                  size: bubbleSize.clamp(54.0, 78.0),
                  float: float,
                  phase: i * (math.pi / 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureBubble extends StatelessWidget {
  const _FeatureBubble({
    required this.t,
    required this.feature,
    required this.size,
    required this.float,
    required this.phase,
  });

  final _SplashTheme t;
  final _SplashFeature feature;
  final double size;
  final Animation<double> float;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: float,
      builder: (context, child) {
        final dy = math.sin(float.value * 2 * math.pi + phase) * 5.0;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.surface, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
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
              PositionedDirectional(
                end: -2,
                bottom: -2,
                child: Container(
                  width: size * 0.42,
                  height: size * 0.42,
                  decoration: BoxDecoration(
                    color: t.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: t.accent.withValues(alpha: 0.5),
                      width: 1.4,
                    ),
                  ),
                  child: Icon(feature.icon, size: size * 0.24, color: t.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            context.tr(feature.titleKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: IntroTokens.t(
              size: 9.5,
              weight: FontWeight.w700,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashFeature {
  const _SplashFeature({
    required this.titleKey,
    required this.imageAsset,
    required this.icon,
    required this.align,
  });

  final String titleKey;
  final String imageAsset;
  final IconData icon;
  final Alignment align;
}

// ────────────────────── Background decoration ─────────────────────

class _SoftBlobs extends StatelessWidget {
  const _SoftBlobs({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            right: -size.width * 0.28,
            top: size.height * 0.06,
            child: _blob(size.width * 0.6, accent.withValues(alpha: 0.10)),
          ),
          Positioned(
            left: -size.width * 0.3,
            bottom: size.height * 0.08,
            child: _blob(size.width * 0.55, accent.withValues(alpha: 0.08)),
          ),
        ],
      ),
    );
  }

  Widget _blob(double d, Color color) {
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Intro / cover — Inter, reference palette: #004D4D → #003333 bg, CTA #4DB6AC → #26A69A, white #FFF.
abstract final class IntroTokens {
  // Background (spec: #004D4D → #003333 deep teal)
  static const Color pageTealA = Color(0xFF004D4D);
  static const Color pageTealB = Color(0xFF003D3D);
  static const Color pageDeep = Color(0xFF003333);
  static const Color pageDeepAlt = Color(0xFF003838);

  // Dots + satellite emphasis (subtle; headline body is all white in reference)
  static const Color headlineAccent = Color(0xFFFFFFFF);
  static const Color accentAlt = Color(0xFF4DB6AC);

  // Legacy label (kept for satellite badge border)
  static const Color iconMint = Color(0xFF80CBC4);
  static const Color iconMintBright = Color(0xFFA7FFEB);

  // Typography
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFC8D6DB);

  // Pinned bottom bar: dark teal, not glassy
  static const Color barBg = Color(0xFF002A2A);
  static const Color glassBarFill = Color(0xFF002A2A);
  static const Color glassBarBorder = Color(0x1AFFFFFF);
  // Trust pill: slightly darker than main bg
  static const Color trustPillBg = Color(0xFF003333);

  // Logo + CTA: medical + on heart
  static const Color logoCross = Color(0xFF4DB6AC);
  // Arrow on CTA: contrasting teal
  static const Color ctaArrow = Color(0xFF00695C);
  // "Get Started" (spec: #4DB6AC → #26A69A)
  static const Color ctaFill = Color(0xFF4DB6AC);
  static const Color ctaFillEnd = Color(0xFF26A69A);

  // Gradient bottom stop
  static const Color coverBottom = Color(0xFF002626);

  /// Inter — matches reference “Inter / Poppins / Montserrat” stack.
  static TextStyle t({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double? letter,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color ?? textOnDark,
      height: height,
      letterSpacing: letter,
    );
  }
}

import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';

/// Organic blobs + corner dot accent (matches [IntroScreen] hero decoration).
class CarelinkBrandBackdropLayer extends StatelessWidget {
  const CarelinkBrandBackdropLayer({
    super.key,
    required this.width,
    required this.height,
    required this.topSafe,
  });

  final double width;
  final double height;
  final double topSafe;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -width * 0.22,
          top: height * 0.18,
          child: _Blob(size: width * 0.55, color: p.surface),
        ),
        Positioned(
          left: -width * 0.25,
          bottom: height * 0.13,
          child: _Blob(size: width * 0.45, color: p.surface),
        ),
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
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: topSafe + 8,
          child: const _IntroDotGrid(),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 1,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.34),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _IntroDotGrid extends StatelessWidget {
  const _IntroDotGrid();

  @override
  Widget build(BuildContext context) {
    final light =
        AppColors.primary.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.42 : 0.55);
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

import 'package:flutter/material.dart';

import 'package:carelink/core/carelink_brand_surfaces.dart';
import 'package:carelink/shared/widgets/carelink_brand_backdrop.dart';

/// Login / registration: same gradient + blob layer as [IntroScreen] (content stacks on top).
class CarelinkAuthBrandedShell extends StatelessWidget {
  const CarelinkAuthBrandedShell({
    super.key,
    required this.child,
    this.includeBackdropDecoration = true,
  });

  final Widget child;
  final bool includeBackdropDecoration;

  @override
  Widget build(BuildContext context) {
    final topSafe = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        CarelinkBrandPageGradient(
          expandChild: true,
          child: includeBackdropDecoration
              ? LayoutBuilder(
                  builder: (context, c) => CarelinkBrandBackdropLayer(
                    width: c.maxWidth,
                    height: c.maxHeight,
                    topSafe: topSafe,
                  ),
                )
              : const SizedBox.expand(),
        ),
        child,
      ],
    );
  }
}

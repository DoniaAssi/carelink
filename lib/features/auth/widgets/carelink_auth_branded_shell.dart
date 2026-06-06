import 'package:flutter/material.dart';

class CarelinkAuthBrandedShell extends StatelessWidget {
  const CarelinkAuthBrandedShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: child,
        ),
      ),
    );
  }
}

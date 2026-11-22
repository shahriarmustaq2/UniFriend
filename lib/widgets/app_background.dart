import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Near-black backdrop with two faint glows, so the glass cards have something
/// to sit on. Radial gradients rather than blurred shadows, which keeps it cheap
/// on low-end phones.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.backgroundTop, AppColors.background],
              stops: [0, 0.55],
            ),
          ),
        ),
        _glow(const Alignment(-1.1, -1.05), 1.1, AppColors.primary, 0.20),
        _glow(const Alignment(1.2, 0.9), 0.9, AppColors.cyan, 0.08),
        child,
      ],
    );
  }

  Widget _glow(Alignment center, double radius, Color color, double alpha) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

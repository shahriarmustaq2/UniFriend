import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Solid midnight background with soft glowing circles and ring shapes.
/// Intended to sit behind the translucent glass surfaces.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.midnight),
        _buildGlow(
          alignment: Alignment.topLeft,
          size: 300,
          color: AppColors.electricBlue,
          dx: -80,
          dy: -90,
        ),
        _buildGlow(
          alignment: Alignment.topRight,
          size: 220,
          color: AppColors.cyan,
          dx: 50,
          dy: -70,
        ),
        _buildGlow(
          alignment: Alignment.centerRight,
          size: 260,
          color: AppColors.periwinkle,
          dx: 60,
          dy: 0,
        ),
        _buildGlow(
          alignment: Alignment.bottomLeft,
          size: 280,
          color: AppColors.electricBlue,
          dx: -90,
          dy: 60,
        ),
        _buildGlow(
          alignment: Alignment.bottomRight,
          size: 200,
          color: AppColors.cyan,
          dx: 40,
          dy: 80,
        ),
        Align(
          alignment: const Alignment(0.85, -0.15),
          child: Transform.rotate(
            angle: -0.3,
            child: _buildRing(size: 140),
          ),
        ),
        Align(
          alignment: const Alignment(-0.8, 0.55),
          child: Transform.translate(
            offset: const Offset(0, 40),
            child: _buildRing(size: 100),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildGlow({
    required Alignment alignment,
    required double size,
    required Color color,
    required double dx,
    required double dy,
  }) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.10),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.30),
                blurRadius: size / 2,
                spreadRadius: size / 5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRing({double size = 120}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 2,
        ),
      ),
    );
  }
}
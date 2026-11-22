import 'package:flutter/material.dart';

/// Thin horizontal progress bar. [fraction] is clamped to 0..1.
class MeterBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;

  const MeterBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(
            height: height,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
            child: Container(height: height, color: color),
          ),
        ],
      ),
    );
  }
}

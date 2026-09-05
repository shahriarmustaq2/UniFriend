import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A lightweight glass surface for the dark theme.
///
/// Uses a small blur with a dark translucent tint (no white frosted wash),
/// so the decorative background shapes stay visible behind it.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? blur;
  final double opacity;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? tint;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur,
    this.opacity = AppColors.glassOpacity,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding = EdgeInsets.zero,
    this.tint = AppColors.glassTint,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur ?? AppColors.glassBlur,
          sigmaY: blur ?? AppColors.glassBlur,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? AppColors.glassTint).withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
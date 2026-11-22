import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's glass surface.
///
/// By default it is a translucent tint with a faint top-lit gradient and a
/// hairline edge, which reads as glass over the dark background and costs
/// nothing to draw. Pass [frosted] for surfaces that float above scrolling
/// content, such as the nav bar and sheets: those blur what is behind them.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? blur;
  final double opacity;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final bool frosted;

  /// Tints the edge, for a card that should stand out (a warning, a highlight).
  final Color? borderColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur,
    this.opacity = AppColors.glassOpacity,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding = EdgeInsets.zero,
    this.tint = AppColors.glassTint,
    this.frosted = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final base = (tint ?? AppColors.glassTint).withValues(alpha: opacity);
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: base,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.045), base),
            base,
          ],
        ),
        border: Border.all(
          color: borderColor?.withValues(alpha: 0.45) ?? AppColors.hairline,
          width: 1,
        ),
      ),
      child: child,
    );

    if (!frosted && blur == null) {
      return ClipRRect(borderRadius: borderRadius, child: surface);
    }
    final sigma = blur ?? AppColors.glassBlur;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: surface,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Floating add button matched to the dark glass surfaces.
///
/// This is a complete widget rather than a child of [FloatingActionButton],
/// so the tap target and the ripple are not nested inside the parent's
/// gesture handling.
class GlassFab extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const GlassFab({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryMedium, AppColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: tooltip,
        onPressed: onPressed,
        tooltip: tooltip,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: Colors.transparent,
        shape: const CircleBorder(),
        child: Icon(icon, color: AppColors.midnight, size: 26),
      ),
    );
  }
}

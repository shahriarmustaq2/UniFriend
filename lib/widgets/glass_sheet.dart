import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'glass_container.dart';

/// Chrome shared by every "add / edit" sheet: rounded glass panel, drag
/// handle, title row with a close button and a scrolling body.
class GlassSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  const GlassSheet({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: GlassContainer(
          frosted: true,
          tint: AppColors.surfaceRaised,
          opacity: 0.92,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 14, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(child: SingleChildScrollView(child: child)),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (final action in actions) ...[
                      Expanded(child: action),
                      if (action != actions.last) const SizedBox(width: 12),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [builder] in a [GlassSheet], lifting the panel above the on-screen
/// keyboard.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // Above the shell, so the floating nav bar cannot cover the sheet.
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (context) => Padding(
      // viewInsets.bottom is what makes the sheet sit above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}

/// Full-width primary action styled like the rest of the app's buttons.
class SheetAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isBusy;
  final bool isDestructive;

  /// A quieter button, for the second choice beside a primary one.
  final bool isSecondary;

  const SheetAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.isDestructive = false,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;
    final background = isDestructive
        ? AppColors.error.withValues(alpha: 0.14)
        : isSecondary
        ? Colors.white.withValues(alpha: 0.06)
        : AppColors.primary.withValues(alpha: enabled ? 1 : 0.4);
    final foreground = isDestructive
        ? AppColors.error
        : isSecondary
        ? AppColors.textPrimary
        : AppColors.midnight;

    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: isBusy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: AppColors.midnight,
                  strokeWidth: 2.2,
                ),
              )
            : Icon(icon ?? Icons.check_rounded, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background,
          disabledForegroundColor: foreground.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isDestructive
                ? BorderSide(color: AppColors.error.withValues(alpha: 0.4))
                : isSecondary
                ? const BorderSide(color: AppColors.hairline)
                : BorderSide.none,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

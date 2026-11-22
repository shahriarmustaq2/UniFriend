import 'package:flutter/material.dart';

import '../data/errors.dart';
import '../theme/app_colors.dart';

/// Runs a mutation and turns any failure into a snackbar, so no screen has to
/// wrap every button in its own try/catch.
///
/// Returns [T] on success. [T] should be `void` for the common case; pass a
/// non-void [T] when the caller needs to know the outcome, such as a swipe to
/// delete that must only stay dismissed if the row was really removed. On
/// failure the default [T] is returned instead of throwing.
Future<T> runAction<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? successMessage,
}) async {
  try {
    final result = await action();
    if (successMessage != null && context.mounted) {
      showGlassSnack(context, successMessage, icon: Icons.check_circle_rounded);
    }
    return result;
  } catch (error) {
    if (!context.mounted) return _fallback<T>();
    showGlassSnack(
      context,
      readableError(error),
      icon: Icons.error_outline_rounded,
      isError: true,
    );
    return _fallback<T>();
  }
}

/// A safe "nothing" for [T]. Never reached for `void` callers, where the
/// returned value is discarded.
T _fallback<T>() {
  if (T == bool) return false as T;
  if (T == int) return 0 as T;
  if (T == double) return 0.0 as T;
  if (T == String) return '' as T;
  if (null is T) return null as T;
  if (T == List<Object?>) return <Never>[] as T;
  throw StateError('runAction<$T> needs an explicit fallback');
}

void showGlassSnack(
  BuildContext context,
  String message, {
  IconData icon = Icons.info_outline_rounded,
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isError ? AppColors.error : AppColors.primaryMedium,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFF3A1520)
            : AppColors.surfaceRaised,
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: isError ? 3500 : 2200),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError
                ? AppColors.error.withValues(alpha: 0.4)
                : AppColors.hairline,
          ),
        ),
      ),
    );
}

/// Yes/no dialog for destructive actions. Returns false when dismissed.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(color: Colors.white70, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? AppColors.error : AppColors.primaryMedium,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

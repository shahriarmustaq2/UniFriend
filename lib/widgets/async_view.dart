import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/errors.dart';
import '../theme/app_colors.dart';
import 'glass_container.dart';

/// Renders an [AsyncValue] without every screen repeating the same
/// loading/error/data switch.
class AsyncView<T> extends ConsumerWidget {
  final AsyncValue<T> value;

  /// Receives the resolved data plus the surrounding [BuildContext], so
  /// builders can navigate without reaching for another `context`.
  final Widget Function(BuildContext context, T data) builder;

  /// Supply `() => ref.invalidate(someProvider)` so the error placeholder can
  /// offer a retry. When omitted the button is hidden.
  final VoidCallback? onRetry;

  /// Vertical padding used by the loading and error placeholders.
  final double placeholderPadding;

  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.placeholderPadding = 36,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      data: (data) => builder(context, data),
      loading: () => LoadingBlock(padding: placeholderPadding),
      error: (error, _) => ErrorBlock(
        message: readableError(error),
        onRetry: onRetry,
        padding: placeholderPadding,
      ),
    );
  }
}

/// Neutral glass block with a spinner, used while a list loads for the first
/// time. Subsequent refreshes keep showing data instead (see `when`'s default
/// `skipLoadingOnRefresh`).
class LoadingBlock extends StatelessWidget {
  final double padding;

  const LoadingBlock({super.key, this.padding = 36});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.symmetric(vertical: padding),
      child: const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            color: AppColors.cyan,
            strokeWidth: 2.4,
          ),
        ),
      ),
    );
  }
}

class ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final double padding;

  const ErrorBlock({
    super.key,
    required this.message,
    this.onRetry,
    this.padding = 36,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: AppColors.error.withValues(alpha: 0.6),
            size: 30,
          ),
          const SizedBox(height: 12),
          Text(
            'Could not load this',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

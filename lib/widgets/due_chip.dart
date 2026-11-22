import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/date_utils.dart';

/// Small pill showing how urgent a deadline is, tinted by [DueStatus].
class DueChip extends StatelessWidget {
  final DueInfo info;
  final bool dense;

  const DueChip({super.key, required this.info, this.dense = false});

  static Color colorFor(DueStatus status) => switch (status) {
    DueStatus.overdue => AppColors.error,
    DueStatus.today => AppColors.warning,
    DueStatus.soon => AppColors.orange,
    DueStatus.later => AppColors.cyan,
    DueStatus.done => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(info.status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: dense ? 10 : 12, color: color),
          const SizedBox(width: 4),
          Text(
            info.label,
            style: TextStyle(
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

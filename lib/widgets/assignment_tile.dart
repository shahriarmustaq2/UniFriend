import 'package:flutter/material.dart';

import '../models/assignment.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import 'due_chip.dart';
import 'glass_container.dart';

/// One deadline row. The circle on the left toggles completion; tapping the
/// body opens the editor.
class AssignmentTile extends StatelessWidget {
  final Assignment assignment;

  /// Course code shown under the title.
  final String? courseLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;

  const AssignmentTile({
    super.key,
    required this.assignment,
    required this.onToggle,
    this.courseLabel,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final due = AppDate.describe(
      assignment.dueDate,
      isCompleted: assignment.isCompleted,
    );

    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        children: [
          RoundCheck(done: assignment.isCompleted, onTap: onToggle),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: assignment.isCompleted
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.white,
                      decoration: assignment.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (courseLabel != null) ...[
                        Text(
                          courseLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(child: DueChip(info: due, dense: true)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A round tick box that pops its tick in when checked.
class RoundCheck extends StatelessWidget {
  final bool done;
  final ValueChanged<bool> onTap;

  const RoundCheck({super.key, required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(!done),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.success.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: done
                  ? AppColors.success
                  : Colors.white.withValues(alpha: 0.28),
              width: 1.5,
            ),
          ),
          child: AnimatedScale(
            // Runs on every change of `done`, not just on first mount, so the
            // tick pops in when the student completes an item.
            scale: done ? 1 : 0.4,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: done ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(
                Icons.check_rounded,
                size: 15,
                color: AppColors.success,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/study_plan.dart';
import '../providers/course_providers.dart';
import '../providers/study_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import 'assignment_tile.dart';
import 'feedback.dart';
import 'glass_container.dart';

/// One planned topic, with a tick box. Shows "from Tue" when it carried over.
class StudyTaskTile extends ConsumerWidget {
  final StudyTask task;
  final VoidCallback? onTap;

  const StudyTaskTile({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = task.courseId == null
        ? null
        : ref.watch(courseByIdProvider)[task.courseId];
    final today = AppDate.dayOf(DateTime.now());
    final carried = !task.isDone && task.plannedFor.isBefore(today);
    final later = task.plannedFor.isAfter(today);

    final meta = [
      ?course?.code,
      if (carried) 'from ${AppDate.weekdayShort(task.plannedFor.weekday)}',
      if (later) AppDate.weekdayDayMonth(task.plannedFor),
    ];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            RoundCheck(
              done: task.isDone,
              onTap: (done) => runAction(
                context,
                () => ref
                    .read(studyTaskListProvider.notifier)
                    .setDone(task.id, done),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: task.isDone
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AppColors.textHint,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta.join('  ·  '),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: carried ? AppColors.warning : AppColors.textHint,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An upcoming exam: days left, and how many of its topics are done.
class ExamTile extends ConsumerWidget {
  final Exam exam;
  final VoidCallback? onTap;

  const ExamTile({super.key, required this.exam, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = exam.courseId == null
        ? null
        : ref.watch(courseByIdProvider)[exam.courseId];
    final (done, total) = ref.watch(examProgressProvider(exam.id));
    final days = exam.daysLeft();
    final color = days <= 1
        ? AppColors.error
        : days <= 3
        ? AppColors.warning
        : AppColors.primaryMedium;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    days <= 0 ? '0' : '$days',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: color,
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                  Text(
                    days == 1 ? 'day' : 'days',
                    style: TextStyle(fontSize: 10, color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      ?course?.code,
                      exam.kind.label,
                      days == 0
                          ? 'Today'
                          : AppDate.weekdayDayMonth(exam.heldOn),
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (total > 0)
              Text(
                '$done/$total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: done == total
                      ? AppColors.success
                      : AppColors.textSecondary,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Counts up from [startedAt], refreshing once a second.
class ElapsedText extends StatefulWidget {
  final DateTime startedAt;
  final TextStyle style;

  const ElapsedText({super.key, required this.startedAt, required this.style});

  @override
  State<ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<ElapsedText> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final safe = elapsed.isNegative ? Duration.zero : elapsed;
    String two(int n) => n.toString().padLeft(2, '0');
    final text = safe.inHours > 0
        ? '${safe.inHours}:${two(safe.inMinutes % 60)}:${two(safe.inSeconds % 60)}'
        : '${two(safe.inMinutes)}:${two(safe.inSeconds % 60)}';
    return Text(
      text,
      style: widget.style.copyWith(fontFeatures: AppTheme.tabular),
    );
  }
}

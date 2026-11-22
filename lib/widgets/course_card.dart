import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course.dart';
import '../providers/assignment_providers.dart';
import '../providers/attendance_providers.dart';
import '../providers/results_providers.dart';
import '../theme/app_colors.dart';
import '../utils/grades.dart';
import 'attendance_card.dart';
import 'glass_container.dart';

/// Course row: code badge, title, kind and credits, attendance and the grade.
class CourseCard extends ConsumerWidget {
  final Course course;
  final VoidCallback? onTap;

  /// Labels an attempt that a retake replaced.
  final bool superseded;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.superseded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grade = ref.watch(courseGradeProvider(course.id));
    final attendance = ref.watch(attendanceSummaryForCourseProvider(course.id));
    final open = ref.watch(openAssignmentCountForCourseProvider(course.id));

    final meta = <(String, Color)>[
      (
        '${course.kind.label} · ${course.creditsLabel} cr',
        AppColors.textSecondary,
      ),
      if (attendance.percent != null)
        (
          '${attendance.percent!.toStringAsFixed(0)}% att.',
          attendanceColor(attendance),
        ),
      if (open > 0) ('$open due', AppColors.warning),
      if (course.classesEndedOn != null) ('Ended', AppColors.textHint),
      if (superseded) ('Retaken', AppColors.textHint),
    ];

    final card = GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      child: Row(
        children: [
          CodeBadge(code: course.code, sessional: course.isSessional),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      for (var i = 0; i < meta.length; i++) ...[
                        if (i > 0)
                          const TextSpan(
                            text: '  ·  ',
                            style: TextStyle(color: AppColors.textHint),
                          ),
                        TextSpan(
                          text: meta[i].$1,
                          style: TextStyle(color: meta[i].$2),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GradeBadge(grade: grade),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textHint,
            ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

class CodeBadge extends StatelessWidget {
  final String code;
  final bool sessional;

  const CodeBadge({super.key, required this.code, this.sessional = false});

  @override
  Widget build(BuildContext context) {
    final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
    final letters = code.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final label = digits.isNotEmpty
        ? digits.substring(max(0, digits.length - 4))
        : (letters.isEmpty
              ? '?'
              : letters.substring(0, min(3, letters.length)));
    final color = sessional ? AppColors.cyan : AppColors.primary;

    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: label.length > 3 ? 12 : 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }
}

class GradeBadge extends StatelessWidget {
  final CourseGrade grade;

  const GradeBadge({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = switch (grade.points) {
      null => AppColors.textHint,
      0 => AppColors.error,
      final p when p >= 3.75 => AppColors.gold,
      _ => AppColors.success,
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 38),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        gradeLetter(grade.points),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

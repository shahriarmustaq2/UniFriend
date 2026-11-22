import 'package:flutter/material.dart';

import '../models/course.dart';
import '../theme/app_colors.dart';
import '../utils/attendance.dart';
import 'glass_container.dart';
import 'meter_bar.dart';

/// Red under the target, amber exactly on it, green above it.
Color attendanceColor(AttendanceSummary summary) {
  final percent = summary.percent;
  if (percent == null) return AppColors.textSecondary;
  if (!summary.meetsTarget()) return AppColors.error;
  return percent == kAttendanceTargetPercent
      ? AppColors.warning
      : AppColors.success;
}

/// One line about the courses under the attendance target, naming the ones so
/// low they would have to be registered again.
String attendanceWarning(List<Course> below, List<Course> toRegister) {
  String codes(Iterable<Course> courses) =>
      courses.map((c) => c.code).join(', ');
  final others = below.where((c) => !toRegister.contains(c));
  if (toRegister.isEmpty) return 'Attendance under target in ${codes(below)}';
  final register =
      'Under $kAttendanceRegisterBelowPercent% in ${codes(toRegister)}: '
      'registration needed';
  return others.isEmpty
      ? register
      : '$register. Under target in ${codes(others)}';
}

/// What the student should do about their attendance, in plain words.
String attendanceAdvice(AttendanceSummary summary) {
  if (summary.total == 0) return 'No classes marked yet';
  if (summary.mustRegister) {
    final needed = summary.classesNeeded(kAttendanceRegisterBelowPercent);
    return 'Under $kAttendanceRegisterBelowPercent%: you would have to register '
        'for this course again. Attend the next $needed '
        '${needed == 1 ? 'class' : 'classes'} to reach '
        '$kAttendanceRegisterBelowPercent%';
  }
  if (!summary.meetsTarget()) {
    final needed = summary.classesNeeded();
    return 'Attend the next $needed ${needed == 1 ? 'class' : 'classes'} '
        'to reach $kAttendanceTargetPercent%';
  }
  final spare = summary.canMiss();
  if (spare == 0) {
    return 'Missing the next class would put you under '
        '$kAttendanceTargetPercent%';
  }
  return 'You can miss $spare ${spare == 1 ? 'class' : 'classes'} '
      'and stay above $kAttendanceTargetPercent%';
}

/// One course's attendance: percentage, bar, counts and advice.
class AttendanceCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final AttendanceSummary summary;
  final VoidCallback? onTap;

  const AttendanceCard({
    super.key,
    required this.title,
    required this.summary,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = attendanceColor(summary);
    final percent = summary.percent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  percent == null ? '--' : '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MeterBar(fraction: (percent ?? 0) / 100, color: color),
            const SizedBox(height: 10),
            Text(
              '${summary.present} present  ·  ${summary.late} late  ·  '
              '${summary.absent} absent',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              attendanceAdvice(summary),
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

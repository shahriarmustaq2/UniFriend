import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/attendance_record.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/course_providers.dart';
import '../../providers/results_providers.dart';
import '../../providers/semester_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/async_view.dart';
import '../../widgets/attendance_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_fab.dart';
import 'attendance_editor_sheet.dart';

/// Attendance for the semester shown on the Semester tab, course by course.
class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(attendanceListProvider);
    final semester = ref.watch(viewedSemesterProvider);
    final courses = ref.watch(coursesInSemesterProvider(semester?.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: GlassFab(
        tooltip: 'Mark attendance',
        onPressed: () => showAttendanceEditor(context),
      ),
      body: AsyncView<List<AttendanceRecord>>(
        value: records,
        onRetry: () => ref.invalidate(attendanceListProvider),
        builder: (context, _) {
          if (courses.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              children: const [
                EmptyState(
                  icon: Icons.fact_check_outlined,
                  accent: AppColors.green,
                  title: 'No courses yet',
                  message: 'Add a course, and its attendance will appear here.',
                ),
              ],
            );
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
            children: [
              AttendanceCard(
                title: semester?.name ?? 'Overall',
                subtitle:
                    'Across its courses. Cancelled classes are not counted.',
                summary: ref.watch(semesterAttendanceProvider(semester?.id)),
              ),
              const SizedBox(height: 22),
              for (final course in courses) ...[
                AttendanceCard(
                  title: course.code,
                  subtitle: course.title,
                  summary: ref.watch(
                    attendanceSummaryForCourseProvider(course.id),
                  ),
                  onTap: () => showAttendanceHistory(context, course.id),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

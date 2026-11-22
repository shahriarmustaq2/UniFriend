import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/course.dart';
import '../../models/semester.dart';
import '../../providers/course_providers.dart';
import '../../providers/results_providers.dart';
import '../../providers/semester_providers.dart';
import '../../providers/sync_providers.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../widgets/async_view.dart';
import '../../widgets/attendance_card.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/course_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_fab.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';
import '../courses/course_editor_sheet.dart';
import 'semester_sheets.dart';

/// One semester at a glance: its GPA so far, attendance, links to the marks
/// table and results, and its courses.
class SemesterScreen extends ConsumerWidget {
  const SemesterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semesters = ref.watch(semesterListProvider);
    final semester = ref.watch(viewedSemesterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: semester == null
          ? null
          : GlassFab(
              tooltip: 'New course',
              onPressed: () =>
                  showCourseEditor(context, semesterId: semester.id),
            ),
      body: AsyncView<List<Semester>>(
        value: semesters,
        onRetry: () => ref.invalidate(semesterListProvider),
        builder: (context, list) {
          if (list.isEmpty || semester == null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              children: [
                EmptyState(
                  icon: Icons.school_outlined,
                  accent: AppColors.primary,
                  title: 'Start with your semester',
                  message:
                      'Add the semester you are in and the day classes start. '
                      'Then add its courses here.',
                  actionLabel: 'Add semester',
                  onAction: () => showSemesterEditor(context),
                ),
              ],
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceRaised,
            onRefresh: () => refreshAll(ref),
            child: _SemesterBody(semester: semester, all: list),
          );
        },
      ),
    );
  }
}

class _SemesterBody extends ConsumerWidget {
  final Semester semester;
  final List<Semester> all;

  const _SemesterBody({required this.semester, required this.all});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesInSemesterProvider(semester.id));
    final gpa = ref.watch(semesterGpaProvider(semester.id));
    final cgpa = ref.watch(cgpaProvider);
    final attendance = ref.watch(semesterAttendanceProvider(semester.id));
    final superseded = ref.watch(supersededCourseIdsProvider);
    final current = ref.watch(currentSemesterProvider);
    final calendar = ref.watch(calendarLookupProvider)(semester.id);
    final week = calendar.weekNumber(DateTime.now());
    final vacation = calendar.vacationOn(DateTime.now());
    final below = semester.id == current?.id
        ? ref.watch(coursesBelowAttendanceTargetProvider)
        : const <Course>[];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      children: [
        _SemesterPicker(viewed: semester, all: all, currentId: current?.id),
        const SizedBox(height: 14),
        Text(
          semester.hasEnded
              ? 'Classes ended ${AppDate.dayMonthYear(semester.classesEndedOn!)}'
              : vacation != null
              ? '${vacation.title.isEmpty ? 'Vacation' : vacation.title} until '
                    '${AppDate.dayMonth(vacation.endsOn)}  ·  week $week paused'
              : week == null
              ? 'Classes start ${AppDate.weekdayDayMonth(semester.startsOn)}'
              : 'Week $week  ·  started ${AppDate.dayMonth(semester.startsOn)}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.auto_graph_rounded,
                accent: AppColors.primary,
                value: gpa?.toStringAsFixed(2) ?? '--',
                label: 'Semester GPA',
                onTap: () => context.go(AppRoutes.results),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: Icons.workspace_premium_rounded,
                accent: AppColors.gold,
                value: cgpa?.toStringAsFixed(2) ?? '--',
                label: 'CGPA',
                onTap: () => context.go(AppRoutes.results),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: Icons.fact_check_rounded,
                accent: attendanceColor(attendance),
                value: attendance.percent == null
                    ? '--'
                    : '${attendance.percent!.toStringAsFixed(0)}%',
                label: 'Attendance',
                onTap: () => context.go(AppRoutes.attendance),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LinkCard(
                icon: Icons.table_chart_rounded,
                color: AppColors.cyan,
                title: 'Marks',
                subtitle: 'Enter marks or grades',
                onTap: () => context.go(AppRoutes.marks),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LinkCard(
                icon: Icons.quiz_rounded,
                color: AppColors.pink,
                title: 'CT marks',
                subtitle: 'Class tests',
                onTap: () => context.go(AppRoutes.ctMarks),
              ),
            ),
          ],
        ),
        if (below.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassContainer(
            borderRadius: BorderRadius.circular(16),
            borderColor: AppColors.error,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    attendanceWarning(
                      below,
                      ref.watch(coursesToRegisterProvider),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 26),
        SectionHeader(
          icon: Icons.menu_book_rounded,
          title: 'Courses  ·  ${courses.length}',
          actionLabel: 'Add',
          onAction: () => showCourseEditor(context, semesterId: semester.id),
        ),
        const SizedBox(height: 10),
        if (courses.isEmpty)
          EmptyState(
            icon: Icons.menu_book_outlined,
            accent: AppColors.primary,
            title: 'No courses yet',
            message:
                'Add each theory and sessional course of ${semester.name}.',
            actionLabel: 'Add a course',
            onAction: () => showCourseEditor(context, semesterId: semester.id),
          )
        else
          for (final course in courses) ...[
            CourseCard(
              course: course,
              superseded: superseded.contains(course.id),
              onTap: () => context.go(AppRoutes.courseDetail(course.id)),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _SemesterPicker extends ConsumerWidget {
  final Semester viewed;
  final List<Semester> all;
  final String? currentId;

  const _SemesterPicker({
    required this.viewed,
    required this.all,
    required this.currentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final semester in all.reversed) ...[
            ChoicePill(
              label: semester.name,
              icon: semester.id == currentId ? Icons.star_rounded : null,
              selected: semester.id == viewed.id,
              onTap: () => ref
                  .read(viewedSemesterIdProvider.notifier)
                  .show(semester.id == currentId ? null : semester.id),
            ),
            const SizedBox(width: 8),
          ],
          ChoicePill(
            label: 'Manage',
            icon: Icons.tune_rounded,
            selected: false,
            color: AppColors.textSecondary,
            onTap: () => context.go(AppRoutes.semesters),
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
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

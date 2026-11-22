import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/errors.dart';
import '../../models/assignment.dart';
import '../../models/course.dart';
import '../../providers/assignment_providers.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/course_providers.dart';
import '../../providers/ct_mark_providers.dart';
import '../../providers/results_providers.dart';
import '../../providers/routine_providers.dart';
import '../../providers/semester_providers.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../utils/grades.dart';
import '../../utils/marks.dart';
import '../../widgets/action_row.dart';
import '../../widgets/assignment_tile.dart';
import '../../widgets/async_view.dart';
import '../../widgets/attendance_card.dart';
import '../../widgets/ct_course_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_fab.dart';
import '../attendance/attendance_editor_sheet.dart';
import '../ct_marks/ct_mark_editor_sheet.dart';
import '../routine/class_slot_editor_sheet.dart';
import '../semester/mark_entry_sheet.dart';
import 'assignment_editor_sheet.dart';
import 'course_editor_sheet.dart';
import 'grade_picker_sheet.dart';

class CourseDetailScreen extends ConsumerWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(courseListProvider);

    return courses.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(padding: EdgeInsets.all(20), child: LoadingBlock()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorBlock(
            message: readableError(error),
            onRetry: () => ref.invalidate(courseListProvider),
          ),
        ),
      ),
      data: (items) {
        final course = items.where((c) => c.id == courseId).firstOrNull;
        if (course == null) {
          // The course was deleted while this screen was still open.
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.search_off_rounded,
                accent: AppColors.blue,
                title: 'Course not found',
                message: 'It looks like this course was deleted.',
                actionLabel: 'Back to semester',
                onAction: () => context.go(AppRoutes.semester),
              ),
            ),
          );
        }
        return _CourseDetailBody(course: course);
      },
    );
  }
}

class _CourseDetailBody extends ConsumerWidget {
  final Course course;

  const _CourseDetailBody({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(assignmentsForCourseProvider(course.id));
    final notifier = ref.read(assignmentListProvider.notifier);
    final attendance = ref.watch(attendanceSummaryForCourseProvider(course.id));
    final marks = ref.watch(ctMarksForCourseProvider(course.id));
    final slots = ref.watch(slotsForCourseProvider(course.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: GlassFab(
        tooltip: 'New assignment',
        onPressed: () => showAssignmentEditor(context, courseId: course.id),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        children: [
          _CourseHeader(course: course),
          const SizedBox(height: 14),
          _ResultCard(course: course),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Attendance',
            actionLabel: 'Makeup class',
            onAction: () => showAttendanceEditor(context, courseId: course.id),
          ),
          const SizedBox(height: 10),
          AttendanceCard(
            title: 'Classes attended',
            summary: attendance,
            onTap: () => showAttendanceHistory(context, course.id),
          ),
          if (!course.isSessional) ...[
            const SizedBox(height: 24),
            _SectionTitle(
              title: 'CT marks',
              actionLabel: 'Add a mark',
              onAction: () => showCtMarkEditor(context, courseId: course.id),
            ),
            const SizedBox(height: 10),
            if (marks.isEmpty)
              const _Note('No class tests recorded yet.')
            else
              CtCourseCard(
                title: 'Class tests',
                marks: marks,
                onTapMark: (mark) => showCtMarkEditor(context, mark: mark),
              ),
          ],
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Classes',
            actionLabel: 'Add class',
            onAction: () => showClassSlotEditor(
              context,
              weekday: DateTime.now().weekday,
              courseId: course.id,
            ),
          ),
          const SizedBox(height: 10),
          if (slots.isEmpty)
            const _Note('Not in your routine yet.')
          else
            GlassContainer(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (final slot in slots) ...[
                    InkWell(
                      onTap: () => showClassSlotEditor(
                        context,
                        weekday: slot.weekday,
                        slot: slot,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                AppDate.weekdayShort(slot.weekday),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                [
                                  slot.timeLabel,
                                  ?slot.room,
                                  if (slot.isAlternate) 'every other week',
                                ].join('  ·  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (slot != slots.last) const RowDivider(),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Assignments  ·  ${assignments.length}',
            actionLabel: 'Add',
            onAction: () => showAssignmentEditor(context, courseId: course.id),
          ),
          const SizedBox(height: 10),
          if (assignments.isEmpty)
            const _Note('Nothing due for this course.')
          else
            for (final assignment in assignments) ...[
              _SwipeToDeleteAssignment(
                assignment: assignment,
                onToggle: (value) => runAction(
                  context,
                  () => notifier.toggleCompleted(assignment.id, value),
                ),
                onEdit: () => showAssignmentEditor(
                  context,
                  courseId: course.id,
                  assignment: assignment,
                ),
                onConfirmDelete: () =>
                    _deleteAssignment(context, ref, assignment),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  /// Returns true once the row is really gone, so `Dismissible` can finish the
  /// swipe. Cancelling returns false and the tile slides back into place.
  Future<bool> _deleteAssignment(
    BuildContext context,
    WidgetRef ref,
    Assignment assignment,
  ) async {
    final confirmed = await confirm(
      context,
      title: 'Delete assignment?',
      message: '"${assignment.title}" will be removed for good.',
    );
    if (!confirmed || !context.mounted) return false;

    return await runAction<bool>(context, () async {
      await ref.read(assignmentListProvider.notifier).delete(assignment.id);
      return true;
    }, successMessage: 'Assignment deleted');
  }
}

/// Deletes a course after asking, and leaves its page.
Future<void> deleteCourse(
  BuildContext context,
  WidgetRef ref,
  Course course,
) async {
  final confirmed = await confirm(
    context,
    title: 'Delete ${course.code}?',
    message:
        'Its classes, attendance, marks and assignments go with it. Study '
        'time logged for it is kept.',
  );
  if (!confirmed || !context.mounted) return;
  final router = GoRouter.of(context);
  final ok = await runAction<bool>(context, () async {
    await ref.read(courseListProvider.notifier).remove(course.id);
    return true;
  }, successMessage: '${course.code} deleted');
  if (ok) router.go(AppRoutes.semester);
}

class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}

/// The grade, where it came from, and the marks part by part.
class _ResultCard extends ConsumerWidget {
  final Course course;

  const _ResultCard({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ref.watch(markSheetProvider(course.id));
    final grade = ref.watch(courseGradeProvider(course.id));
    if (sheet == null) return const SizedBox.shrink();

    final points = grade.points;
    final caption = switch (grade.source) {
      GradeSource.direct => 'Grade entered directly',
      GradeSource.marks => 'From ${formatMark(sheet.total)} marks',
      GradeSource.none =>
        '${formatMark(sheet.total)} so far  ·  ${formatMark(sheet.outstanding)} to come',
    };
    final next = grade.source == GradeSource.none
        ? null
        : marksToNextGrade(sheet.total);

    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RESULT',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      points == null
                          ? 'Not graded yet'
                          : '${gradeLetter(points)}  ·  ${points.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: points == null
                            ? AppColors.textSecondary
                            : grade.source == GradeSource.direct
                            ? AppColors.gold
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => showGradePicker(context, course: course),
                child: Text(
                  grade.source == GradeSource.direct ? 'Change' : 'Set grade',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final line in sheet.lines)
            InkWell(
              onTap: () =>
                  showMarkEntry(context, course: course, part: line.part),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.part.label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (line.source == MarkSource.auto)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Text(
                          'auto',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.cyan,
                          ),
                        ),
                      ),
                    Text(
                      '${line.value == null ? '—' : formatMark(line.value!)}'
                      ' / ${formatMark(line.weight)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: line.value == null
                            ? AppColors.textHint
                            : AppColors.textPrimary,
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (next != null && grade.source == GradeSource.marks) ...[
            const SizedBox(height: 6),
            Text(
              '${formatMark(next)} more marks would have reached the next grade.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textHint),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(actionLabel),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseHeader extends ConsumerWidget {
  final Course course;

  const _CourseHeader({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semester = ref.watch(semesterByIdProvider)[course.semesterId];
    final accent = course.isSessional
        ? AppColors.cyan
        : AppColors.primaryMedium;

    return GlassContainer(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.fromLTRB(18, 16, 6, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.code,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                useRootNavigator: true,
                tooltip: 'Course options',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textHint,
                ),
                onSelected: (value) => _onMenu(context, ref, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit course'),
                  ),
                  PopupMenuItem(
                    value: 'end',
                    child: Text(
                      course.classesEndedOn == null
                          ? 'Classes ended'
                          : 'Reopen classes',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete course',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: course.isSessional
                    ? Icons.science_outlined
                    : Icons.menu_book_outlined,
                label: course.kind.label,
              ),
              _MetaChip(
                icon: Icons.functions_rounded,
                label: '${course.creditsLabel} credits',
              ),
              if (semester != null)
                _MetaChip(icon: Icons.school_outlined, label: semester.name),
              if (course.classesEndedOn != null)
                _MetaChip(
                  icon: Icons.flag_outlined,
                  label: 'Ended ${AppDate.dayMonth(course.classesEndedOn!)}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final notifier = ref.read(courseListProvider.notifier);
    switch (value) {
      case 'edit':
        await showCourseEditor(context, course: course);
      case 'end':
        if (course.classesEndedOn != null) {
          await runAction(
            context,
            () => notifier.setClassesEnded(course.id, null),
          );
          return;
        }
        final ok = await confirm(
          context,
          title: 'End classes for ${course.code}?',
          message:
              'From today it leaves your routine and reminders, and attendance '
              'stops being tracked. Marks and results stay, and you can reopen '
              'it any time.',
          confirmLabel: 'End classes',
          destructive: false,
        );
        if (!ok || !context.mounted) return;
        await runAction(
          context,
          () => notifier.setClassesEnded(
            course.id,
            AppDate.dayOf(DateTime.now()),
          ),
        );
      case 'delete':
        await deleteCourse(context, ref, course);
    }
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipe left to delete, on top of the shared assignment tile.
class _SwipeToDeleteAssignment extends StatelessWidget {
  final Assignment assignment;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  /// Resolves true once the row should actually leave the list. Asking here
  /// rather than in `onDismissed` keeps the dismissal and the removal in the
  /// same frame, which Dismissible requires.
  final Future<bool> Function() onConfirmDelete;

  const _SwipeToDeleteAssignment({
    required this.assignment,
    required this.onToggle,
    required this.onEdit,
    required this.onConfirmDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(assignment.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onConfirmDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.error,
          size: 22,
        ),
      ),
      child: AssignmentTile(
        assignment: assignment,
        onToggle: onToggle,
        onEdit: onEdit,
      ),
    );
  }
}

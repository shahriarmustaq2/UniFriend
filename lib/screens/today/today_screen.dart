import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/assignment.dart';
import '../../models/study_plan.dart';
import '../../providers/assignment_providers.dart';
import '../../providers/course_providers.dart';
import '../../providers/notice_providers.dart';
import '../../providers/results_providers.dart';
import '../../providers/routine_providers.dart';
import '../../providers/semester_providers.dart';
import '../../providers/study_providers.dart';
import '../../providers/sync_providers.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../widgets/assignment_tile.dart';
import '../../widgets/attendance_card.dart';
import '../../widgets/class_card.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/notice_tile.dart';
import '../../widgets/section_header.dart';
import '../../widgets/study_tiles.dart';
import '../courses/assignment_editor_sheet.dart';
import '../expenses/expense_editor_sheet.dart';
import '../notices/notice_editor_sheet.dart';
import '../routine/class_slot_editor_sheet.dart';
import '../semester/semester_sheets.dart';
import '../study/study_plan_sheets.dart';

/// What today asks of the student: quick actions, today's classes to mark,
/// what is due soon, today's study plan and pinned notices.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  /// Deadlines and exams within this many days count as "due soon".
  static const int _soonDays = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = AppDate.dayOf(DateTime.now());
    final classes = ref.watch(classesOnDayProvider(today));
    final term = ref.watch(semesterTodayProvider);
    final hasSemester = ref.watch(semesterListProvider).value?.isNotEmpty;
    final below = ref.watch(coursesBelowAttendanceTargetProvider);
    final toRegister = ref.watch(coursesToRegisterProvider);
    final plan = ref.watch(todayPlanProvider);
    final pinned = ref.watch(pinnedNoticesProvider);
    final courses = ref.watch(courseByIdProvider);

    final horizon = AppDate.addDays(today, _soonDays + 1);
    final dueAssignments = ref
        .watch(openAssignmentsProvider)
        .where((a) => a.dueDate.isBefore(horizon))
        .toList();
    final dueExams = ref
        .watch(upcomingExamsProvider)
        .where((e) => e.heldOn.isBefore(horizon))
        .toList();

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceRaised,
      onRefresh: () => refreshAll(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        children: [
          if (hasSemester == false) ...[
            _Banner(
              icon: Icons.school_outlined,
              color: AppColors.primary,
              text:
                  'Add your semester to get week numbers, a routine and '
                  'marks.',
              action: 'Add',
              onAction: () => showSemesterEditor(context),
            ),
            const SizedBox(height: 14),
          ] else if (term?.vacation != null) ...[
            _Banner(
              icon: Icons.beach_access_outlined,
              color: AppColors.cyan,
              text:
                  '${term!.vacation!.title.isEmpty ? 'Vacation' : term.vacation!.title}'
                  ' until ${AppDate.weekdayDayMonth(term.vacation!.endsOn)}. '
                  'Enjoy the break.',
            ),
            const SizedBox(height: 14),
          ],
          const _QuickActions(),
          if (below.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Banner(
              icon: Icons.warning_amber_rounded,
              color: AppColors.error,
              text: attendanceWarning(below, toRegister),
              action: 'View',
              onAction: () => context.go(AppRoutes.attendance),
            ),
          ],
          const SizedBox(height: 26),
          SectionHeader(
            icon: Icons.schedule_rounded,
            title: classes.isEmpty
                ? 'Classes today'
                : 'Classes today  ·  ${classes.length}',
            actionLabel: 'Week',
            onAction: () => context.go(AppRoutes.routine),
          ),
          const SizedBox(height: 10),
          if (classes.isEmpty)
            GlassContainer(
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.all(16),
              child: Text(
                term?.vacation != null
                    ? 'No classes during the vacation.'
                    : 'No classes today.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            for (final occurrence in classes) ...[
              ClassCard(
                occurrence: occurrence,
                onEdit: () => showClassSlotEditor(
                  context,
                  weekday: occurrence.slot.weekday,
                  slot: occurrence.slot,
                ),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 16),
          const SectionHeader(
            icon: Icons.flag_outlined,
            accent: AppColors.warning,
            title: 'Due soon',
          ),
          const SizedBox(height: 10),
          if (dueAssignments.isEmpty && dueExams.isEmpty)
            GlassContainer(
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Nothing due in the next week.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else ...[
            for (final exam in dueExams) ...[
              ExamTile(exam: exam, onTap: () => context.go(AppRoutes.study)),
              const SizedBox(height: 10),
            ],
            for (final assignment in dueAssignments) ...[
              _AssignmentRow(
                assignment: assignment,
                courseLabel: courses[assignment.courseId]?.code,
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 16),
          SectionHeader(
            icon: Icons.checklist_rounded,
            accent: AppColors.purple,
            title: 'Study plan',
            actionLabel: plan.isEmpty ? 'Plan' : 'All',
            onAction: plan.isEmpty
                ? () => showStudyTaskEditor(context)
                : () => context.go(AppRoutes.study),
          ),
          const SizedBox(height: 10),
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
            child: plan.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      'Nothing planned. Add a topic to study today.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final StudyTask task in plan.take(5))
                        StudyTaskTile(
                          task: task,
                          onTap: () => showStudyTaskEditor(context, task: task),
                        ),
                      if (plan.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+ ${plan.length - 5} more on the Study tab',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (pinned.isNotEmpty) ...[
            const SizedBox(height: 26),
            SectionHeader(
              icon: Icons.push_pin_outlined,
              accent: AppColors.gold,
              title: 'Pinned',
              actionLabel: 'Notices',
              onAction: () => context.go(AppRoutes.notices),
            ),
            const SizedBox(height: 10),
            for (final notice in pinned.take(3)) ...[
              NoticeTile(
                notice: notice,
                onEdit: () => showNoticeEditor(context, notice: notice),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _AssignmentRow extends ConsumerWidget {
  final Assignment assignment;
  final String? courseLabel;

  const _AssignmentRow({required this.assignment, this.courseLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AssignmentTile(
      assignment: assignment,
      courseLabel: courseLabel,
      onToggle: (done) => runAction(
        context,
        () => ref
            .read(assignmentListProvider.notifier)
            .toggleCompleted(assignment.id, done),
      ),
      onEdit: () => showAssignmentEditor(
        context,
        courseId: assignment.courseId,
        assignment: assignment,
      ),
    );
  }
}

/// The four things done most often, one tap each.
class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(studyTimerProvider);

    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: timer == null ? Icons.play_arrow_rounded : Icons.stop_rounded,
            color: AppColors.cyan,
            label: timer == null ? 'Focus' : null,
            live: timer,
            onTap: timer == null
                ? () => ref.read(studyTimerProvider.notifier).start()
                : () => stopStudyTimer(context, ref),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.payments_outlined,
            color: AppColors.orange,
            label: 'Expense',
            onTap: () => showExpenseEditor(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.playlist_add_rounded,
            color: AppColors.purple,
            label: 'Plan',
            onTap: () => showStudyTaskEditor(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.campaign_outlined,
            color: AppColors.primary,
            label: 'Notice',
            onTap: () => showNoticeEditor(context),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;

  /// When set, the tile shows a running timer instead of [label].
  final DateTime? live;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.onTap,
    this.label,
    this.live,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: live != null ? color : AppColors.textSecondary,
    );
    return Semantics(
      button: true,
      label: live != null ? 'Stop timer' : label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(18),
          borderColor: live != null ? color : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              if (live != null)
                ElapsedText(startedAt: live!, style: textStyle)
              else
                Text(label ?? '', style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const _Banner({
    required this.icon,
    required this.color,
    required this.text,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      borderColor: color,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (action != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

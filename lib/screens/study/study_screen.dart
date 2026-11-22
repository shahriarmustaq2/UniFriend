import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/study_plan.dart';
import '../../models/study_session.dart';
import '../../providers/core_providers.dart';
import '../../providers/course_providers.dart';
import '../../providers/study_providers.dart';
import '../../providers/sync_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../utils/study_stats.dart';
import '../../widgets/action_row.dart';
import '../../widgets/amount_sheet.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/meter_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/study_tiles.dart';
import 'study_plan_sheets.dart';
import 'study_session_editor_sheet.dart';

/// One screen for studying: time this week, today's plan, exams to prepare
/// for, and a short log of what was done.
class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(todayPlanProvider);
    final upcoming = ref.watch(upcomingPlanProvider);
    final exams = ref.watch(upcomingExamsProvider);
    final sessions =
        ref.watch(studySessionListProvider).value ?? const <StudySession>[];

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceRaised,
      onRefresh: () => refreshAll(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
        children: [
          const _FocusCard(),
          const SizedBox(height: 26),
          SectionHeader(
            icon: Icons.checklist_rounded,
            title: 'Today\'s plan',
            actionLabel: 'Add',
            onAction: () => showStudyTaskEditor(context),
          ),
          const SizedBox(height: 10),
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
            child: plan.isEmpty
                ? const _Hint(
                    'Nothing planned for today. Add a topic or two, and tick them '
                    'off as you go. Unfinished ones carry over to tomorrow.',
                  )
                : Column(
                    children: [
                      for (final task in plan)
                        StudyTaskTile(
                          task: task,
                          onTap: () => showStudyTaskEditor(context, task: task),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 26),
          SectionHeader(
            icon: Icons.event_note_rounded,
            accent: AppColors.cyan,
            title: 'Exams',
            actionLabel: 'Add exam',
            onAction: () => showExamEditor(context),
          ),
          const SizedBox(height: 10),
          if (exams.isEmpty)
            GlassContainer(
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.all(14),
              child: const _Hint(
                'Add your next CT, viva or final to see the days left, and link '
                'topics to it to track what is still to cover.',
              ),
            )
          else
            for (final exam in exams) ...[
              ExamTile(exam: exam, onTap: () => _examActions(context, exam)),
              const SizedBox(height: 10),
            ],
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader(
              icon: Icons.upcoming_rounded,
              accent: AppColors.purple,
              title: 'Coming up',
            ),
            const SizedBox(height: 10),
            GlassContainer(
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
              child: Column(
                children: [
                  for (final task in upcoming.take(8))
                    StudyTaskTile(
                      task: task,
                      onTap: () => showStudyTaskEditor(context, task: task),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          SectionHeader(
            icon: Icons.history_rounded,
            accent: AppColors.textSecondary,
            title: 'Recent study',
            actionLabel: 'Log time',
            onAction: () => showStudySessionEditor(context),
          ),
          const SizedBox(height: 10),
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            child: sessions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: _Hint(
                      'Use the timer above, or log time you studied by hand.',
                    ),
                  )
                : Column(
                    children: [
                      for (final session in sessions.take(5)) ...[
                        _SessionRow(session: session),
                        if (session != sessions.take(5).last)
                          const RowDivider(),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _examActions(BuildContext context, Exam exam) {
    return showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => GlassSheet(
        title: exam.title,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              ActionRow(
                icon: Icons.playlist_add_rounded,
                iconColor: AppColors.cyan,
                label: 'Plan a topic for it',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showStudyTaskEditor(
                    context,
                    examId: exam.id,
                    courseId: exam.courseId,
                  );
                },
              ),
              const RowDivider(),
              ActionRow(
                icon: Icons.edit_outlined,
                label: 'Edit exam',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showExamEditor(context, exam: exam);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Time this week against the goal, and the focus timer.
class _FocusCard extends ConsumerWidget {
  const _FocusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(studyMinutesThisWeekProvider);
    final today = ref.watch(studyMinutesTodayProvider);
    final goal = ref.watch(weeklyStudyGoalProvider);
    final started = ref.watch(studyTimerProvider);
    final fraction = goal == 0 ? 0.0 : week / goal;

    return GlassContainer(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'THIS WEEK',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      StudyStats.formatMinutes(week),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => showAmountSheet(
                  context,
                  title: 'Weekly study goal',
                  label: 'Hours per week',
                  icon: Icons.flag_outlined,
                  initial: goal / 60,
                  max: 168,
                  onSave: (hours) => ref
                      .read(profileProvider.notifier)
                      .setStudyGoal((hours * 60).round()),
                ),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'of ${StudyStats.formatMinutes(goal)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MeterBar(
            fraction: fraction,
            color: fraction >= 1 ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(height: 8),
          Text(
            today == 0
                ? 'Nothing logged today yet'
                : '${StudyStats.formatMinutes(today)} today',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (started == null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => ref.read(studyTimerProvider.notifier).start(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start focus timer'),
                style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
              ),
            )
          else
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: AppColors.cyan,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ElapsedText(
                      startedAt: started,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.cyan,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => stopStudyTimer(context, ref),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop & log'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  final StudySession session;

  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = session.courseId == null
        ? null
        : ref.watch(courseByIdProvider)[session.courseId];
    final days = AppDate.daysUntil(session.studiedOn);
    final when = days == 0
        ? 'Today'
        : days == -1
        ? 'Yesterday'
        : AppDate.weekdayDayMonth(session.studiedOn);

    return InkWell(
      onTap: () => showStudySessionEditor(context, session: session),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    [?course?.code, when].join('  ·  '),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              StudyStats.formatMinutes(session.minutes),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ct_mark.dart';
import '../../providers/course_providers.dart';
import '../../providers/ct_mark_providers.dart';
import '../../providers/semester_providers.dart';
import '../../utils/ct_summary.dart';
import '../../theme/app_colors.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ct_course_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_fab.dart';
import '../../widgets/stat_tile.dart';
import 'ct_mark_editor_sheet.dart';

class CtMarksScreen extends ConsumerWidget {
  const CtMarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = ref.watch(ctMarkListProvider);
    final courses = ref.watch(courseByIdProvider);
    final semester = ref.watch(viewedSemesterProvider);
    // Only theory courses sit class tests; sessional quizzes are a mark part.
    final inSemester = {
      for (final c in ref.watch(coursesInSemesterProvider(semester?.id)))
        if (!c.isSessional) c.id,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: GlassFab(
        tooltip: 'New CT mark',
        onPressed: () => showCtMarkEditor(context),
      ),
      body: AsyncView<List<CtMark>>(
        value: marks,
        onRetry: () => ref.invalidate(ctMarkListProvider),
        builder: (context, all) {
          final items = all
              .where((m) => inSemester.contains(m.courseId))
              .toList();
          final overall = CtSummary.of(items);
          if (items.isEmpty) {
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
              children: [
                EmptyState(
                  icon: Icons.quiz_outlined,
                  accent: AppColors.pink,
                  title: 'No CT marks yet',
                  message:
                      'Record each class test as you get it back. The best 3 '
                      'make up the CT part of the marks.',
                  actionLabel: 'Add a mark',
                  onAction: () => showCtMarkEditor(context),
                ),
              ],
            );
          }

          final byCourse = <String, List<CtMark>>{};
          for (final mark in items) {
            byCourse.putIfAbsent(mark.courseId, () => []).add(mark);
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.quiz_outlined,
                      accent: AppColors.pink,
                      value: '${overall.count}',
                      label: 'Tests',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.percent_rounded,
                      accent: ctColor(overall.averagePercent),
                      value: '${overall.averagePercent!.toStringAsFixed(0)}%',
                      label: 'Average',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.emoji_events_outlined,
                      accent: AppColors.warning,
                      value: '${overall.highestPercent!.toStringAsFixed(0)}%',
                      label: 'Highest',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              for (final entry in byCourse.entries) ...[
                CtCourseCard(
                  title: courses[entry.key]?.code ?? 'Course',
                  subtitle: courses[entry.key]?.title,
                  marks: entry.value,
                  onTapMark: (mark) => showCtMarkEditor(context, mark: mark),
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

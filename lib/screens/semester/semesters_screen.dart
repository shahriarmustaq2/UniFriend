import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/semester.dart';
import '../../providers/core_providers.dart';
import '../../providers/course_providers.dart';
import '../../providers/semester_providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_fab.dart';
import 'semester_sheets.dart';

/// Every semester, newest first, each with its vacations.
class SemestersScreen extends ConsumerWidget {
  const SemestersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semesters = ref.watch(semesterListProvider);
    final current = ref.watch(currentSemesterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: GlassFab(
        tooltip: 'New semester',
        onPressed: () => showSemesterEditor(context),
      ),
      body: AsyncView<List<Semester>>(
        value: semesters,
        onRetry: () => ref.invalidate(semesterListProvider),
        builder: (context, list) {
          if (list.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              children: [
                EmptyState(
                  icon: Icons.school_outlined,
                  accent: AppColors.primary,
                  title: 'Add your semester',
                  message:
                      'Name it and pick the day classes start. Your courses, '
                      'routine and week numbers hang off it.',
                  actionLabel: 'Add semester',
                  onAction: () => showSemesterEditor(context),
                ),
              ],
            );
          }
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
            children: [
              for (final semester in list.reversed) ...[
                _SemesterCard(
                  semester: semester,
                  isCurrent: semester.id == current?.id,
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SemesterCard extends ConsumerWidget {
  final Semester semester;
  final bool isCurrent;

  const _SemesterCard({required this.semester, required this.isCurrent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vacations = ref.watch(vacationsForSemesterProvider(semester.id));
    final courses = ref.watch(coursesInSemesterProvider(semester.id));
    final calendar = ref.watch(calendarLookupProvider)(semester.id);
    final week = calendar.weekNumber(DateTime.now());

    final status = semester.hasEnded
        ? 'Classes ended ${AppDate.dayMonthYear(semester.classesEndedOn!)}'
        : week == null
        ? 'Starts ${AppDate.dayMonthYear(semester.startsOn)}'
        : 'Week $week  ·  since ${AppDate.dayMonth(semester.startsOn)}';

    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      borderColor: isCurrent ? AppColors.primary : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            semester.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          const _Badge('Current'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$status  ·  ${AppDate.plural(courses.length, 'course')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                useRootNavigator: true,
                tooltip: 'Semester options',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppColors.textHint,
                ),
                onSelected: (value) => _onMenu(context, ref, value),
                itemBuilder: (context) => [
                  if (!isCurrent)
                    const PopupMenuItem(
                      value: 'current',
                      child: Text('Make current'),
                    ),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'end',
                    child: Text(
                      semester.hasEnded ? 'Reopen classes' : 'Classes ended',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final vacation in vacations)
            InkWell(
              onTap: () => showVacationEditor(
                context,
                semesterId: semester.id,
                vacation: vacation,
              ),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.beach_access_outlined,
                      size: 16,
                      color: AppColors.cyan,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${vacation.title.isEmpty ? 'Vacation' : vacation.title}'
                        '  ·  ${AppDate.dayMonth(vacation.startsOn)} – '
                        '${AppDate.dayMonth(vacation.endsOn)}',
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
          TextButton.icon(
            onPressed: () =>
                showVacationEditor(context, semesterId: semester.id),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add vacation'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
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
    final notifier = ref.read(semesterListProvider.notifier);
    switch (value) {
      case 'current':
        await runAction(
          context,
          () => ref
              .read(profileProvider.notifier)
              .setCurrentSemester(semester.id),
          successMessage: '${semester.name} is now your current semester',
        );
      case 'edit':
        await showSemesterEditor(context, semester: semester);
      case 'end':
        if (semester.hasEnded) {
          await runAction(
            context,
            () => notifier.setClassesEnded(semester.id, null),
          );
          return;
        }
        final ok = await confirm(
          context,
          title: 'End classes for ${semester.name}?',
          message:
              'From today its classes leave your routine and reminders, and '
              'attendance stops being tracked. You can still enter marks and '
              'results, and reopen it any time.',
          confirmLabel: 'End classes',
          destructive: false,
        );
        if (!ok || !context.mounted) return;
        await runAction(
          context,
          () => notifier.setClassesEnded(
            semester.id,
            AppDate.dayOf(DateTime.now()),
          ),
        );
      case 'delete':
        await deleteSemester(context, ref, semester);
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryMedium,
        ),
      ),
    );
  }
}

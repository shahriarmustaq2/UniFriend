import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/course.dart';
import '../../providers/course_providers.dart';
import '../../providers/results_providers.dart';
import '../../providers/semester_providers.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/gpa.dart';
import '../../utils/grades.dart';
import '../../widgets/async_view.dart';
import '../../widgets/course_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/meter_bar.dart';

/// CGPA, GPA by semester, and every course's grade, semester by semester.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(courseListProvider);

    return AsyncView<List<Course>>(
      value: courses,
      onRetry: () => ref.invalidate(courseListProvider),
      builder: (context, items) {
        if (items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              EmptyState(
                icon: Icons.insights_outlined,
                accent: AppColors.gold,
                title: 'No results yet',
                message:
                    'Add your courses, then enter marks or a grade, and your '
                    'CGPA builds itself.',
                actionLabel: 'Go to semester',
                onAction: () => context.go(AppRoutes.semester),
              ),
            ],
          );
        }
        return const _ResultsBody();
      },
    );
  }
}

class _ResultsBody extends ConsumerWidget {
  const _ResultsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cgpa = ref.watch(cgpaProvider);
    final credits = ref.watch(creditsEarnedProvider);
    final bySemester = ref.watch(semesterGpaListProvider);
    final semesters = ref.watch(semesterListProvider).value ?? const [];
    final names = ref.watch(semesterByIdProvider);
    final superseded = ref.watch(supersededCourseIdsProvider);
    final unassigned = ref.watch(coursesInSemesterProvider(null));

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      children: [
        GlassContainer(
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CGPA',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cgpa?.toStringAsFixed(2) ?? '--',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      height: 1,
                      color: AppColors.gold,
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      cgpaRemark(cgpa),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              MeterBar(
                fraction: (cgpa ?? 0) / kMaxGradePoints,
                color: AppColors.gold,
              ),
              const SizedBox(height: 10),
              Text(
                '${_credits(credits)} credits earned',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (bySemester.length > 1) ...[
          const SizedBox(height: 14),
          _GpaChart(
            results: bySemester,
            names: {for (final s in semesters) s.id: s.name},
          ),
        ],
        for (final semester in semesters.reversed)
          ..._semesterSection(
            context,
            ref,
            title: semester.name,
            gpa: bySemester
                .where((s) => s.semesterId == semester.id)
                .firstOrNull,
            courses: ref.watch(coursesInSemesterProvider(semester.id)),
            superseded: superseded,
          ),
        if (unassigned.isNotEmpty)
          ..._semesterSection(
            context,
            ref,
            title: 'No semester',
            gpa: bySemester.where((s) => s.semesterId == null).firstOrNull,
            courses: unassigned,
            superseded: superseded,
          ),
        if (superseded.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            kRetakePolicy == RetakePolicy.bestGrade
                ? 'A retaken course counts once in the CGPA, with its better '
                      'grade. The other attempt is marked "Retaken".'
                : 'A retaken course counts once in the CGPA, with its latest '
                      'grade.',
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
        if (names.isEmpty) const SizedBox.shrink(),
      ],
    );
  }

  List<Widget> _semesterSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required SemesterGpa? gpa,
    required List<Course> courses,
    required Set<String> superseded,
  }) {
    if (courses.isEmpty) return const [];
    return [
      const SizedBox(height: 26),
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            gpa?.gpa == null
                ? 'Not graded'
                : 'GPA ${gpa!.gpa!.toStringAsFixed(2)}  ·  ${_credits(gpa.totalCredits)} cr',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontFeatures: AppTheme.tabular,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      for (final course in courses) ...[
        CourseCard(
          course: course,
          superseded: superseded.contains(course.id),
          onTap: () => context.go(AppRoutes.courseDetail(course.id)),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  static String _credits(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// GPA per semester as bars, earliest on the left.
class _GpaChart extends StatelessWidget {
  final List<SemesterGpa> results;
  final Map<String, String> names;

  const _GpaChart({required this.results, required this.names});

  @override
  Widget build(BuildContext context) {
    const height = 110.0;
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GPA by semester',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: height + 34,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final result in results)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            result.gpa?.toStringAsFixed(2) ?? '--',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontFeatures: AppTheme.tabular,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height:
                                height * ((result.gpa ?? 0) / kMaxGradePoints),
                            constraints: const BoxConstraints(maxWidth: 30),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.5),
                                  AppColors.primaryMedium,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            names[result.semesterId] ?? 'Other',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

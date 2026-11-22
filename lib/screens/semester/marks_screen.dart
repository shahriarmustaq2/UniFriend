import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/course.dart';
import '../../providers/course_providers.dart';
import '../../providers/results_providers.dart';
import '../../providers/semester_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/grades.dart';
import '../../utils/marks.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';
import '../courses/grade_picker_sheet.dart';
import 'mark_entry_sheet.dart';

/// The semester's tabulation: one table for theory courses and one for
/// sessionals. The total and the grade come first, so they show without
/// scrolling, then a column per part of the marks.
/// Tap a cell to enter that mark, or the grade to set one directly.
class MarksScreen extends ConsumerWidget {
  const MarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semester = ref.watch(viewedSemesterProvider);
    final courses = ref.watch(coursesInSemesterProvider(semester?.id));
    final theory = courses.where((c) => !c.isSessional).toList();
    final sessional = courses.where((c) => c.isSessional).toList();
    final gpa = ref.watch(semesterGpaProvider(semester?.id));

    if (courses.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: const [
          EmptyState(
            icon: Icons.table_chart_outlined,
            accent: AppColors.cyan,
            title: 'No courses in this semester',
            message: 'Add courses on the Semester tab to enter their marks.',
          ),
        ],
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      children: [
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      semester?.name ?? 'Courses',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'GPA from the courses graded so far',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                gpa?.toStringAsFixed(2) ?? '--',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
            ],
          ),
        ),
        if (theory.isNotEmpty) ...[
          const SizedBox(height: 22),
          _MarkTable(kind: CourseKind.theory, courses: theory),
        ],
        if (sessional.isNotEmpty) ...[
          const SizedBox(height: 22),
          _MarkTable(kind: CourseKind.sessional, courses: sessional),
        ],
        const SizedBox(height: 18),
        const _Legend(),
      ],
    );
  }
}

const double _courseColumn = 86;
const double _partColumn = 60;
const double _totalColumn = 62;
const double _gradeColumn = 58;
const double _rowHeight = 52;

class _MarkTable extends ConsumerWidget {
  final CourseKind kind;
  final List<Course> courses;

  const _MarkTable({required this.kind, required this.courses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shares = kMarkScheme[kind]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            kind == CourseKind.theory ? 'Theory' : 'Sessional',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kind == CourseKind.theory
                  ? AppColors.primaryMedium
                  : AppColors.cyan,
            ),
          ),
        ),
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderRow(shares: shares),
                for (final course in courses) ...[
                  Container(
                    height: 1,
                    width:
                        _courseColumn +
                        shares.length * _partColumn +
                        _totalColumn +
                        _gradeColumn,
                    color: AppColors.hairline,
                  ),
                  _CourseRow(course: course),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final List<MarkShare> shares;

  const _HeaderRow({required this.shares});

  static String _short(MarkPart part) => switch (part) {
    MarkPart.attendance => 'Att.',
    MarkPart.ct => 'CT',
    MarkPart.assignment => 'Asg.',
    MarkPart.finalExam => 'Final',
    MarkPart.quiz => 'Quiz',
    MarkPart.performance => 'Perf.',
    MarkPart.viva => 'Viva',
  };

  @override
  Widget build(BuildContext context) {
    Widget cell(String top, String bottom, double width) => SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(
              top,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              bottom,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        const SizedBox(
          width: _courseColumn,
          child: Padding(
            padding: EdgeInsets.only(left: 14),
            child: Text(
              'Course',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        cell('Total', '100', _totalColumn),
        cell('Grade', '', _gradeColumn),
        for (final share in shares)
          cell(_short(share.part), formatMark(share.weight), _partColumn),
      ],
    );
  }
}

class _CourseRow extends ConsumerWidget {
  final Course course;

  const _CourseRow({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ref.watch(markSheetProvider(course.id));
    final grade = ref.watch(courseGradeProvider(course.id));
    if (sheet == null) return const SizedBox.shrink();

    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: _courseColumn,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${course.creditsLabel} cr',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _Cell(
            width: _totalColumn,
            child: Text(
              formatMark(sheet.total),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: sheet.isComplete
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ),
          _Cell(
            width: _gradeColumn,
            onTap: () => showGradePicker(context, course: course),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: switch (grade.source) {
                  GradeSource.direct => AppColors.gold.withValues(alpha: 0.14),
                  GradeSource.marks => AppColors.success.withValues(
                    alpha: 0.12,
                  ),
                  GradeSource.none => Colors.transparent,
                },
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                gradeLetter(grade.points),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: switch (grade.source) {
                    GradeSource.direct => AppColors.gold,
                    GradeSource.marks => AppColors.success,
                    GradeSource.none => AppColors.textHint,
                  },
                ),
              ),
            ),
          ),
          for (final line in sheet.lines)
            _Cell(
              width: _partColumn,
              onTap: () =>
                  showMarkEntry(context, course: course, part: line.part),
              child: Text(
                line.value == null ? '—' : formatMark(line.value!),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontStyle: line.source == MarkSource.auto
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: switch (line.source) {
                    MarkSource.entered => AppColors.textPrimary,
                    MarkSource.auto => AppColors.cyan,
                    MarkSource.missing => AppColors.textHint,
                  },
                  fontFeatures: AppTheme.tabular,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final double width;
  final Widget child;
  final VoidCallback? onTap;

  const _Cell({required this.width, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: width,
      height: _rowHeight,
      child: Center(child: child),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String text, {bool italic = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          item(
            AppColors.cyan,
            'Worked out for you: attendance from your attendance %, class '
            'tests from your best 3 CTs. Tap to type your own.',
            italic: true,
          ),
          item(
            AppColors.success,
            'Grade from marks, once every part is in (80+ A+, 75 A, 70 A-, '
            '65 B+, 60 B, 55 B-, 50 C+, 45 C, 40 D).',
          ),
          item(
            AppColors.gold,
            'Grade entered directly. It wins over the marks; clear it to go '
            'back to them.',
          ),
        ],
      ),
    );
  }
}

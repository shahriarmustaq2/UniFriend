import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/course.dart';
import '../../providers/course_providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/grades.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_sheet.dart';

/// Lets the student record or clear a result for [course].
Future<void> showGradePicker(BuildContext context, {required Course course}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _GradePickerSheet(course: course),
  );
}

class _GradePickerSheet extends ConsumerStatefulWidget {
  final Course course;

  const _GradePickerSheet({required this.course});

  @override
  ConsumerState<_GradePickerSheet> createState() => _GradePickerSheetState();
}

class _GradePickerSheetState extends ConsumerState<_GradePickerSheet> {
  /// `null` means "not graded", which is a real, selectable option.
  double? _selected;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.course.gradePoints;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);

    await runAction(context, () async {
      await ref
          .read(courseListProvider.notifier)
          .setGrade(widget.course.id, _selected);
      navigator.pop();
    });

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      title: 'Result for ${widget.course.code}',
      actions: [
        // GlassSheet already spaces and flexes its actions, so these are
        // passed bare. The Clear button only appears when there is something
        // to clear.
        if (widget.course.gradePoints != null)
          SheetAction(
            label: 'Clear',
            icon: Icons.backspace_outlined,
            onPressed: _isSaving
                ? null
                : () {
                    setState(() => _selected = null);
                    _save();
                  },
            isDestructive: true,
          ),
        SheetAction(
          label: 'Save',
          icon: Icons.check_rounded,
          onPressed: _save,
          isBusy: _isSaving,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  _selected?.toStringAsFixed(2) ?? '--',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selected == null
                      ? 'From marks'
                      : '${gradeLetter(_selected)}  ·  ${widget.course.creditsLabel} cr',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (letter, points) in kGradePresets)
                _GradeOption(
                  letter: letter,
                  points: points,
                  selected:
                      _selected != null && (_selected! - points).abs() < 0.001,
                  onTap: () => setState(() => _selected = points),
                ),
            ],
          ),
          const SizedBox(height: 18),
          GlassContainer(
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              'A grade set here wins over the marks. Clear it to work the grade '
              'out from the marks instead; a course with neither stays out of '
              'your CGPA.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeOption extends StatelessWidget {
  final String letter;
  final double points;
  final bool selected;
  final VoidCallback onTap;

  const _GradeOption({
    required this.letter,
    required this.points,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Text(
              letter,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.midnight : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              points.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.midnight.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

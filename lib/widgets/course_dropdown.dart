import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/course_providers.dart';
import '../providers/semester_providers.dart';
import '../theme/app_colors.dart';
import 'glass_text_field.dart';

/// Picks one of the student's courses: those of the current semester, plus
/// whichever one is already selected.
class CourseDropdown extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  /// Adds a "no course" option, for records that can stand alone.
  final String? noneLabel;

  const CourseDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.noneLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(courseListProvider).value ?? const [];
    final current = ref.watch(currentSemesterProvider);
    final courses = [
      for (final c in all)
        if (current == null || c.semesterId == current.id || c.id == value) c,
    ];
    // A course deleted while the sheet is open must not be left selected, or
    // the dropdown throws for having a value that is not among its items.
    final selected = courses.any((c) => c.id == value) ? value : null;

    return DropdownButtonFormField<String?>(
      initialValue: selected,
      isExpanded: true,
      dropdownColor: AppColors.surfaceRaised,
      iconEnabledColor: AppColors.textSecondary,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: GlassTextField.decoration(
        label: 'Course',
        icon: Icons.menu_book_rounded,
      ),
      hint: Text(
        courses.isEmpty ? 'Add a course first' : 'Choose a course',
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          color: AppColors.textHint,
        ),
      ),
      items: [
        if (noneLabel != null)
          DropdownMenuItem<String?>(value: null, child: Text(noneLabel!)),
        for (final course in courses)
          DropdownMenuItem<String?>(
            value: course.id,
            child: Text(
              '${course.code}  ·  ${course.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
      validator: (selected) {
        if (noneLabel == null && selected == null) {
          return courses.isEmpty
              ? 'Add a course first, on the Semester tab'
              : 'Choose a course';
        }
        return null;
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/course.dart';
import '../../providers/course_providers.dart';
import '../../providers/semester_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';

/// Opens the course editor. Pass [course] to edit, omit it to create one in
/// [semesterId] (the current semester by default).
Future<void> showCourseEditor(
  BuildContext context, {
  Course? course,
  String? semesterId,
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) =>
        _CourseEditorSheet(course: course, semesterId: semesterId),
  );
}

class _CourseEditorSheet extends ConsumerStatefulWidget {
  final Course? course;
  final String? semesterId;

  const _CourseEditorSheet({this.course, this.semesterId});

  @override
  ConsumerState<_CourseEditorSheet> createState() => _CourseEditorSheetState();
}

class _CourseEditorSheetState extends ConsumerState<_CourseEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _titleController;
  late final TextEditingController _creditsController;
  late CourseKind _kind;
  String? _semesterId;
  bool _isSaving = false;

  bool get _isEditing => widget.course != null;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _codeController = TextEditingController(text: course?.code ?? '');
    _titleController = TextEditingController(text: course?.title ?? '');
    _creditsController = TextEditingController(
      text: course == null ? '3' : course.creditsLabel,
    );
    _kind = course?.kind ?? CourseKind.theory;
    _semesterId =
        course?.semesterId ??
        widget.semesterId ??
        ref.read(currentSemesterProvider)?.id;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  /// Parses credits with a fallback, so a half-typed "3." does not throw.
  static double _parseCredits(String raw) => double.tryParse(raw.trim()) ?? 3.0;

  /// Another course with this code, described for the retake hint.
  String? _earlierAttempt() {
    final code = _codeController.text.trim().toLowerCase();
    if (code.isEmpty) return null;
    final courses = ref.watch(courseListProvider).value ?? const <Course>[];
    final other = courses
        .where((c) => c.id != widget.course?.id)
        .where((c) => c.code.toLowerCase() == code)
        .firstOrNull;
    if (other == null) return null;
    final semester = ref.watch(semesterByIdProvider)[other.semesterId];
    return semester == null ? other.code : '${other.code} in ${semester.name}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final notifier = ref.read(courseListProvider.notifier);
    final navigator = Navigator.of(context);
    final existing = widget.course;

    await runAction(context, () async {
      final credits = _parseCredits(_creditsController.text);
      if (_isEditing) {
        await notifier.save(
          existing!.copyWith(
            code: _codeController.text.trim(),
            title: _titleController.text.trim(),
            credits: credits,
            kind: _kind,
            semesterId: _semesterId,
          ),
        );
      } else {
        await notifier.insert(
          Course(
            id: '',
            code: _codeController.text.trim(),
            title: _titleController.text.trim(),
            credits: credits,
            kind: _kind,
            semesterId: _semesterId,
            createdAt: DateTime.now(),
          ),
        );
      }
      navigator.pop();
    });

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      title: _isEditing ? 'Edit course' : 'New course',
      actions: [
        SheetAction(
          label: _isEditing ? 'Save changes' : 'Add course',
          icon: _isEditing ? Icons.save_rounded : Icons.add_rounded,
          onPressed: _save,
          isBusy: _isSaving,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassTextField(
              controller: _codeController,
              label: 'Course code',
              icon: Icons.tag_rounded,
              textInputAction: TextInputAction.next,
              autofocus: !_isEditing,
              inputFormatters: [LengthLimitingTextInputFormatter(16)],
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the course code';
                }
                return null;
              },
            ),
            if (_earlierAttempt() != null) ...[
              const SizedBox(height: 8),
              Text(
                'You already have ${_earlierAttempt()}. Taking the same code again '
                'counts as a retake, and only the better grade goes towards your '
                'CGPA.',
                style: const TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ],
            const SizedBox(height: 14),
            GlassTextField(
              controller: _titleController,
              label: 'Course title',
              icon: Icons.menu_book_rounded,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the course title';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final kind in CourseKind.values) ...[
                  Expanded(
                    child: _KindOption(
                      kind: kind,
                      selected: _kind == kind,
                      onTap: () => setState(() {
                        _kind = kind;
                        // A new sessional is usually a 0.75 or 1.5 credit lab.
                        if (!_isEditing &&
                            kind == CourseKind.sessional &&
                            _creditsController.text == '3') {
                          _creditsController.text = '1.5';
                        }
                      }),
                    ),
                  ),
                  if (kind != CourseKind.values.last) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _SemesterDropdown(
              value: _semesterId,
              onChanged: (v) => setState(() => _semesterId = v),
            ),
            const SizedBox(height: 14),
            GlassTextField(
              controller: _creditsController,
              label: 'Credits',
              icon: Icons.functions_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final credits = double.tryParse((value ?? '').trim());
                if (credits == null) return 'Enter a number';
                // The column stores two decimals, which is what lab credits
                // such as 0.75 need, and allows at most 12.
                if (credits <= 0 || credits > 12) {
                  return 'Must be above 0, up to 12';
                }
                if (credits * 100 != (credits * 100).roundToDouble()) {
                  return 'Use at most 2 decimals';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset
                    in _kind == CourseKind.sessional
                        ? const [0.75, 1.0, 1.5, 2.0]
                        : const [2.0, 3.0, 4.0])
                  ChoicePill(
                    label: Course.formatCredits(preset),
                    selected:
                        double.tryParse(_creditsController.text.trim()) ==
                        preset,
                    onTap: () => setState(
                      () => _creditsController.text = Course.formatCredits(
                        preset,
                      ),
                    ),
                  ),
              ],
            ),
            if (_kind == CourseKind.sessional) ...[
              const SizedBox(height: 10),
              const Text(
                'Sessional marks: 75 for the lab (20 quiz, 10 attendance, '
                '45 performance) and 25 for the viva. A 0.75 credit lab often '
                'meets every other week; set that when you add its class.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textHint,
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              const Text(
                'Theory marks: 10 attendance, 20 class tests, 10 assignments, '
                '60 final exam.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KindOption extends StatelessWidget {
  final CourseKind kind;
  final bool selected;
  final VoidCallback onTap;

  const _KindOption({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = kind == CourseKind.sessional
        ? AppColors.cyan
        : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.white.withValues(alpha: 0.09),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              kind == CourseKind.sessional
                  ? Icons.science_outlined
                  : Icons.menu_book_outlined,
              size: 18,
              color: selected ? color : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              kind.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemesterDropdown extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _SemesterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semesters = ref.watch(semesterListProvider).value ?? const [];
    final selected = semesters.any((s) => s.id == value) ? value : null;
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
        label: 'Semester',
        icon: Icons.school_outlined,
      ),
      hint: Text(
        semesters.isEmpty ? 'Add a semester in Profile first' : 'Choose',
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          color: AppColors.textHint,
        ),
      ),
      items: [
        for (final semester in semesters.reversed)
          DropdownMenuItem<String?>(
            value: semester.id,
            child: Text(semester.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'Choose a semester' : null,
    );
  }
}

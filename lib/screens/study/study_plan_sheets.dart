import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/study_plan.dart';
import '../../providers/study_providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/course_dropdown.dart';
import '../../widgets/date_field.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';
import 'study_session_editor_sheet.dart';

/// Stops the running timer by logging the time. The timer keeps running if the
/// sheet is closed without saving, so no time is lost by accident.
Future<void> stopStudyTimer(BuildContext context, WidgetRef ref) async {
  final started = ref.read(studyTimerProvider);
  if (started == null) return;
  final minutes = DateTime.now().difference(started).inMinutes.clamp(1, 1440);
  final saved = await showStudySessionEditor(context, minutes: minutes);
  if (saved) ref.read(studyTimerProvider.notifier).stop();
}

/// Adds a topic to the plan, or edits one. [examId] links a new topic to an
/// exam, and [day] picks the day it is planned for.
Future<void> showStudyTaskEditor(
  BuildContext context, {
  StudyTask? task,
  String? examId,
  String? courseId,
  DateTime? day,
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _StudyTaskSheet(
      task: task,
      examId: examId,
      courseId: courseId,
      day: day,
    ),
  );
}

class _StudyTaskSheet extends ConsumerStatefulWidget {
  final StudyTask? task;
  final String? examId;
  final String? courseId;
  final DateTime? day;

  const _StudyTaskSheet({this.task, this.examId, this.courseId, this.day});

  @override
  ConsumerState<_StudyTaskSheet> createState() => _StudyTaskSheetState();
}

class _StudyTaskSheetState extends ConsumerState<_StudyTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.task?.title ?? '',
  );
  late String? _courseId = widget.task?.courseId ?? widget.courseId;
  late String? _examId = widget.task?.examId ?? widget.examId;
  late DateTime _day =
      widget.task?.plannedFor ?? AppDate.dayOf(widget.day ?? DateTime.now());
  bool _isSaving = false;

  bool get _isEditing => widget.task != null;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save({bool another = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final notifier = ref.read(studyTaskListProvider.notifier);
    final navigator = Navigator.of(context);
    final draft = StudyTask(
      id: widget.task?.id ?? '',
      courseId: _courseId,
      examId: _examId,
      title: _title.text.trim(),
      plannedFor: _day,
      isDone: widget.task?.isDone ?? false,
      createdAt: widget.task?.createdAt ?? DateTime.now(),
    );

    await runAction(context, () async {
      if (_isEditing) {
        await notifier.save(draft);
      } else {
        await notifier.insert(draft);
      }
      if (another) {
        _title.clear();
      } else {
        navigator.pop();
      }
    });
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _delete() async {
    final notifier = ref.read(studyTaskListProvider.notifier);
    final navigator = Navigator.of(context);
    await runAction(context, () async {
      await notifier.delete(widget.task!.id);
      navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final exams = ref.watch(upcomingExamsProvider);
    final today = AppDate.dayOf(DateTime.now());
    final tomorrow = AppDate.addDays(today, 1);

    return GlassSheet(
      title: _isEditing ? 'Edit topic' : 'Plan a topic',
      actions: [
        if (_isEditing)
          SheetAction(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onPressed: _isSaving ? null : _delete,
          )
        else
          SheetAction(
            label: 'Add another',
            icon: Icons.playlist_add_rounded,
            isSecondary: true,
            onPressed: _isSaving ? null : () => _save(another: true),
          ),
        SheetAction(
          label: _isEditing ? 'Save' : 'Add',
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
              controller: _title,
              label: 'What to study',
              icon: Icons.edit_note_rounded,
              hintText: 'Chapter 4, deadlocks',
              autofocus: !_isEditing,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a topic' : null,
            ),
            const SizedBox(height: 14),
            CourseDropdown(
              value: _courseId,
              noneLabel: 'No course',
              onChanged: (v) => setState(() => _courseId = v),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoicePill(
                  label: 'Today',
                  selected: _day == today,
                  onTap: () => setState(() => _day = today),
                ),
                ChoicePill(
                  label: 'Tomorrow',
                  selected: _day == tomorrow,
                  onTap: () => setState(() => _day = tomorrow),
                ),
                ChoicePill(
                  label: _day.isAfter(tomorrow) || _day.isBefore(today)
                      ? AppDate.weekdayDayMonth(_day)
                      : 'Pick a day',
                  icon: Icons.event_rounded,
                  selected: _day.isAfter(tomorrow) || _day.isBefore(today),
                  onTap: () async {
                    final picked = await showAppDatePicker(
                      context,
                      initialDate: _day,
                    );
                    if (picked != null) {
                      setState(() => _day = AppDate.dayOf(picked));
                    }
                  },
                ),
              ],
            ),
            if (exams.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Preparing for',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoicePill(
                    label: 'No exam',
                    selected: _examId == null,
                    onTap: () => setState(() => _examId = null),
                  ),
                  for (final exam in exams)
                    ChoicePill(
                      label: exam.title,
                      color: AppColors.cyan,
                      selected: _examId == exam.id,
                      onTap: () => setState(() {
                        _examId = exam.id;
                        _courseId ??= exam.courseId;
                      }),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Adds an exam to count down to, or edits one.
Future<void> showExamEditor(BuildContext context, {Exam? exam}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _ExamSheet(exam: exam),
  );
}

class _ExamSheet extends ConsumerStatefulWidget {
  final Exam? exam;

  const _ExamSheet({this.exam});

  @override
  ConsumerState<_ExamSheet> createState() => _ExamSheetState();
}

class _ExamSheetState extends ConsumerState<_ExamSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.exam?.title ?? '',
  );
  late String? _courseId = widget.exam?.courseId;
  late ExamKind _kind = widget.exam?.kind ?? ExamKind.ct;
  late DateTime _day =
      widget.exam?.heldOn ?? AppDate.addDays(AppDate.dayOf(DateTime.now()), 7);
  bool _isSaving = false;

  bool get _isEditing => widget.exam != null;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final notifier = ref.read(examListProvider.notifier);
    final navigator = Navigator.of(context);
    final draft = Exam(
      id: widget.exam?.id ?? '',
      courseId: _courseId,
      title: _title.text.trim(),
      kind: _kind,
      heldOn: _day,
      createdAt: widget.exam?.createdAt ?? DateTime.now(),
    );
    await runAction(context, () async {
      if (_isEditing) {
        await notifier.save(draft);
      } else {
        await notifier.insert(draft);
      }
      navigator.pop();
    });
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete this exam?',
      message: 'Topics planned for it stay in your plan.',
    );
    if (!ok || !mounted) return;
    final notifier = ref.read(examListProvider.notifier);
    final navigator = Navigator.of(context);
    await runAction(context, () async {
      await notifier.remove(widget.exam!.id);
      navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      title: _isEditing ? 'Edit exam' : 'New exam',
      actions: [
        if (_isEditing)
          SheetAction(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onPressed: _isSaving ? null : _delete,
          ),
        SheetAction(
          label: _isEditing ? 'Save' : 'Add exam',
          onPressed: _save,
          isBusy: _isSaving,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in ExamKind.values)
                  ChoicePill(
                    label: kind.label,
                    selected: _kind == kind,
                    onTap: () => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            GlassTextField(
              controller: _title,
              label: 'Name',
              icon: Icons.event_note_rounded,
              hintText: 'CT 3, Operating Systems final',
              autofocus: !_isEditing,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 14),
            CourseDropdown(
              value: _courseId,
              noneLabel: 'No course',
              onChanged: (v) => setState(() => _courseId = v),
            ),
            const SizedBox(height: 14),
            DateField(
              label: 'Date',
              value: _day,
              onChanged: (v) => setState(() => _day = AppDate.dayOf(v)),
            ),
          ],
        ),
      ),
    );
  }
}

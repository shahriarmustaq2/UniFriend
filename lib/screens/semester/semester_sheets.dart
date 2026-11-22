import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/semester.dart';
import '../../providers/course_providers.dart';
import '../../providers/semester_providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../widgets/date_field.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';
import '../../widgets/switch_field.dart';

/// Adds a semester, or edits one: name, start date, and the end of classes.
Future<void> showSemesterEditor(BuildContext context, {Semester? semester}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _SemesterSheet(semester: semester),
  );
}

class _SemesterSheet extends ConsumerStatefulWidget {
  final Semester? semester;

  const _SemesterSheet({this.semester});

  @override
  ConsumerState<_SemesterSheet> createState() => _SemesterSheetState();
}

class _SemesterSheetState extends ConsumerState<_SemesterSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.semester?.name ?? '',
  );
  late DateTime _startsOn =
      widget.semester?.startsOn ?? AppDate.dayOf(DateTime.now());
  late DateTime? _endedOn = widget.semester?.classesEndedOn;
  bool _makeCurrent = true;
  bool _isSaving = false;

  bool get _isEditing => widget.semester != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ended = _endedOn;
    if (ended != null && ended.isBefore(_startsOn)) {
      showGlassSnack(
        context,
        'Classes cannot end before the semester starts',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
      return;
    }
    setState(() => _isSaving = true);
    final notifier = ref.read(semesterListProvider.notifier);
    final navigator = Navigator.of(context);

    await runAction(context, () async {
      if (_isEditing) {
        await notifier.save(
          widget.semester!.copyWith(
            name: _name.text.trim(),
            startsOn: _startsOn,
            classesEndedOn: ended,
          ),
        );
      } else {
        await notifier.add(
          name: _name.text.trim(),
          startsOn: _startsOn,
          makeCurrent: _makeCurrent,
        );
      }
      navigator.pop();
    });
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      title: _isEditing ? 'Edit semester' : 'New semester',
      actions: [
        SheetAction(
          label: _isEditing ? 'Save' : 'Add semester',
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
              controller: _name,
              label: 'Name',
              icon: Icons.school_outlined,
              hintText: 'Level 2 Term 1',
              autofocus: !_isEditing,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 14),
            DateField(
              label: 'Classes start',
              value: _startsOn,
              onChanged: (v) => setState(() => _startsOn = AppDate.dayOf(v)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Week 1 is the week this date falls in. Week numbers and '
              'alternate-week classes count from here.',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
            if (!_isEditing)
              SwitchField(
                title: 'This is my current semester',
                value: _makeCurrent,
                onChanged: (v) => setState(() => _makeCurrent = v),
              )
            else ...[
              const SizedBox(height: 14),
              SwitchField(
                title: 'Classes have ended',
                subtitle:
                    'Stops the routine, reminders and attendance warnings. '
                    'Marks and results stay.',
                value: _endedOn != null,
                onChanged: (v) => setState(
                  () => _endedOn = v ? AppDate.dayOf(DateTime.now()) : null,
                ),
              ),
              if (_endedOn != null)
                DateField(
                  label: 'Last day of classes',
                  value: _endedOn!,
                  onChanged: (v) => setState(() => _endedOn = AppDate.dayOf(v)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Adds a vacation to [semesterId], or edits one.
Future<void> showVacationEditor(
  BuildContext context, {
  required String semesterId,
  Vacation? vacation,
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) =>
        _VacationSheet(semesterId: semesterId, vacation: vacation),
  );
}

class _VacationSheet extends ConsumerStatefulWidget {
  final String semesterId;
  final Vacation? vacation;

  const _VacationSheet({required this.semesterId, this.vacation});

  @override
  ConsumerState<_VacationSheet> createState() => _VacationSheetState();
}

class _VacationSheetState extends ConsumerState<_VacationSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.vacation?.title ?? '',
  );
  late DateTime _from =
      widget.vacation?.startsOn ?? AppDate.dayOf(DateTime.now());
  late DateTime _to =
      widget.vacation?.endsOn ??
      AppDate.addDays(AppDate.dayOf(DateTime.now()), 6);
  bool _isSaving = false;

  bool get _isEditing => widget.vacation != null;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_to.isBefore(_from)) {
      showGlassSnack(
        context,
        'The vacation has to end on or after its first day',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
      return;
    }
    setState(() => _isSaving = true);
    final notifier = ref.read(vacationListProvider.notifier);
    final navigator = Navigator.of(context);
    final draft = Vacation(
      id: widget.vacation?.id ?? '',
      semesterId: widget.semesterId,
      title: _title.text.trim(),
      startsOn: _from,
      endsOn: _to,
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
    final notifier = ref.read(vacationListProvider.notifier);
    final navigator = Navigator.of(context);
    await runAction(context, () async {
      await notifier.delete(widget.vacation!.id);
      navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = AppDate.daysUntil(_to, now: _from) + 1;

    return GlassSheet(
      title: _isEditing ? 'Edit vacation' : 'Add vacation',
      actions: [
        if (_isEditing)
          SheetAction(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onPressed: _isSaving ? null : _delete,
          ),
        SheetAction(
          label: _isEditing ? 'Save' : 'Add',
          onPressed: _save,
          isBusy: _isSaving,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTextField(
            controller: _title,
            label: 'Name (optional)',
            icon: Icons.beach_access_outlined,
            hintText: 'Eid vacation',
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DateField(
                  label: 'From',
                  value: _from,
                  onChanged: (v) => setState(() {
                    _from = AppDate.dayOf(v);
                    if (_to.isBefore(_from)) _to = _from;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DateField(
                  label: 'To',
                  value: _to,
                  onChanged: (v) => setState(() => _to = AppDate.dayOf(v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassContainer(
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.all(12),
            child: Text(
              days < 1
                  ? 'Pick an end date on or after the first day.'
                  : '${AppDate.plural(days, 'day')} without classes. Any week '
                        'spent wholly on vacation does not count, so week '
                        'numbers and alternate-week classes pause through it.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirms, then deletes a semester and everything in it.
Future<void> deleteSemester(
  BuildContext context,
  WidgetRef ref,
  Semester semester,
) async {
  final count = ref.read(coursesInSemesterProvider(semester.id)).length;
  final confirmed = await confirm(
    context,
    title: 'Delete ${semester.name}?',
    message: count == 0
        ? 'The semester and its vacations will be removed.'
        : 'Its ${AppDate.plural(count, 'course')} will be deleted too, with '
              'their classes, attendance, marks and assignments. This cannot '
              'be undone.',
  );
  if (!confirmed || !context.mounted) return;
  await runAction(
    context,
    () => ref.read(semesterListProvider.notifier).remove(semester.id),
    successMessage: 'Semester deleted',
  );
}

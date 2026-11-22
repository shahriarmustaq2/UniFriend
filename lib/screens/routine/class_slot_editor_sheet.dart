import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/class_slot.dart';
import '../../providers/course_providers.dart';
import '../../providers/routine_providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/course_dropdown.dart';
import '../../widgets/date_field.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';
import '../../widgets/switch_field.dart';

/// Opens the class editor on [weekday]. Pass [slot] to edit, omit it to create.
Future<void> showClassSlotEditor(
  BuildContext context, {
  required int weekday,
  ClassSlot? slot,
  String? courseId,
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) =>
        _ClassSlotEditorSheet(weekday: weekday, slot: slot, courseId: courseId),
  );
}

class _ClassSlotEditorSheet extends ConsumerStatefulWidget {
  final int weekday;
  final ClassSlot? slot;
  final String? courseId;

  const _ClassSlotEditorSheet({
    required this.weekday,
    this.slot,
    this.courseId,
  });

  @override
  ConsumerState<_ClassSlotEditorSheet> createState() =>
      _ClassSlotEditorSheetState();
}

class _ClassSlotEditorSheetState extends ConsumerState<_ClassSlotEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _roomController;
  late String? _courseId;
  late int _weekday;
  late int _start;
  late int _end;
  late bool _alternate;
  late DateTime _anchor;
  bool _isSaving = false;

  bool get _isEditing => widget.slot != null;

  @override
  void initState() {
    super.initState();
    final slot = widget.slot;
    _roomController = TextEditingController(text: slot?.room ?? '');
    _courseId = slot?.courseId ?? widget.courseId;
    _weekday = slot?.weekday ?? widget.weekday;
    _start = slot?.startMinute ?? 8 * 60;
    _end = slot?.endMinute ?? 8 * 60 + 50;
    _alternate = slot?.isAlternate ?? false;
    _anchor = slot?.anchorDate ?? AppDate.mostRecent(_weekday);
  }

  /// The first class date sets the weekday too, so the two cannot disagree.
  Future<void> _pickAnchor() async {
    final picked = await showAppDatePicker(context, initialDate: _anchor);
    if (picked == null) return;
    setState(() {
      _anchor = AppDate.dayOf(picked);
      _weekday = _anchor.weekday;
    });
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await _pick(_start);
    if (picked == null) return;
    // Moving the start carries the end along, so the class keeps its length.
    final length = _end - _start;
    setState(() {
      _start = picked;
      _end = (picked + length).clamp(picked + 1, 1440);
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pick(_end == 1440 ? 1439 : _end);
    if (picked != null) setState(() => _end = picked);
  }

  Future<int?> _pick(int minute) async {
    final picked = await showAppTimePicker(
      context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  ClassSlot get _draft => ClassSlot(
    id: widget.slot?.id ?? '',
    courseId: _courseId ?? '',
    weekday: _weekday,
    startMinute: _start,
    endMinute: _end,
    room: _roomController.text.trim().isEmpty
        ? null
        : _roomController.text.trim(),
    repeatWeeks: _alternate ? 2 : 1,
    anchorDate: _alternate ? _anchor : null,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_end <= _start) {
      showGlassSnack(
        context,
        'The class has to end after it starts',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final notifier = ref.read(classSlotListProvider.notifier);
    final navigator = Navigator.of(context);

    await runAction(context, () async {
      if (_isEditing) {
        await notifier.save(_draft);
      } else {
        await notifier.insert(_draft);
      }
      navigator.pop();
    });

    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _delete() async {
    final confirmed = await confirm(
      context,
      title: 'Remove this class?',
      message: 'It leaves your routine. Attendance already marked is kept.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    final notifier = ref.read(classSlotListProvider.notifier);
    final navigator = Navigator.of(context);
    await runAction(context, () async {
      await notifier.delete(widget.slot!.id);
      navigator.pop();
    });
  }

  /// The class this one would run into, if any. Only a warning: a clash can be
  /// real, and the student knows their timetable better than the app does.
  String? _clashWith() {
    final others = ref.watch(slotsOnWeekdayProvider(_weekday));
    final courses = ref.watch(courseByIdProvider);
    final draft = _draft;
    for (final other in others) {
      if (other.id != draft.id && draft.overlaps(other)) {
        return courses[other.courseId]?.code ?? 'another class';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final clash = _clashWith();

    return GlassSheet(
      title: _isEditing ? 'Edit class' : 'New class',
      actions: [
        if (_isEditing)
          SheetAction(
            label: 'Remove',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onPressed: _isSaving ? null : _delete,
          ),
        SheetAction(
          label: _isEditing ? 'Save' : 'Add class',
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
            CourseDropdown(
              value: _courseId,
              onChanged: (value) => setState(() => _courseId = value),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final day in AppDate.weekdaysInOrder)
                  ChoicePill(
                    label: AppDate.weekdayShort(day),
                    selected: day == _weekday,
                    onTap: () => setState(() {
                      _weekday = day;
                      // Keep the class date in the same week, on the new day.
                      _anchor = AppDate.addDays(
                        AppDate.startOfWeek(_anchor),
                        (day - AppDate.weekStart) % 7,
                      );
                    }),
                  ),
              ],
            ),
            SwitchField(
              title: 'Every other week',
              subtitle:
                  'For a 0.75 credit sessional that meets in alternate weeks.',
              value: _alternate,
              onChanged: (v) => setState(() => _alternate = v),
            ),
            if (_alternate) ...[
              GestureDetector(
                onTap: _pickAnchor,
                behavior: HitTestBehavior.opaque,
                child: PickerBox(
                  icon: Icons.event_repeat_rounded,
                  label: 'Date of one class (your first, or any you had)',
                  value: AppDate.weekdayDayMonth(_anchor),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'It then repeats every second week from that date. Weeks spent '
                'wholly on vacation are skipped, so the rhythm carries on '
                'after a break.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickStart,
                    behavior: HitTestBehavior.opaque,
                    child: PickerBox(
                      icon: Icons.schedule_rounded,
                      label: 'Starts',
                      value: AppDate.minuteOfDay(_start),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickEnd,
                    behavior: HitTestBehavior.opaque,
                    child: PickerBox(
                      icon: Icons.schedule_rounded,
                      label: 'Ends',
                      value: AppDate.minuteOfDay(_end % 1440),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GlassTextField(
              controller: _roomController,
              label: 'Room (optional)',
              icon: Icons.place_outlined,
              textInputAction: TextInputAction.done,
              hintText: 'Room 301, OS Lab',
            ),
            if (clash != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Overlaps with $clash on ${AppDate.weekdayName(_weekday)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                      ),
                    ),
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

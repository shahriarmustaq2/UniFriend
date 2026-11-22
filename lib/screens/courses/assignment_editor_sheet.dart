import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/assignment.dart';
import '../../providers/assignment_providers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/date_field.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';

/// Opens the assignment editor for [courseId]. Pass [assignment] to edit.
Future<void> showAssignmentEditor(
  BuildContext context, {
  required String courseId,
  Assignment? assignment,
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) =>
        _AssignmentEditorSheet(courseId: courseId, assignment: assignment),
  );
}

class _AssignmentEditorSheet extends ConsumerStatefulWidget {
  final String courseId;
  final Assignment? assignment;

  const _AssignmentEditorSheet({required this.courseId, this.assignment});

  @override
  ConsumerState<_AssignmentEditorSheet> createState() =>
      _AssignmentEditorSheetState();
}

class _AssignmentEditorSheetState
    extends ConsumerState<_AssignmentEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;

  /// Defaults to 23:59 three days from now, so a student who only picks a date
  /// still gets a deadline at the end of that day.
  late DateTime _dueDate;
  bool _isSaving = false;

  bool get _isEditing => widget.assignment != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.assignment?.title ?? '',
    );
    _dueDate = widget.assignment?.dueDate ?? _defaultDueDate();
  }

  static DateTime _defaultDueDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 3, 23, 59);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(context, initialDate: _dueDate);
    if (picked == null) return;

    // Keep the previously chosen time of day when only the date changes.
    setState(() {
      _dueDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _dueDate.hour,
        _dueDate.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showAppTimePicker(
      context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    if (picked == null) return;

    setState(() {
      _dueDate = DateTime(
        _dueDate.year,
        _dueDate.month,
        _dueDate.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final notifier = ref.read(assignmentListProvider.notifier);
    final navigator = Navigator.of(context);

    await runAction(context, () async {
      if (_isEditing) {
        await notifier.save(
          widget.assignment!.copyWith(
            title: _titleController.text.trim(),
            dueDate: _dueDate,
          ),
        );
      } else {
        await notifier.insert(
          Assignment(
            id: '',
            courseId: widget.courseId,
            title: _titleController.text.trim(),
            dueDate: _dueDate,
            isCompleted: false,
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
      title: _isEditing ? 'Edit assignment' : 'New assignment',
      actions: [
        SheetAction(
          label: _isEditing ? 'Save changes' : 'Add assignment',
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
              controller: _titleController,
              label: 'What is due?',
              icon: Icons.task_alt_rounded,
              textInputAction: TextInputAction.done,
              autofocus: !_isEditing,
              hintText: 'Lab 05, Quiz 3, Sprint demo',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Give the assignment a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _DateTimeRow(
              dueDate: _dueDate,
              onPickDate: _pickDate,
              onPickTime: _pickTime,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final DateTime dueDate;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _DateTimeRow({
    required this.dueDate,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, size: 18, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onPickDate,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppDate.weekdayDayMonth(dueDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppDate.describe(dueDate, isCompleted: false).longLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _PickerButton(label: AppDate.time(dueDate), onTap: onPickTime),
        ],
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PickerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

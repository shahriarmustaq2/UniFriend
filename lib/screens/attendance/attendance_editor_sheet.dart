import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/attendance_record.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/course_providers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/class_card.dart';
import '../../widgets/course_dropdown.dart';
import '../../widgets/date_field.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_sheet.dart';

/// Records a class outside the routine, such as a makeup class or a past date.
/// Pass [record] to correct or remove an existing mark.
Future<void> showAttendanceEditor(
  BuildContext context, {
  String? courseId,
  AttendanceRecord? record,
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) =>
        _AttendanceEditorSheet(courseId: courseId, record: record),
  );
}

/// Every mark recorded for one course, newest first. Tapping one edits it.
Future<void> showAttendanceHistory(BuildContext context, String courseId) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _AttendanceHistorySheet(courseId: courseId),
  );
}

class _AttendanceEditorSheet extends ConsumerStatefulWidget {
  final String? courseId;
  final AttendanceRecord? record;

  const _AttendanceEditorSheet({this.courseId, this.record});

  @override
  ConsumerState<_AttendanceEditorSheet> createState() =>
      _AttendanceEditorSheetState();
}

class _AttendanceEditorSheetState
    extends ConsumerState<_AttendanceEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late String? _courseId;
  late DateTime _heldOn;
  late AttendanceStatus _status;
  bool _isSaving = false;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    _courseId = widget.record?.courseId ?? widget.courseId;
    _heldOn = widget.record?.heldOn ?? AppDate.dayOf(DateTime.now());
    _status = widget.record?.status ?? AttendanceStatus.present;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final notifier = ref.read(attendanceListProvider.notifier);
    final navigator = Navigator.of(context);
    final record = widget.record;

    await runAction(context, () async {
      await notifier.mark(
        courseId: _courseId!,
        heldOn: _heldOn,
        // A correction overwrites its own mark. A new entry takes the next free
        // session, so it cannot silently replace a class already on that day.
        session: record?.session ?? notifier.nextSession(_courseId!, _heldOn),
        status: _status,
      );
      navigator.pop();
    });

    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _delete() async {
    final notifier = ref.read(attendanceListProvider.notifier);
    final navigator = Navigator.of(context);
    await runAction(context, () async {
      await notifier.delete(widget.record!.id);
      navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(courseByIdProvider)[_courseId];

    return GlassSheet(
      title: _isEditing ? 'Edit attendance' : 'Mark attendance',
      actions: [
        if (_isEditing)
          SheetAction(
            label: 'Remove',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onPressed: _isSaving ? null : _delete,
          ),
        SheetAction(
          label: 'Save',
          icon: Icons.check_rounded,
          onPressed: _save,
          isBusy: _isSaving,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A mark's identity is its course, day and session, so correcting
            // one changes only the status. Moving it means removing and re-adding.
            if (_isEditing)
              PickerBox(
                icon: Icons.event_rounded,
                label: course?.code ?? 'Course',
                value: AppDate.dayMonthYear(_heldOn),
              )
            else ...[
              CourseDropdown(
                value: _courseId,
                onChanged: (value) => setState(() => _courseId = value),
              ),
              const SizedBox(height: 14),
              DateField(
                label: 'Class date',
                value: _heldOn,
                onChanged: (value) =>
                    setState(() => _heldOn = AppDate.dayOf(value)),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                for (final status in AttendanceStatus.values) ...[
                  ChoicePill(
                    label: status.label,
                    color: status.color,
                    selected: status == _status,
                    onTap: () => setState(() => _status = status),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceHistorySheet extends ConsumerWidget {
  final String courseId;

  const _AttendanceHistorySheet({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseByIdProvider)[courseId];
    final records = ref.watch(attendanceForCourseProvider(courseId));

    return GlassSheet(
      title: '${course?.code ?? 'Course'} attendance',
      actions: [
        SheetAction(
          label: 'Mark a class',
          icon: Icons.add_rounded,
          onPressed: () => showAttendanceEditor(context, courseId: courseId),
        ),
      ],
      child: records.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No classes marked yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            )
          : Column(
              children: [
                for (final record in records) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showAttendanceEditor(context, record: record),
                    child: GlassContainer(
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppDate.weekdayDayMonth(record.heldOn) +
                                  (record.session > 1
                                      ? '  ·  class ${record.session}'
                                      : ''),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            record.status.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: record.status.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/study_session.dart';
import '../../providers/study_providers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/course_dropdown.dart';
import '../../widgets/date_field.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';

/// Opens the study log editor. Pass [session] to edit, or [minutes] to prefill
/// the length from the timer. Completes with true once something was saved.
Future<bool> showStudySessionEditor(
  BuildContext context, {
  StudySession? session,
  int? minutes,
  String? courseId,
}) async {
  final saved = await showGlassSheet<bool>(
    context: context,
    builder: (context) => _StudySessionEditorSheet(
      session: session,
      minutes: minutes,
      courseId: courseId,
    ),
  );
  return saved ?? false;
}

class _StudySessionEditorSheet extends ConsumerStatefulWidget {
  final StudySession? session;
  final int? minutes;
  final String? courseId;

  const _StudySessionEditorSheet({this.session, this.minutes, this.courseId});

  @override
  ConsumerState<_StudySessionEditorSheet> createState() =>
      _StudySessionEditorSheetState();
}

class _StudySessionEditorSheetState
    extends ConsumerState<_StudySessionEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _topicController;
  late final TextEditingController _minutesController;
  late final TextEditingController _notesController;
  late String? _courseId;
  late DateTime _studiedOn;
  bool _isSaving = false;

  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _courseId = session?.courseId ?? widget.courseId;
    _studiedOn = session?.studiedOn ?? AppDate.dayOf(DateTime.now());
    _topicController = TextEditingController(text: session?.topic ?? '');
    _minutesController = TextEditingController(
      text: '${session?.minutes ?? widget.minutes ?? 30}',
    );
    _notesController = TextEditingController(text: session?.notes ?? '');
  }

  @override
  void dispose() {
    _topicController.dispose();
    _minutesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final notifier = ref.read(studySessionListProvider.notifier);
    final navigator = Navigator.of(context);
    final notes = _notesController.text.trim();
    final draft = StudySession(
      id: widget.session?.id ?? '',
      courseId: _courseId,
      topic: _topicController.text.trim(),
      minutes: int.parse(_minutesController.text.trim()),
      studiedOn: _studiedOn,
      notes: notes.isEmpty ? null : notes,
      createdAt: widget.session?.createdAt ?? DateTime.now(),
    );

    await runAction(context, () async {
      if (_isEditing) {
        await notifier.save(draft);
      } else {
        await notifier.insert(draft);
      }
      navigator.pop(true);
    });

    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _delete() async {
    final confirmed = await confirm(
      context,
      title: 'Delete this session?',
      message: '"${widget.session!.topic}" leaves your study log for good.',
    );
    if (!confirmed || !mounted) return;
    final notifier = ref.read(studySessionListProvider.notifier);
    final navigator = Navigator.of(context);
    await runAction(context, () async {
      await notifier.delete(widget.session!.id);
      navigator.pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      title: _isEditing ? 'Edit study session' : 'Log study session',
      actions: [
        if (_isEditing)
          SheetAction(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onPressed: _isSaving ? null : _delete,
          ),
        SheetAction(
          label: _isEditing ? 'Save' : 'Log it',
          icon: _isEditing ? Icons.save_rounded : Icons.check_rounded,
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
              controller: _topicController,
              label: 'What did you study?',
              icon: Icons.edit_note_rounded,
              textInputAction: TextInputAction.next,
              autofocus: !_isEditing,
              hintText: 'Page replacement algorithms',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name the topic';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            CourseDropdown(
              value: _courseId,
              noneLabel: 'General study',
              onChanged: (value) => setState(() => _courseId = value),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GlassTextField(
                    controller: _minutesController,
                    label: 'Minutes',
                    icon: Icons.timer_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final minutes = int.tryParse((value ?? '').trim());
                      if (minutes == null) return 'Enter minutes';
                      if (minutes < 1 || minutes > 1440) return '1 to 1440';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DateField(
                    label: 'Date',
                    value: _studiedOn,
                    onChanged: (value) =>
                        setState(() => _studiedOn = AppDate.dayOf(value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GlassTextField(
              controller: _notesController,
              label: 'Notes (optional)',
              icon: Icons.notes_rounded,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

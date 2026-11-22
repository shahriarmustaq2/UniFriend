import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ct_mark.dart';
import '../../providers/ct_mark_providers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/course_dropdown.dart';
import '../../widgets/date_field.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';

/// Opens the CT editor. Pass [mark] to edit, omit it to create.
Future<void> showCtMarkEditor(
  BuildContext context, {
  String? courseId,
  CtMark? mark,
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _CtMarkEditorSheet(courseId: courseId, mark: mark),
  );
}

class _CtMarkEditorSheet extends ConsumerStatefulWidget {
  final String? courseId;
  final CtMark? mark;

  const _CtMarkEditorSheet({this.courseId, this.mark});

  @override
  ConsumerState<_CtMarkEditorSheet> createState() => _CtMarkEditorSheetState();
}

class _CtMarkEditorSheetState extends ConsumerState<_CtMarkEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _obtainedController;
  late final TextEditingController _totalController;
  late String? _courseId;
  late DateTime _heldOn;
  bool _isSaving = false;

  bool get _isEditing => widget.mark != null;

  static String _number(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  void initState() {
    super.initState();
    final mark = widget.mark;
    _courseId = mark?.courseId ?? widget.courseId;
    _heldOn = mark?.heldOn ?? AppDate.dayOf(DateTime.now());
    _titleController = TextEditingController(
      text: mark?.title ?? _suggestedTitle(_courseId),
    );
    _obtainedController = TextEditingController(
      text: mark == null ? '' : _number(mark.obtained),
    );
    _totalController = TextEditingController(
      text: mark == null ? '20' : _number(mark.total),
    );
  }

  /// "CT 3" when the course already has two.
  String _suggestedTitle(String? courseId) {
    if (courseId == null) return 'CT 1';
    return 'CT ${ref.read(ctMarksForCourseProvider(courseId)).length + 1}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _obtainedController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final notifier = ref.read(ctMarkListProvider.notifier);
    final navigator = Navigator.of(context);
    final draft = CtMark(
      id: widget.mark?.id ?? '',
      courseId: _courseId!,
      title: _titleController.text.trim(),
      obtained: double.parse(_obtainedController.text.trim()),
      total: double.parse(_totalController.text.trim()),
      heldOn: _heldOn,
      createdAt: widget.mark?.createdAt ?? DateTime.now(),
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
    final confirmed = await confirm(
      context,
      title: 'Delete this mark?',
      message: '"${widget.mark!.title}" will be removed for good.',
    );
    if (!confirmed || !mounted) return;
    final notifier = ref.read(ctMarkListProvider.notifier);
    final navigator = Navigator.of(context);
    await runAction(context, () async {
      await notifier.delete(widget.mark!.id);
      navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final numberFilter = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);

    return GlassSheet(
      title: _isEditing ? 'Edit CT mark' : 'New CT mark',
      actions: [
        if (_isEditing)
          SheetAction(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onPressed: _isSaving ? null : _delete,
          ),
        SheetAction(
          label: _isEditing ? 'Save' : 'Add mark',
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
              onChanged: (value) => setState(() {
                _courseId = value;
                if (!_isEditing) _titleController.text = _suggestedTitle(value);
              }),
            ),
            const SizedBox(height: 14),
            GlassTextField(
              controller: _titleController,
              label: 'Test name',
              icon: Icons.quiz_outlined,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name this test';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GlassTextField(
                    controller: _obtainedController,
                    label: 'Marks got',
                    icon: Icons.check_circle_outline_rounded,
                    keyboardType: numberKeyboard,
                    inputFormatters: numberFilter,
                    textInputAction: TextInputAction.next,
                    autofocus: !_isEditing && _courseId != null,
                    validator: (value) {
                      final obtained = double.tryParse((value ?? '').trim());
                      if (obtained == null) return 'Enter a number';
                      final total = double.tryParse(
                        _totalController.text.trim(),
                      );
                      if (total != null && obtained > total) {
                        return 'More than the total';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassTextField(
                    controller: _totalController,
                    label: 'Out of',
                    icon: Icons.pin_outlined,
                    keyboardType: numberKeyboard,
                    inputFormatters: numberFilter,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      final total = double.tryParse((value ?? '').trim());
                      if (total == null) return 'Enter a number';
                      // The column is numeric(5, 2).
                      if (total <= 0 || total > 999) {
                        return 'Above 0, up to 999';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DateField(
              label: 'Test date',
              value: _heldOn,
              onChanged: (value) => setState(() => _heldOn = value),
            ),
          ],
        ),
      ),
    );
  }
}

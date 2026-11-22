import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notice.dart';
import '../../providers/notice_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';

/// Opens the notice editor. Pass [notice] to edit, omit it to create.
Future<void> showNoticeEditor(BuildContext context, {Notice? notice}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _NoticeEditorSheet(notice: notice),
  );
}

class _NoticeEditorSheet extends ConsumerStatefulWidget {
  final Notice? notice;

  const _NoticeEditorSheet({this.notice});

  @override
  ConsumerState<_NoticeEditorSheet> createState() => _NoticeEditorSheetState();
}

class _NoticeEditorSheetState extends ConsumerState<_NoticeEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  /// Held locally rather than read back off [widget.notice], which is a
  /// snapshot taken when the sheet opened and would not reflect the toggle.
  late bool _isPinned;
  bool _isSaving = false;

  bool get _isEditing => widget.notice != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notice?.title ?? '');
    _bodyController = TextEditingController(text: widget.notice?.body ?? '');
    _isPinned = widget.notice?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final notifier = ref.read(noticeListProvider.notifier);
    final navigator = Navigator.of(context);

    await runAction(context, () async {
      final body = _bodyController.text.trim();
      final draft = Notice(
        id: widget.notice?.id ?? '',
        title: _titleController.text.trim(),
        body: body.isEmpty ? null : body,
        isPinned: _isPinned,
        createdAt: widget.notice?.createdAt ?? DateTime.now(),
      );
      if (_isEditing) {
        await notifier.save(draft);
      } else {
        await notifier.insert(draft);
      }
      navigator.pop();
    });

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      title: _isEditing ? 'Edit notice' : 'New notice',
      actions: [
        SheetAction(
          label: _isEditing ? 'Save changes' : 'Add notice',
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
              label: 'Title',
              icon: Icons.title_rounded,
              textInputAction: TextInputAction.next,
              autofocus: !_isEditing,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Give the notice a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            GlassTextField(
              controller: _bodyController,
              label: 'Details (optional)',
              icon: Icons.notes_rounded,
              maxLines: 5,
              hintText: 'Room number, time, link, anything you will forget',
            ),
            const SizedBox(height: 18),
            _PinRow(
              isPinned: _isPinned,
              enabled: !_isSaving,
              onChanged: (value) => setState(() => _isPinned = value),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pin toggle shown while editing, so pinning is reachable from both places.
class _PinRow extends StatelessWidget {
  final bool isPinned;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PinRow({
    required this.isPinned,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(
            isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            size: 18,
            color: isPinned ? AppColors.warning : Colors.white70,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pin to the top of Home',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Switch(
            value: isPinned,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

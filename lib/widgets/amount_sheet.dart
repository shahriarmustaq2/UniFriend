import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feedback.dart';
import 'glass_sheet.dart';
import 'glass_text_field.dart';

/// Asks for one number, for personal targets such as a budget or a study goal.
Future<void> showAmountSheet(
  BuildContext context, {
  required String title,
  required String label,
  required IconData icon,
  required double? initial,
  required double max,
  required Future<void> Function(double value) onSave,
  Future<void> Function()? onClear,
  String? hintText,
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _AmountSheet(
      title: title,
      label: label,
      icon: icon,
      initial: initial,
      max: max,
      onSave: onSave,
      onClear: onClear,
      hintText: hintText,
    ),
  );
}

class _AmountSheet extends StatefulWidget {
  final String title;
  final String label;
  final IconData icon;
  final double? initial;
  final double max;
  final Future<void> Function(double value) onSave;
  final Future<void> Function()? onClear;
  final String? hintText;

  const _AmountSheet({
    required this.title,
    required this.label,
    required this.icon,
    required this.initial,
    required this.max,
    required this.onSave,
    required this.onClear,
    required this.hintText,
  });

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == null
        ? ''
        : widget.initial!
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'\.?0+$'), ''),
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);

    await runAction(context, () async {
      await action();
      navigator.pop();
    });

    if (mounted) setState(() => _isSaving = false);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _run(() => widget.onSave(double.parse(_controller.text.trim())));
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      title: widget.title,
      actions: [
        if (widget.onClear != null && widget.initial != null)
          SheetAction(
            label: 'Remove',
            icon: Icons.backspace_outlined,
            isDestructive: true,
            onPressed: _isSaving ? null : () => _run(widget.onClear!),
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
        child: GlassTextField(
          controller: _controller,
          label: widget.label,
          icon: widget.icon,
          hintText: widget.hintText,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          validator: (value) {
            final number = double.tryParse((value ?? '').trim());
            if (number == null) return 'Enter a number';
            if (number < 0 || number > widget.max) {
              return 'Must be between 0 and ${widget.max.toStringAsFixed(0)}';
            }
            return null;
          },
        ),
      ),
    );
  }
}

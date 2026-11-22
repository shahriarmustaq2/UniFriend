import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';

/// Asks for an email address and sends the reset link.
Future<void> showForgotPasswordSheet(BuildContext context, {String? email}) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => _ForgotPasswordSheet(email: email),
  );
}

class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  final String? email;

  const _ForgotPasswordSheet({this.email});

  @override
  ConsumerState<_ForgotPasswordSheet> createState() =>
      _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.email ?? '',
  );
  bool _isSending = false;
  bool _sent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);

    final repo = ref.read(authRepositoryProvider);
    await runAction(context, () async {
      await repo.sendPasswordReset(_controller.text.trim());
      if (mounted) setState(() => _sent = true);
    });

    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return GlassSheet(
        title: 'Check your email',
        actions: [
          SheetAction(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        child: Text(
          'If an account exists for ${_controller.text.trim()}, a reset link is '
          'on its way. Open it on this device to choose a new password.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      );
    }

    return GlassSheet(
      title: 'Reset your password',
      actions: [
        SheetAction(
          label: 'Send reset link',
          icon: Icons.send_rounded,
          onPressed: _send,
          isBusy: _isSending,
        ),
      ],
      child: Form(
        key: _formKey,
        child: GlassTextField(
          controller: _controller,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofocus: widget.email == null || widget.email!.isEmpty,
          validator: (value) {
            if (value == null || !value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
      ),
    );
  }
}

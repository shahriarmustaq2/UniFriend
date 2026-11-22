import 'package:flutter/material.dart';

import 'glass_text_field.dart';

/// New password and its confirmation. The owner supplies the controllers and the
/// surrounding `Form`.
class NewPasswordFields extends StatelessWidget {
  final TextEditingController password;
  final TextEditingController confirmation;

  const NewPasswordFields({
    super.key,
    required this.password,
    required this.confirmation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassTextField(
          controller: password,
          label: 'New password',
          icon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        GlassTextField(
          controller: confirmation,
          label: 'Confirm new password',
          icon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.done,
          validator: (value) {
            if (value != password.text) return 'Passwords do not match';
            return null;
          },
        ),
      ],
    );
  }
}

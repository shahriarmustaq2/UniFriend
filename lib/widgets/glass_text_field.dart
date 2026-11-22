import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// The single text field style used by every form in the app.
///
/// Extracted from the login screen so the sign-up sheet, notice editor and
/// course form all match the original frosted input exactly.
class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final String? hintText;
  final int maxLines;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.hintText,
    this.maxLines = 1,
    this.autofocus = false,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      maxLines: maxLines,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      cursorColor: AppColors.primary,
      decoration: decoration(
        label: label,
        icon: icon,
        hintText: hintText,
        suffixIcon: suffixIcon,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  /// Shared with the app's dropdowns, so every form control looks the same.
  static InputDecoration decoration({
    required String label,
    required IconData icon,
    String? hintText,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, size: 20, color: AppColors.textHint),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 15),
      prefixIconColor: AppColors.textHint,
      alignLabelWithHint: alignLabelWithHint,
      border: _border(Colors.white.withValues(alpha: 0.09)),
      enabledBorder: _border(Colors.white.withValues(alpha: 0.09)),
      focusedBorder: _border(AppColors.primary, 1.5),
      errorBorder: _border(AppColors.error),
      focusedErrorBorder: _border(AppColors.error, 1.5),
    );
  }

  static OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? maxLength;
  final bool? enableSuggestions;
  final bool autocorrect;
  final Iterable<String>? autofillHints;
  final void Function(String)? onChanged;
  final Widget? counter;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.enableSuggestions,
    this.autocorrect = true,
    this.autofillHints,
    this.onChanged,
    this.counter,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      enableSuggestions: enableSuggestions ?? true,
      autocorrect: autocorrect,
      autofillHints: autofillHints,
      onChanged: onChanged,
      style: TextStyle(
        color: context.txtPrimary,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.txtSecondary),
        hintText: hint,
        hintStyle: TextStyle(color: context.txtMuted),
        prefixIcon: Icon(prefixIcon, color: context.txtMuted, size: 20),
        suffixIcon: suffixIcon,
        counter: counter,
      ),
    );
  }
}

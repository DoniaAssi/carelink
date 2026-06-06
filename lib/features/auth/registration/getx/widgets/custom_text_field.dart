import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    this.controller,
    this.hintText,
    this.helperBelow,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.obscureText = false,
    this.autocorrect,
    this.enableSuggestions,
    this.suffix,
    this.readOnly = false,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? helperBelow;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final bool obscureText;
  final bool? autocorrect;
  final bool? enableSuggestions;
  final Widget? suffix;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints?.toList(),
          validator: validator,
          autocorrect: autocorrect ?? true,
          enableSuggestions: enableSuggestions ?? true,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: icon == null ? null : Icon(icon, size: 20),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
          ),
        ),
        if (helperBelow != null) ...[
          const SizedBox(height: 6),
          Text(helperBelow!, style: const TextStyle(fontSize: 12)),
        ],
      ],
    );
  }
}

class PasswordVisibilityIcon extends StatelessWidget {
  const PasswordVisibilityIcon({required this.obscure, required this.onToggle, super.key});

  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
      onPressed: onToggle,
    );
  }
}

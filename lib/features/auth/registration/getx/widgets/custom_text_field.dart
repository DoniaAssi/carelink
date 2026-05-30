import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';

/// Matches [LoginScreen] `_buildTextField`: hint-only, no floating label.
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.helperBelow,
    this.suffix,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final String? helperBelow;
  final Widget? suffix;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          readOnly: readOnly,
          onTap: onTap,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: p.inkDark,
          ),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            floatingLabelBehavior: FloatingLabelBehavior.never,
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              color: p.inkMuted,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: p.isDark
                ? const Color(0xFF123640).withValues(alpha: 0.55)
                : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
            prefixIcon: Icon(icon, color: p.inkMuted, size: 22),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.9),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.9),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red.shade300, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
            ),
          ),
        ),
        if (helperBelow != null) ...[
          const SizedBox(height: 6),
          Text(
            helperBelow!,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: p.inkMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class PasswordVisibilityIcon extends StatelessWidget {
  const PasswordVisibilityIcon({
    super.key,
    required this.obscure,
    required this.onToggle,
  });

  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: p.inkMuted,
            size: 22,
          ),
        ),
      ),
    );
  }
}

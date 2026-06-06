import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/services/auth_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

class ForgotPasswordSheet {
  static Future<void> show(BuildContext context, {String? initialEmail}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ForgotPasswordScreen(initialEmail: initialEmail),
        fullscreenDialog: true,
      ),
    );
  }
}

enum _ResetStep { email, code, password, success }

class _ForgotPasswordScreen extends StatefulWidget {
  const _ForgotPasswordScreen({this.initialEmail});

  final String? initialEmail;

  @override
  State<_ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<_ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;
  String? _resetToken;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _message(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.sendForgotPasswordCode(email: _emailController.text);
      if (!mounted) return;
      setState(() => _step = _ResetStep.code);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _auth.verifyForgotPasswordCode(
        email: _emailController.text,
        code: _codeController.text,
      );
      if (!mounted) return;
      setState(() {
        _resetToken = token;
        _step = _ResetStep.password;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final token = _resetToken;
    if (token == null || token.isEmpty) {
      setState(() => _error = context.tr('auth.invalidOtp'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.resetForgottenPassword(
        resetToken: token,
        newPassword: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _step = _ResetStep.success);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return context.tr('auth.enterEmail');
    if (!AuthService.isValidEmailFormat(email)) {
      return context.tr('auth.enterValidEmail');
    }
    return null;
  }

  String? _codeValidator(String? value) {
    if (!RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')) {
      return context.tr('auth.codeRequired6');
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final password = value ?? '';
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$').hasMatch(password)) {
      return context.tr('auth.passwordRequirements');
    }
    return null;
  }

  String? _confirmationValidator(String? value) {
    if (value != _passwordController.text) {
      return context.tr('auth.passwordsNoMatch');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: palette.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: palette.inkDark,
                  ),
                  const Spacer(),
                  const CarelinkBrandLogo(height: 28),
                  const Spacer(),
                  const PatientHeaderActions(color: AppColors.primary),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    20 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _buildCard(palette),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(CarelinkPalette palette) {
    return Container(
      key: ValueKey(_step),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.25 : 0.07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stepIcon(),
              const SizedBox(height: 18),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: palette.inkDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: palette.inkMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (_step == _ResetStep.email) _emailStep(palette),
              if (_step == _ResetStep.code) _codeStep(palette),
              if (_step == _ResetStep.password) _passwordStep(palette),
              if (_step == _ResetStep.success) _successStep(),
              if (_error != null && _step != _ResetStep.success) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.red.shade400,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepIcon() {
    final icon = switch (_step) {
      _ResetStep.email => Icons.mail_outline_rounded,
      _ResetStep.code => Icons.verified_user_outlined,
      _ResetStep.password => Icons.lock_reset_rounded,
      _ResetStep.success => Icons.check_circle_outline_rounded,
    };
    return Icon(icon, size: 52, color: AppColors.primary);
  }

  String get _title => switch (_step) {
    _ResetStep.email => context.tr('auth.forgotPasswordTitle'),
    _ResetStep.code => context.tr('auth.verifyYourEmail'),
    _ResetStep.password => context.tr('auth.createNewPassword'),
    _ResetStep.success => context.tr('auth.passwordResetSuccess'),
  };

  String get _subtitle => switch (_step) {
    _ResetStep.email => context.tr('auth.forgotPasswordBody'),
    _ResetStep.code => context.tr('auth.verifyEmailSubtitle'),
    _ResetStep.password => context.tr('auth.createNewPasswordSubtitle'),
    _ResetStep.success => context.tr('auth.passwordResetSuccessBody'),
  };

  Widget _emailStep(CarelinkPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          palette,
          controller: _emailController,
          hint: context.tr('auth.email'),
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          validator: _emailValidator,
        ),
        const SizedBox(height: 18),
        _primaryButton(context.tr('auth.sendCode'), _sendCode),
      ],
    );
  }

  Widget _codeStep(CarelinkPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: _field(
            palette,
            controller: _codeController,
            hint: context.tr('auth.otpCode'),
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: _codeValidator,
          ),
        ),
        const SizedBox(height: 18),
        _primaryButton(context.tr('auth.verifyAndContinue'), _verifyCode),
        TextButton(
          onPressed: _loading ? null : _sendCode,
          child: Text(context.tr('auth.resendCode')),
        ),
      ],
    );
  }

  Widget _passwordStep(CarelinkPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          palette,
          controller: _passwordController,
          hint: context.tr('auth.newPassword'),
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.newPassword],
          validator: _passwordValidator,
          suffix: _visibilityButton(
            obscured: _obscurePassword,
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 14),
        _field(
          palette,
          controller: _confirmPasswordController,
          hint: context.tr('auth.confirmNewPassword'),
          icon: Icons.lock_outline_rounded,
          obscureText: _obscureConfirmation,
          autofillHints: const [AutofillHints.newPassword],
          validator: _confirmationValidator,
          suffix: _visibilityButton(
            obscured: _obscureConfirmation,
            onPressed: () =>
                setState(() => _obscureConfirmation = !_obscureConfirmation),
          ),
        ),
        const SizedBox(height: 18),
        _primaryButton(context.tr('auth.resetPassword'), _resetPassword),
      ],
    );
  }

  Widget _successStep() {
    return _primaryButton(
      context.tr('auth.backToLogin'),
      () => Navigator.of(context).pop(),
    );
  }

  Widget _field(
    CarelinkPalette palette, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Iterable<String>? autofillHints,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: !obscureText,
      style: GoogleFonts.inter(color: palette.inkDark, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: palette.inkMuted),
        suffixIcon: suffix,
        filled: true,
        fillColor: palette.isDark
            ? const Color(0xFF123640).withValues(alpha: 0.55)
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _visibilityButton({
    required bool obscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: _loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}

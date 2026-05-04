import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_nav.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/auth_service.dart';

enum _ForgotPhase {
  chooseMethod,
  emailRequestCode,
  emailEnterCode,
  phoneRequestCode,
  phoneEnterCode,
  newPassword,
}

/// Forgot password: verify email or phone ownership with codes, then set a new password.
class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({super.key, this.initialEmail});

  final String? initialEmail;

  static Future<void> show(BuildContext context, {String? initialEmail}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ForgotPasswordSheet(initialEmail: initialEmail),
    );
  }

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _emailCodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phoneCodeCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  _ForgotPhase _phase = _ForgotPhase.chooseMethod;

  bool _loading = false;
  Timer? _resendTimer;
  int _resendSeconds = 0;
  String? _resetToken;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEmail?.trim();
    if (initial != null && initial.isNotEmpty) {
      _emailCtrl.text = initial;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _emailCodeCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneCodeCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _toast(String msg, {Color? color}) {
    final m = appScaffoldMessengerKey.currentState;
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? const Color(0xFF1F2933),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _errorMessage(Object e) {
    if (e is AuthServiceException) {
      return e.retryAfterSeconds != null
          ? '${e.message} (${e.retryAfterSeconds}s)'
          : e.message;
    }
    final s = e.toString().replaceFirst('Exception: ', '');
    if (s.toLowerCase().contains('network') ||
        s.toLowerCase().contains('failed host lookup') ||
        s.toLowerCase().contains('connection refused')) {
      return 'Cannot reach server at ${ApiService.baseUrl}.';
    }
    return s;
  }

  void _maybeLogDevCode(SendVerificationResult r) {
    AuthService.logDevCodeIfAny(r.devCode);
    if (kDebugMode && r.devCode != null && r.devCode!.isNotEmpty) {
      _toast('Dev: code ${r.devCode}', color: Colors.blueGrey.shade800);
    }
  }

  Future<void> _sendEmailResetCode() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _toast(context.tr('auth.enterEmail'));
      return;
    }
    if (!AuthService.isValidEmailFormat(email)) {
      _toast(context.tr('auth.enterValidEmail'));
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await _auth.sendEmailVerificationCode(
        email: email,
        purpose: VerificationPurpose.passwordReset,
      );
      if (!mounted) return;
      _maybeLogDevCode(r);
      _emailCodeCtrl.clear();
      setState(() => _phase = _ForgotPhase.emailEnterCode);
      _startResendCooldown();
      _toast(
        r.userMessage,
        color: Colors.green.shade700,
      );
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      _toast(e.message, color: Colors.red.shade700);
    } catch (e) {
      if (!mounted) return;
      _toast(_errorMessage(e), color: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyEmailResetCode() async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final result = await _auth.verifyEmailCode(
        email: _emailCtrl.text.trim(),
        code: _emailCodeCtrl.text,
        purpose: VerificationPurpose.passwordReset,
      );
      if (!mounted) return;
      final token = result.resetToken;
      if (token == null || token.isEmpty) {
        _toast(context.tr('auth.invalidVerificationCode'),
            color: Colors.red.shade700,);
        return;
      }
      setState(() {
        _resetToken = token;
        _phase = _ForgotPhase.newPassword;
      });
      _toast(
        context.tr('auth.emailVerifiedSuccess'),
        color: Colors.green.shade700,
      );
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      _toast(
        e.message.toLowerCase().contains('invalid') ||
                e.message.toLowerCase().contains('expired') ||
                e.message.toLowerCase().contains('too many')
            ? context.tr('auth.invalidVerificationCode')
            : e.message,
        color: Colors.red.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      _toast(_errorMessage(e), color: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPhoneResetCode() async {
    FocusScope.of(context).unfocus();
    final digits = AuthService.normalizePhoneDigits(_phoneCtrl.text);
    if (!AuthService.isValidPhoneLength(digits)) {
      _toast(context.tr('auth.invalidPhone'));
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await _auth.sendPhoneVerificationCode(
        phoneDigits: digits,
        purpose: VerificationPurpose.passwordReset,
      );
      if (!mounted) return;
      _maybeLogDevCode(r);
      _phoneCodeCtrl.clear();
      setState(() => _phase = _ForgotPhase.phoneEnterCode);
      _startResendCooldown();
      _toast(
        r.userMessage,
        color: Colors.green.shade700,
      );
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      _toast(e.message, color: Colors.red.shade700);
    } catch (e) {
      if (!mounted) return;
      _toast(_errorMessage(e), color: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyPhoneResetCode() async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final result = await _auth.verifyPhoneCode(
        phoneDigits: AuthService.normalizePhoneDigits(_phoneCtrl.text),
        code: _phoneCodeCtrl.text,
        purpose: VerificationPurpose.passwordReset,
      );
      if (!mounted) return;
      final token = result.resetToken;
      if (token == null || token.isEmpty) {
        _toast(context.tr('auth.invalidVerificationCode'),
            color: Colors.red.shade700,);
        return;
      }
      setState(() {
        _resetToken = token;
        _phase = _ForgotPhase.newPassword;
      });
      _toast(
        context.tr('auth.phoneVerifiedSuccess'),
        color: Colors.green.shade700,
      );
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      _toast(
        e.message.toLowerCase().contains('invalid') ||
                e.message.toLowerCase().contains('expired') ||
                e.message.toLowerCase().contains('too many')
            ? context.tr('auth.invalidVerificationCode')
            : e.message,
        color: Colors.red.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      _toast(_errorMessage(e), color: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitNewPassword() async {
    FocusScope.of(context).unfocus();
    final token = _resetToken;
    if (token == null || token.isEmpty) {
      _toast(context.tr('auth.invalidVerificationCode'));
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.completePasswordReset(
        resetToken: token,
        newPassword: _newPwCtrl.text,
        confirmPassword: _confirmPwCtrl.text,
      );
      if (!mounted) return;
      _toast(
        'Password updated. You can sign in with your new password.',
        color: Colors.green.shade700,
      );
      Navigator.pop(context);
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      _toast(e.message, color: Colors.red.shade700);
    } catch (e) {
      if (!mounted) return;
      _toast(_errorMessage(e), color: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _strongPw(String s) {
    return RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$').hasMatch(s);
  }

  void _goBack() {
    setState(() {
      switch (_phase) {
        case _ForgotPhase.newPassword:
          _resetToken = null;
          _phase = _ForgotPhase.chooseMethod;
          break;
        case _ForgotPhase.emailEnterCode:
          _phase = _ForgotPhase.emailRequestCode;
          _emailCodeCtrl.clear();
          break;
        case _ForgotPhase.emailRequestCode:
          _phase = _ForgotPhase.chooseMethod;
          break;
        case _ForgotPhase.phoneEnterCode:
          _phase = _ForgotPhase.phoneRequestCode;
          _phoneCodeCtrl.clear();
          break;
        case _ForgotPhase.phoneRequestCode:
          _phase = _ForgotPhase.chooseMethod;
          break;
        case _ForgotPhase.chooseMethod:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(
            color: p.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.border.withValues(alpha: 0.65),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 12, 22, 20 + bottom + viewInsets),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: p.stroke,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (_phase != _ForgotPhase.chooseMethod)
                      IconButton(
                        onPressed: _loading ? null : _goBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: p.inkDark,
                      ),
                    Expanded(
                      child: Text(
                        context.tr('auth.forgotPasswordTitle'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: p.inkDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),
                if (_phase == _ForgotPhase.chooseMethod) ...[
                  Text(
                    context.tr('auth.chooseResetMethod'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: p.inkMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _methodTile(
                    p,
                    icon: Icons.mail_outline_rounded,
                    title: context.tr('auth.resetViaEmail'),
                    subtitle: context.tr('auth.forgotPasswordEmailSubtitle'),
                    onTap: _loading
                        ? null
                        : () => setState(
                              () => _phase = _ForgotPhase.emailRequestCode,
                            ),
                  ),
                  const SizedBox(height: 10),
                  _methodTile(
                    p,
                    icon: Icons.sms_outlined,
                    title: context.tr('auth.resetViaPhone'),
                    subtitle: context.tr('auth.forgotPasswordPhoneSubtitle'),
                    onTap: _loading
                        ? null
                        : () => setState(
                              () => _phase = _ForgotPhase.phoneRequestCode,
                            ),
                  ),
                ],
                if (_phase == _ForgotPhase.emailRequestCode) ...[
                  Text(
                    context.tr('auth.forgotPasswordEmailSubtitle'),
                    style: GoogleFonts.inter(fontSize: 13, color: p.inkMuted),
                  ),
                  const SizedBox(height: 14),
                  _field(
                    p,
                    controller: _emailCtrl,
                    hint: context.tr('auth.email'),
                    keyboard: TextInputType.emailAddress,
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),
                  _primaryButton(
                    p,
                    label: context.tr('auth.sendCode'),
                    onPressed: _loading ? null : _sendEmailResetCode,
                    loading: _loading,
                  ),
                ],
                if (_phase == _ForgotPhase.emailEnterCode) ...[
                  Text(
                    context.tr('auth.enterCodeHint'),
                    style: GoogleFonts.inter(fontSize: 13, color: p.inkMuted),
                  ),
                  const SizedBox(height: 14),
                  _field(
                    p,
                    controller: _emailCodeCtrl,
                    hint: context.tr('auth.otpCode'),
                    keyboard: TextInputType.number,
                    icon: Icons.pin_outlined,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed:
                        (_loading || _resendSeconds > 0) ? null : _sendEmailResetCode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _resendSeconds > 0
                          ? context.tr(
                              'auth.resendIn',
                              args: {'seconds': _resendSeconds.toString()},
                            )
                          : context.tr('auth.resendCode'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _primaryButton(
                    p,
                    label: context.tr('auth.verifyAndContinue'),
                    onPressed: _loading ? null : _verifyEmailResetCode,
                    loading: _loading,
                  ),
                ],
                if (_phase == _ForgotPhase.phoneRequestCode) ...[
                  Text(
                    context.tr('auth.forgotPasswordPhoneSubtitle'),
                    style: GoogleFonts.inter(fontSize: 13, color: p.inkMuted),
                  ),
                  const SizedBox(height: 14),
                  _field(
                    p,
                    controller: _phoneCtrl,
                    hint: context.tr('auth.phone'),
                    keyboard: TextInputType.number,
                    icon: Icons.phone_outlined,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 16),
                  _primaryButton(
                    p,
                    label: context.tr('auth.sendCode'),
                    onPressed: _loading ? null : _sendPhoneResetCode,
                    loading: _loading,
                  ),
                ],
                if (_phase == _ForgotPhase.phoneEnterCode) ...[
                  Text(
                    context.tr('auth.enterCodeHint'),
                    style: GoogleFonts.inter(fontSize: 13, color: p.inkMuted),
                  ),
                  const SizedBox(height: 14),
                  _field(
                    p,
                    controller: _phoneCodeCtrl,
                    hint: context.tr('auth.otpCode'),
                    keyboard: TextInputType.number,
                    icon: Icons.pin_outlined,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed:
                        (_loading || _resendSeconds > 0) ? null : _sendPhoneResetCode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _resendSeconds > 0
                          ? context.tr(
                              'auth.resendIn',
                              args: {'seconds': _resendSeconds.toString()},
                            )
                          : context.tr('auth.resendCode'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _primaryButton(
                    p,
                    label: context.tr('auth.verifyAndContinue'),
                    onPressed: _loading ? null : _verifyPhoneResetCode,
                    loading: _loading,
                  ),
                ],
                if (_phase == _ForgotPhase.newPassword) ...[
                  _field(
                    p,
                    controller: _newPwCtrl,
                    hint: context.tr('auth.newPassword'),
                    obscure: true,
                    icon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    p,
                    controller: _confirmPwCtrl,
                    hint: context.tr('auth.confirmNewPassword'),
                    obscure: true,
                    icon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '8+ characters with upper, lower, and number.',
                    style: GoogleFonts.inter(fontSize: 12, color: p.inkMuted),
                  ),
                  const SizedBox(height: 14),
                  _primaryButton(
                    p,
                    label: context.tr('auth.resetPassword'),
                    onPressed: _loading
                        ? null
                        : () {
                            if (!_strongPw(_newPwCtrl.text)) {
                              _toast(
                                'Use 8+ chars with upper, lower, and number.',
                                color: Colors.orange.shade900,
                              );
                              return;
                            }
                            _submitNewPassword();
                          },
                    loading: _loading,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _methodTile(
    CarelinkPalette p, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: p.isDark
          ? const Color(0xFF123640).withValues(alpha: 0.55)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        color: p.inkDark,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: p.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    CarelinkPalette p, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      autocorrect: false,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: p.inkDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: p.inkMuted, fontSize: 15),
        prefixIcon: Icon(icon, color: p.inkMuted, size: 22),
        filled: true,
        fillColor: p.isDark
            ? const Color(0xFF123640).withValues(alpha: 0.55)
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _primaryButton(
    CarelinkPalette p, {
    required String label,
    required VoidCallback? onPressed,
    required bool loading,
  }) {
    return SizedBox(
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: loading
                ? [
                    AppColors.primary.withValues(alpha: 0.55),
                    AppColors.primaryDark.withValues(alpha: 0.55),
                  ]
                : const [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

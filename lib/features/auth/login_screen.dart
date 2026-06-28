import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_nav.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/auth_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/features/admin/screens/admin_home_screen.dart';
import 'package:carelink/features/nurse/screens/nurse_dashboard.dart';
import 'package:carelink/features/doctors/doctor/doctor_rate_approval_screen.dart';
import 'forgot_password_sheet.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _prefsRemember = 'carelink_login_remember_me';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthService _auth = AuthService();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberPrefs();
  }

  Future<void> _loadRememberPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rememberMe = prefs.getBool(_prefsRemember) ?? true;
    });
  }

  Future<void> _persistRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsRemember, value);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmailFormat(String email) =>
      AuthService.isValidEmailFormat(email);

  void _showMessage(String text, {Color? color}) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color ?? const Color(0xFF1F2933),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildHeader(CarelinkPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CarelinkBrandLogo(
            height: 36,
            fallbackTextColor: p.inkDark,
            forceDarkLogo: p.isDark,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.tr('auth.signIn'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: p.inkDark,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('auth.loginSubtitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: p.inkMuted,
            fontSize: 13.5,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    CarelinkPalette p, {
    required String hintKey,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    final bool obscured = obscure;
    return TextFormField(
      controller: controller,
      obscureText: obscured,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: !obscured,
      validator: validator,
      textInputAction: obscured ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (obscured && !_isLoading) {
          loginUser();
        }
      },
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: p.inkDark,
      ),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.never,
        isDense: false,
        alignLabelWithHint: false,
        hintText: context.tr(hintKey),
        hintStyle: GoogleFonts.inter(
          color: p.inkMuted,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: p.isDark
            ? const Color(0xFF123640).withValues(alpha: 0.55)
            : Colors.white,
        prefixIcon: Icon(icon, color: p.inkMuted, size: 22),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
    );
  }

  Widget _buildPrimaryButton(CarelinkPalette p) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: _isLoading
                ? [
                    AppColors.primary.withValues(alpha: 0.55),
                    AppColors.primaryDark.withValues(alpha: 0.55),
                  ]
                : const [AppColors.primary, AppColors.primaryDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (_isLoading) ? null : loginUser,
            borderRadius: BorderRadius.circular(999),
            splashColor: Colors.white24,
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr('auth.signIn'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _signInContent(CarelinkPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTextField(
          p,
          hintKey: 'auth.email',
          icon: Icons.email_outlined,
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final s = v?.trim() ?? '';
            if (s.isEmpty) {
              return context.tr('auth.enterEmail');
            }
            if (!_isValidEmailFormat(s)) {
              return context.tr('auth.enterValidEmail');
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildTextField(
          p,
          hintKey: 'auth.password',
          icon: Icons.lock_outline_rounded,
          controller: passwordController,
          obscure: _obscurePassword,
          suffixIcon: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: p.inkMuted,
                  size: 22,
                ),
              ),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) {
              return context.tr('auth.passwordRequired');
            }
            return null;
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading
                    ? null
                    : () {
                        final next = !_rememberMe;
                        setState(() => _rememberMe = next);
                        _persistRememberMe(next);
                      },
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _rememberMe
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 24,
                    color: _rememberMe ? AppColors.primary : p.inkMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                context.tr('auth.rememberMe'),
                style: GoogleFonts.inter(color: p.inkMuted, fontSize: 13.5),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _isLoading
                  ? null
                  : () {
                      ForgotPasswordSheet.show(
                        context,
                        initialEmail: emailController.text.trim(),
                      );
                    },
              child: Text(
                context.tr('auth.forgotPassword'),
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPrimaryButton(p),
        const SizedBox(height: 22),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              Text(
                context.tr('auth.noAccount'),
                style: GoogleFonts.inter(color: p.inkMuted, fontSize: 13.5),
              ),
              InkWell(
                onTap: _isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                child: Text(
                  context.tr('auth.signUp'),
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loginFormCard(CarelinkPalette p, {required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 26,
        vertical: compact ? 22 : 26,
      ),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: p.isDark ? 0.96 : 1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: p.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.border.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.07),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(p),
            SizedBox(height: compact ? 22 : 26),
            _signInContent(p),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAuthSuccess(
    Map<String, dynamic> response, {
    String? successMessage,
  }) async {
    if (!mounted) return;

    final user = response['user'] as Map<String, dynamic>?;
    if (user == null) {
      _showMessage(context.tr('auth.invalidServerUser'));
      return;
    }

    final role = (user['role'] ?? user['userRole'] ?? '')
        .toString()
        .toLowerCase();
    final userId = (user['userId'] ?? user['id'] ?? '').toString();
    final userName = (user['fullName'] ?? user['name'] ?? 'User').toString();
    final userMap = Map<String, dynamic>.from(user);

    if (userMap['id'] == null && userMap['userId'] != null) {
      userMap['id'] = userMap['userId'];
    }
    if (userMap['fullName'] == null && userMap['name'] != null) {
      userMap['fullName'] = userMap['name'];
    }
    if (userMap['role'] == null && userMap['userRole'] != null) {
      userMap['role'] = userMap['userRole'];
    }

    final currentUser = User.fromJson(userMap);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_user_id', userId);
    await prefs.setString('session_display_name', userName);
    if (!mounted) return;

    _showMessage(
      successMessage ?? context.tr('auth.loginSuccessful'),
      color: Colors.green.shade700,
    );

    switch (role) {
      case 'patient':
        appNavigatorKey.currentState?.pushReplacementNamed(
          '/patient-home',
          arguments: {'userId': userId, 'displayName': userName},
        );
        break;
      case 'nurse':
        appNavigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => NurseDashboard(user: currentUser)),
        );
        break;
      case 'doctor':
        // Save doctor info to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('doctor_token', userId);
        await prefs.setString('doctor_userId', userId);
        await prefs.setString('doctor_fullName', userName);
        await prefs.setString(
          'doctor_email',
          (userMap['email'] ?? '').toString(),
        );
        await prefs.setString('doctor_role', role);

        if (!mounted) return;
        appNavigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(
            builder: (_) => DoctorRateApprovalScreen(doctorId: userId),
          ),
        );
        break;
      case 'admin':
        appNavigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => AdminHomeScreen(user: currentUser)),
        );
        break;
      default:
        _showMessage(context.tr('auth.unknownRole', args: {'role': role}));
    }
  }

  /// Email/password login via backend API (`ApiService`).
  Future<void> loginUser() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      _showMessage(context.tr('auth.checkForm'), color: Colors.orange.shade800);
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() => _isLoading = true);

    try {
      final response = await _auth.login(email, password);
      await _handleAuthSuccess(response);
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      String errorMsg = 'Login failed. Please try again.';

      if (errorString.contains('invalid credentials') ||
          errorString.contains('unauthorized') ||
          errorString.contains('401')) {
        errorMsg = 'Invalid email or password.';
      } else if (errorString.contains('network request failed') ||
          errorString.contains('failed to fetch') ||
          errorString.contains('connection refused') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('network error')) {
        errorMsg =
            'Cannot connect to backend at ${ApiService.baseUrl}. Make sure the backend is running and the base URL is correct.';
      } else if (errorString.contains('timeout')) {
        errorMsg =
            'The request timed out. Check if the backend server is running.';
      } else if (errorString.contains('cors')) {
        errorMsg =
            'CORS error. If you are running on Chrome, enable CORS in your backend.';
      } else {
        errorMsg = e.toString().replaceFirst('Exception: ', '');
      }

      _showMessage(errorMsg, color: Colors.red.shade700);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: p.isDark
          ? const Color(0xFF021018)
          : AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: CarelinkBackground(child: SizedBox.expand())),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final horizontalPad = w < 400 ? 16.0 : 22.0;
                final maxCardW = w < 520 ? double.infinity : 440.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 6,
                          end: 8,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                appNavigatorKey.currentState
                                    ?.pushNamedAndRemoveUntil(
                                      '/intro',
                                      (route) => false,
                                    );
                              },
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: p.inkDark,
                              iconSize: 24,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 42,
                                height: 42,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            const Spacer(),
                            PatientHeaderActions(color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPad,
                            0,
                            horizontalPad,
                            16 + viewInsets,
                          ),
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxCardW),
                              child: _loginFormCard(p, compact: w < 600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

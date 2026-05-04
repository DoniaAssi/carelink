import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_nav.dart';
import 'package:carelink/core/carelink_date_picker.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/auth_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupBackdropPainter extends CustomPainter {
  const _SignupBackdropPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final base = isDark ? const Color(0xFF03181F) : AppColors.background;
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        radius: 1.15,
        colors: [
          base,
          isDark ? const Color(0xFF05242D) : const Color(0xFFF5FBFA),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 56 : 48
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary.withValues(alpha: isDark ? 0.07 : 0.09);
    final p1 = ui.Path()
      ..moveTo(-40, size.height * 0.18)
      ..cubicTo(
        size.width * 0.25,
        -20,
        size.width * 0.45,
        size.height * 0.42,
        size.width + 60,
        size.height * 0.06,
      );
    canvas.drawPath(p1, wave);

    final wave2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 48 : 40
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primaryDark.withValues(alpha: isDark ? 0.08 : 0.07);
    final p2 = ui.Path()
      ..moveTo(size.width * 0.12, size.height + 56)
      ..cubicTo(
        size.width * 0.4,
        size.height * 0.68,
        size.width * 0.72,
        size.height * 0.92,
        size.width + 72,
        size.height * 0.48,
      );
    canvas.drawPath(p2, wave2);

    final dotPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.05);
    const step = 28.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        if (((x ~/ step) + (y ~/ step)) % 3 == 0) {
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignupBackdropPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final TextEditingController specializationController =
      TextEditingController();
  final TextEditingController experienceYearsController =
      TextEditingController();
  final TextEditingController licenseNumberController = TextEditingController();
  final TextEditingController serviceTypeController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController profileImageUrlController =
      TextEditingController();
  final TextEditingController dateOfBirthController = TextEditingController();
  final TextEditingController chronicDiseasesController =
      TextEditingController();
  final TextEditingController allergiesController = TextEditingController();
  final TextEditingController currentMedicationsController =
      TextEditingController();

  String selectedRole = 'patient';
  String? selectedGender;
  bool isRegistering = false;
  bool isGettingLocation = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  double? gpsLat;
  double? gpsLng;
  String? selectedPlaceName;
  Uint8List? profileImageBytes;
  String? profileImageName;
  bool showProfileImageUrlField = false;
  final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final AuthService _signupAuth = AuthService();
  final TextEditingController _emailOtpController = TextEditingController();
  final TextEditingController _phoneOtpController = TextEditingController();
  String? _emailVerificationToken;
  bool _emailOtpVerified = false;
  int _emailResendSeconds = 0;
  Timer? _emailResendTimer;
  bool _emailOtpBusy = false;

  String? _phoneVerificationToken;
  bool _phoneOtpVerified = false;
  int _phoneResendSeconds = 0;
  Timer? _phoneResendTimer;
  bool _phoneOtpBusy = false;

  static const double _kSheetTopRadius = 22;
  static const Color _accent = AppColors.primary;
  static const Color _accentGradientEnd = Color(0xFF3ABEB0);

  bool get _isDark => themeController.isDark;
  Color get _pageBg => _isDark ? const Color(0xFF021018) : AppColors.background;
  Color get _cardBg => _isDark ? const Color(0xFF0A252E) : Colors.white;
  Color get _cardBgSoft =>
      _isDark ? const Color(0xFF0D2E38) : const Color(0xFFF0F7F5);
  Color get _inputBg =>
      _isDark ? const Color(0xFF123640).withValues(alpha: 0.55) : Colors.white;
  Color get _inputBorderDark =>
      _isDark ? const Color(0xFF1E3A44) : AppColors.border;
  Color get _textPrimary =>
      _isDark ? const Color(0xFFF5FBFC) : AppColors.textDark;
  Color get _textSecondary =>
      _isDark ? const Color(0xFF8FA7AE) : const Color(0xFF5C6C73);

  @override
  void initState() {
    super.initState();
    selectedRole = 'patient';
    selectedGender = 'prefer_not_to_say';
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    specializationController.dispose();
    experienceYearsController.dispose();
    licenseNumberController.dispose();
    serviceTypeController.dispose();
    addressController.dispose();
    profileImageUrlController.dispose();
    dateOfBirthController.dispose();
    chronicDiseasesController.dispose();
    allergiesController.dispose();
    currentMedicationsController.dispose();
    _emailOtpController.dispose();
    _phoneOtpController.dispose();
    _emailResendTimer?.cancel();
    _phoneResendTimer?.cancel();
    super.dispose();
  }

  void _showMessage(String text, {Color? color}) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color ?? const Color(0xFF1E2E2E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showCarelinkDateOfBirthPicker(
      context,
      currentIsoDate: dateOfBirthController.text,
    );
    if (picked != null) {
      dateOfBirthController.text = picked.toIso8601String().split('T').first;
      setState(() {});
    }
  }

  Future<void> getLocation() async {
    FocusScope.of(context).unfocus();
    setState(() => isGettingLocation = true);

    try {
      final result = await showModalBottomSheet<_PickedLocation>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MapLocationPickerSheet(
          initialLat: gpsLat,
          initialLng: gpsLng,
          initialAddress: addressController.text.trim(),
          initialPlaceName: selectedPlaceName,
        ),
      );

      if (result == null) return;

      setState(() {
        gpsLat = result.latitude;
        gpsLng = result.longitude;
        selectedPlaceName = result.placeName;
      });
      addressController.text = result.address;
      _showMessage('Location selected from map', color: Colors.green);
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => isGettingLocation = false);
    }
  }

  bool _isStrongPassword(String input) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
    return regex.hasMatch(input);
  }

  bool _isLikelyUrl(String input) {
    final value = input.trim();
    if (value.isEmpty) return true;
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1080,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        profileImageBytes = bytes;
        profileImageName = file.name;
        if (profileImageUrlController.text.trim().isNotEmpty) {
          profileImageUrlController.clear();
        }
      });
      _showMessage('Profile image selected', color: Colors.green);
    } on MissingPluginException {
      _showMessage(
        'Image picker needs full app restart. Please stop and run again.',
        color: Colors.red,
      );
    } catch (_) {
      if (kIsWeb && source == ImageSource.camera) {
        _showMessage(
          'Camera not available on this browser/device. Try phone browser or Gallery.',
          color: Colors.red,
        );
      } else {
        _showMessage(
          'Could not pick image. Please try again.',
          color: Colors.red,
        );
      }
    }
  }

  void _startEmailOtpCooldown() {
    _emailResendTimer?.cancel();
    setState(() => _emailResendSeconds = 30);
    _emailResendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_emailResendSeconds <= 1) {
        t.cancel();
        setState(() => _emailResendSeconds = 0);
      } else {
        setState(() => _emailResendSeconds--);
      }
    });
  }

  void _startPhoneOtpCooldown() {
    _phoneResendTimer?.cancel();
    setState(() => _phoneResendSeconds = 30);
    _phoneResendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_phoneResendSeconds <= 1) {
        t.cancel();
        setState(() => _phoneResendSeconds = 0);
      } else {
        setState(() => _phoneResendSeconds--);
      }
    });
  }

  void _maybeLogDevCode(SendVerificationResult r) {
    AuthService.logDevCodeIfAny(r.devCode);
    if (kDebugMode && r.devCode != null && r.devCode!.isNotEmpty) {
      _showMessage('Dev code: ${r.devCode}', color: Colors.blueGrey.shade700);
    }
  }

  Future<void> _sendSignupEmailCode() async {
    FocusScope.of(context).unfocus();
    final email = emailController.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      _showMessage(context.tr('auth.enterValidEmail'), color: Colors.red);
      return;
    }
    setState(() => _emailOtpBusy = true);
    try {
      final r = await _signupAuth.sendEmailVerificationCode(
        email: email,
        purpose: VerificationPurpose.signup,
      );
      if (!mounted) return;
      _maybeLogDevCode(r);
      setState(() {
        _emailOtpVerified = false;
        _emailVerificationToken = null;
      });
      _startEmailOtpCooldown();
      _showMessage(
        r.userMessage,
        color: Colors.green.shade700,
      );
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, color: Colors.red);
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _emailOtpBusy = false);
    }
  }

  Future<void> _verifySignupEmailCode() async {
    FocusScope.of(context).unfocus();
    final email = emailController.text.trim();
    final code = _emailOtpController.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      _showMessage(context.tr('auth.enterValidEmail'), color: Colors.red);
      return;
    }
    setState(() => _emailOtpBusy = true);
    try {
      final res = await _signupAuth.verifyEmailCode(
        email: email,
        code: code,
        purpose: VerificationPurpose.signup,
      );
      if (!mounted) return;
      final t = res.emailVerificationToken;
      if (t == null || t.isEmpty) {
        _showMessage(context.tr('auth.invalidVerificationCode'), color: Colors.red);
        return;
      }
      setState(() {
        _emailVerificationToken = t;
        _emailOtpVerified = true;
      });
      _showMessage(
        context.tr('auth.emailVerifiedSuccess'),
        color: Colors.green.shade700,
      );
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      _showMessage(
        e.message.toLowerCase().contains('invalid') ||
                e.message.toLowerCase().contains('expired') ||
                e.message.toLowerCase().contains('too many')
            ? context.tr('auth.invalidVerificationCode')
            : e.message,
        color: Colors.red,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _emailOtpBusy = false);
    }
  }

  Future<void> _sendSignupPhoneCode() async {
    FocusScope.of(context).unfocus();
    final digits = AuthService.normalizePhoneDigits(phoneController.text);
    if (!AuthService.isValidPhoneLength(digits)) {
      _showMessage(context.tr('auth.invalidPhone'), color: Colors.red);
      return;
    }
    setState(() => _phoneOtpBusy = true);
    try {
      final r = await _signupAuth.sendPhoneVerificationCode(
        phoneDigits: digits,
        purpose: VerificationPurpose.signup,
      );
      if (!mounted) return;
      _maybeLogDevCode(r);
      setState(() {
        _phoneOtpVerified = false;
        _phoneVerificationToken = null;
      });
      _startPhoneOtpCooldown();
      _showMessage(
        r.userMessage,
        color: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _phoneOtpBusy = false);
    }
  }

  Future<void> _verifySignupPhoneCode() async {
    FocusScope.of(context).unfocus();
    final digits = AuthService.normalizePhoneDigits(phoneController.text);
    final code = _phoneOtpController.text.trim();
    if (!AuthService.isValidPhoneLength(digits)) {
      _showMessage(context.tr('auth.invalidPhone'), color: Colors.red);
      return;
    }
    setState(() => _phoneOtpBusy = true);
    try {
      final res = await _signupAuth.verifyPhoneCode(
        phoneDigits: digits,
        code: code,
        purpose: VerificationPurpose.signup,
      );
      if (!mounted) return;
      final t = res.phoneVerificationToken;
      if (t == null || t.isEmpty) {
        _showMessage(context.tr('auth.invalidVerificationCode'), color: Colors.red);
        return;
      }
      setState(() {
        _phoneVerificationToken = t;
        _phoneOtpVerified = true;
      });
      _showMessage(
        context.tr('auth.phoneVerifiedSuccess'),
        color: Colors.green.shade700,
      );
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      _showMessage(
        e.message.toLowerCase().contains('invalid') ||
                e.message.toLowerCase().contains('expired') ||
                e.message.toLowerCase().contains('too many')
            ? context.tr('auth.invalidVerificationCode')
            : e.message,
        color: Colors.red,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _phoneOtpBusy = false);
    }
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedRole == 'patient') {
      if (dateOfBirthController.text.trim().isEmpty) {
        _showMessage('Please select date of birth', color: Colors.red);
        return;
      }
      if (selectedGender == null || selectedGender!.trim().isEmpty) {
        _showMessage('Please select gender', color: Colors.red);
        return;
      }
    }

    if (!_emailOtpVerified ||
        _emailVerificationToken == null ||
        _emailVerificationToken!.isEmpty) {
      _showMessage(
        context.tr('auth.verifyEmailFirst'),
        color: Colors.red,
      );
      return;
    }

    if (!_phoneOtpVerified ||
        _phoneVerificationToken == null ||
        _phoneVerificationToken!.isEmpty) {
      _showMessage(
        context.tr('auth.verifyPhoneFirst'),
        color: Colors.red,
      );
      return;
    }

    if (selectedRole == 'doctor' || selectedRole == 'nurse') {
      final years = int.tryParse(experienceYearsController.text.trim());
      if (years == null) {
        _showMessage(
          'Experience years must be a valid number',
          color: Colors.red,
        );
        return;
      }
      if (selectedRole == 'doctor' &&
          licenseNumberController.text.trim().isEmpty) {
        _showMessage('Please enter doctor license number', color: Colors.red);
        return;
      }
    }

    setState(() => isRegistering = true);

    String? profileImagePayload;
    final imageBytes = profileImageBytes;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      profileImagePayload =
          'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    } else {
      final u = profileImageUrlController.text.trim();
      if (u.isNotEmpty) profileImagePayload = u;
    }

    try {
      final response = await ApiService().register(
        nameController.text.trim(),
        emailController.text.trim(),
        phoneController.text.trim(),
        passwordController.text,
        selectedRole,
        confirmPassword: confirmPasswordController.text,
        specialization: selectedRole == 'patient'
            ? null
            : specializationController.text.trim(),
        addressText: addressController.text.trim(),
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        dateOfBirth: selectedRole == 'patient'
            ? dateOfBirthController.text.trim()
            : null,
        gender: selectedRole == 'patient' ? selectedGender : null,
        chronicDiseases: selectedRole == 'patient'
            ? chronicDiseasesController.text.trim()
            : null,
        allergies: selectedRole == 'patient'
            ? allergiesController.text.trim()
            : null,
        currentMedications: selectedRole == 'patient'
            ? currentMedicationsController.text.trim()
            : null,
        profileImageUrl: profileImagePayload,
        experienceYears: selectedRole == 'patient'
            ? null
            : int.tryParse(experienceYearsController.text.trim()),
        licenseNumber: selectedRole == 'patient'
            ? null
            : licenseNumberController.text.trim(),
        serviceType: selectedRole == 'patient'
            ? null
            : serviceTypeController.text.trim(),
        phoneVerificationToken: _phoneVerificationToken,
        emailVerificationToken: _emailVerificationToken,
      );

      _showMessage(
        response['message']?.toString() ?? 'Account created successfully',
        color: Colors.green,
      );
      appNavigatorKey.currentState?.pop();
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => isRegistering = false);
    }
  }

  Widget _customField({
    String? label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    double bottomPadding = 14,
    int? maxLines,
    void Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 7),
          ],
          Container(
            decoration: BoxDecoration(
              color: _inputBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _inputBorderDark, width: 1),
            ),
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
              keyboardType: (maxLines ?? 1) > 1
                  ? TextInputType.multiline
                  : keyboardType,
              validator: validator,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: onChanged,
              inputFormatters: inputFormatters,
              maxLines: maxLines ?? 1,
              minLines: (maxLines ?? 1) > 1 ? 2 : null,
              style: GoogleFonts.inter(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: _accent,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(icon, color: _textSecondary, size: 22),
                suffixIcon: suffixIcon,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTabs() {
    const roles = [
      ('patient', 'Patient', Icons.favorite_rounded),
      ('nurse', 'Nurse', Icons.local_hospital_outlined),
      ('doctor', 'Doctor', Icons.medical_services_outlined),
    ];

    return Row(
      children: roles.map((entry) {
        final isSelected = selectedRole == entry.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => selectedRole = entry.$1),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _accent.withValues(alpha: 0.14)
                        : _inputBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? _accent : _inputBorderDark,
                      width: isSelected ? 1.2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        entry.$3,
                        size: 20,
                        color: isSelected ? _accent : _textSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: isSelected ? _accent : _textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _heroSubtitle() {
    switch (selectedRole) {
      case 'doctor':
        return 'Join CareLink to manage consultations, patient requests, and trusted clinical access.';
      case 'nurse':
        return 'Join CareLink to support patients, coordinate care, and stay connected securely.';
      default:
        return 'Join CareLink to manage appointments, records, and secure health updates in one place.';
    }
  }

  String _detailsSectionTitle() {
    return selectedRole == 'patient'
        ? 'Patient Details'
        : 'Professional Details';
  }

  String _submitButtonLabel() {
    switch (selectedRole) {
      case 'doctor':
        return 'Create Doctor Account';
      case 'nurse':
        return 'Create Nurse Account';
      default:
        return 'Create Patient Account';
    }
  }

  Widget _sectionHeading(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _accent, size: 18),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _inputBorderDark, width: 1),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: selectedGender,
        dropdownColor: _cardBgSoft,
        style: GoogleFonts.inter(
          color: _textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.person_outline_rounded,
            color: _textSecondary,
            size: 22,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 14,
          ),
        ),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: _textSecondary),
        items: [
          DropdownMenuItem(
            value: 'male',
            child: Text('Male', style: GoogleFonts.inter(color: _textPrimary)),
          ),
          DropdownMenuItem(
            value: 'female',
            child: Text(
              'Female',
              style: GoogleFonts.inter(color: _textPrimary),
            ),
          ),
          DropdownMenuItem(
            value: 'other',
            child: Text('Other', style: GoogleFonts.inter(color: _textPrimary)),
          ),
          DropdownMenuItem(
            value: 'prefer_not_to_say',
            child: Text(
              'Prefer not to say',
              style: GoogleFonts.inter(color: _textPrimary),
            ),
          ),
        ],
        onChanged: (v) => setState(() => selectedGender = v),
      ),
    );
  }

  Widget _buildMapSelectionHint() {
    final hasLocation = gpsLat != null && gpsLng != null;
    if (!hasLocation) return const SizedBox.shrink();
    final placeLabel = (selectedPlaceName ?? '').trim();
    final addressLabel = addressController.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Colors.green.shade600,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              placeLabel.isNotEmpty
                  ? placeLabel
                  : (addressLabel.isNotEmpty
                        ? addressLabel
                        : 'Map location saved'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFB7D8D4),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _customField(
              label: null,
              hint: 'Full Address',
              icon: Icons.location_on_outlined,
              controller: addressController,
              bottomPadding: 0,
              validator: (v) {
                if (selectedRole == 'patient' &&
                    (v == null || v.trim().isEmpty)) {
                  return 'Address is required for patient';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: SizedBox(
              height: 56,
              child: isGettingLocation
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent,
                        ),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: getLocation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accent,
                        side: BorderSide(color: _inputBorderDark, width: 1.2),
                        backgroundColor: _inputBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Open Map',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Same max-width strategy as [LoginScreen] for wide web windows.
  double _signupCardMaxWidth(double screenW) {
    if (screenW >= 1200) return 520;
    if (screenW >= 900) return 480;
    if (screenW >= 600) return 440;
    return 420;
  }

  /// Matches login: back control + avatar + title + subtitle inside the card.
  Widget _buildCompactSignupHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CarelinkBrandLogo(
            height: 36,
            fallbackTextColor: _textPrimary,
            forceDarkLogo: _isDark,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Sign Up',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _heroSubtitle(),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: _textSecondary,
            fontSize: 13.5,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: _textSecondary,
              ),
              title: Text(
                'Choose from gallery',
                style: GoogleFonts.inter(
                  color: _textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: _textSecondary),
              title: Text(
                'Take a photo',
                style: GoogleFonts.inter(
                  color: _textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfileImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImagePicker() {
    final hasImage = profileImageBytes != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: _cardBgSoft,
                backgroundImage: hasImage
                    ? MemoryImage(profileImageBytes!)
                    : null,
                child: hasImage
                    ? null
                    : Icon(
                        Icons.person_outline_rounded,
                        size: 32,
                        color: _textSecondary,
                      ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: _accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Photo (Optional)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasImage
                      ? (profileImageName ?? 'Photo selected')
                      : 'Upload your profile photo',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: _showImageSourceSheet,
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: BorderSide(color: _inputBorderDark, width: 1.2),
              backgroundColor: _inputBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt_outlined, size: 16),
                SizedBox(width: 4),
                Text('Upload', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalImageUrl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              setState(() {
                showProfileImageUrlField = !showProfileImageUrlField;
              });
            },
            child: Text(
              showProfileImageUrlField
                  ? 'Hide image URL'
                  : 'Use image URL instead',
              style: GoogleFonts.inter(
                color: _accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (showProfileImageUrlField)
          _customField(
            label: null,
            hint: 'https://example.com/image.jpg',
            icon: Icons.link_rounded,
            controller: profileImageUrlController,
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return null;
              if (!_isLikelyUrl(value)) return 'Please enter a valid URL';
              return null;
            },
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: isRegistering
                ? [
                    _accent.withValues(alpha: 0.55),
                    _accentGradientEnd.withValues(alpha: 0.55),
                  ]
                : const [_accent, _accentGradientEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isRegistering ? null : registerUser,
            borderRadius: BorderRadius.circular(999),
            child: Center(
              child: isRegistering
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _submitButtonLabel(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordRuleHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: _textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Password must contain uppercase, lowercase, number, and at least 8 characters.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final sw = MediaQuery.sizeOf(context).width;
    final cardMaxW = _signupCardMaxWidth(sw);
    const hPad = 24.0;

    return Scaffold(
      backgroundColor: p.isDark ? const Color(0xFF021018) : _pageBg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SignupBackdropPainter(isDark: p.isDark),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: IconButton(
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            appNavigatorKey.currentState?.pushReplacementNamed(
                              '/login',
                            );
                          }
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
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      hPad,
                      0,
                      hPad,
                      24 + viewInsets,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cardMaxW),
                        child: Form(
                          key: _formKey,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                            decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(
                                _kSheetTopRadius,
                              ),
                              border: Border.all(
                                color: _inputBorderDark.withValues(alpha: 0.55),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildCompactSignupHeader(),
                                const SizedBox(height: 24),
                                Text(
                                  'Choose Account Type',
                                  style: GoogleFonts.inter(
                                    color: _textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildRoleTabs(),
                                const SizedBox(height: 18),
                                _sectionHeading(
                                  Icons.person_outline_rounded,
                                  'Basic Information',
                                ),
                                _customField(
                                  label: null,
                                  hint: 'Full Name',
                                  icon: Icons.person_outline,
                                  controller: nameController,
                                  validator: (v) {
                                    final value = (v ?? '').trim();
                                    if (value.isEmpty) {
                                      return 'Please enter your full name';
                                    }
                                    if (value.length < 2) {
                                      return 'Name is too short';
                                    }
                                    if (RegExp(r'^\d+$').hasMatch(value)) {
                                      return 'Name cannot be numbers only';
                                    }
                                    return null;
                                  },
                                ),
                                _customField(
                                  label: null,
                                  hint: 'Email Address',
                                  icon: Icons.email_outlined,
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  onChanged: (_) {
                                    if (_emailOtpVerified) {
                                      setState(() {
                                        _emailOtpVerified = false;
                                        _emailVerificationToken = null;
                                      });
                                    }
                                  },
                                  validator: (v) {
                                    final value = (v ?? '').trim();
                                    if (value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!_emailRegex.hasMatch(value)) {
                                      return 'Invalid email format';
                                    }
                                    return null;
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Email verification',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        context.tr('auth.enterCodeHint'),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: _textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: OutlinedButton(
                                          onPressed: (_emailOtpBusy ||
                                                  _emailResendSeconds > 0 ||
                                                  isRegistering)
                                              ? null
                                              : _sendSignupEmailCode,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _accent,
                                            side: BorderSide(
                                              color: _inputBorderDark,
                                              width: 1.2,
                                            ),
                                            backgroundColor: _inputBg,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _emailOtpBusy
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: _accent,
                                                  ),
                                                )
                                              : Text(
                                                  _emailResendSeconds > 0
                                                      ? context.tr(
                                                          'auth.resendIn',
                                                          args: {
                                                            'seconds':
                                                                _emailResendSeconds
                                                                    .toString(),
                                                          },
                                                        )
                                                      : context
                                                          .tr('auth.sendCode'),
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _customField(
                                        label: null,
                                        hint: context.tr('auth.otpCode'),
                                        icon: Icons.pin_outlined,
                                        controller: _emailOtpController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        bottomPadding: 10,
                                        validator: (_) => null,
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: OutlinedButton(
                                          onPressed: (_emailOtpBusy ||
                                                  isRegistering)
                                              ? null
                                              : _verifySignupEmailCode,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _accent,
                                            side: BorderSide(
                                              color: _inputBorderDark,
                                              width: 1.2,
                                            ),
                                            backgroundColor: _inputBg,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _emailOtpBusy
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: _accent,
                                                  ),
                                                )
                                              : Text(
                                                  context.tr(
                                                    'auth.verifyAndContinue',
                                                  ),
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      if (_emailOtpVerified) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.green.shade600,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              context.tr(
                                                'auth.emailVerifiedSuccess',
                                              ),
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                _customField(
                                  label: null,
                                  hint: 'Phone number (digits only)',
                                  icon: Icons.phone_outlined,
                                  controller: phoneController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (_) {
                                    if (_phoneOtpVerified) {
                                      setState(() {
                                        _phoneOtpVerified = false;
                                        _phoneVerificationToken = null;
                                      });
                                    }
                                  },
                                  validator: (v) {
                                    final digits =
                                        AuthService.normalizePhoneDigits(
                                      (v ?? '').toString(),
                                    );
                                    if (digits.isEmpty) {
                                      return 'Please enter your phone number';
                                    }
                                    if (!AuthService.isValidPhoneLength(digits)) {
                                      return 'Phone must be 8-15 digits';
                                    }
                                    return null;
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Phone verification',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        context.tr('auth.enterCodeHint'),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: _textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: OutlinedButton(
                                          onPressed: (_phoneOtpBusy ||
                                                  _phoneResendSeconds > 0 ||
                                                  isRegistering)
                                              ? null
                                              : _sendSignupPhoneCode,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _accent,
                                            side: BorderSide(
                                              color: _inputBorderDark,
                                              width: 1.2,
                                            ),
                                            backgroundColor: _inputBg,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _phoneOtpBusy
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: _accent,
                                                  ),
                                                )
                                              : Text(
                                                  _phoneResendSeconds > 0
                                                      ? context.tr(
                                                          'auth.resendIn',
                                                          args: {
                                                            'seconds':
                                                                _phoneResendSeconds
                                                                    .toString(),
                                                          },
                                                        )
                                                      : context
                                                          .tr('auth.sendCode'),
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _customField(
                                        label: null,
                                        hint: context.tr('auth.otpCode'),
                                        icon: Icons.pin_outlined,
                                        controller: _phoneOtpController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        bottomPadding: 10,
                                        validator: (_) => null,
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: OutlinedButton(
                                          onPressed: (_phoneOtpBusy ||
                                                  isRegistering)
                                              ? null
                                              : _verifySignupPhoneCode,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _accent,
                                            side: BorderSide(
                                              color: _inputBorderDark,
                                              width: 1.2,
                                            ),
                                            backgroundColor: _inputBg,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _phoneOtpBusy
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: _accent,
                                                  ),
                                                )
                                              : Text(
                                                  context.tr(
                                                    'auth.verifyAndContinue',
                                                  ),
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      if (_phoneOtpVerified) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.green.shade600,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              context.tr(
                                                'auth.phoneVerifiedSuccess',
                                              ),
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                _sectionHeading(
                                  Icons.lock_outline_rounded,
                                  'Security',
                                ),
                                _customField(
                                  label: null,
                                  hint: 'Password',
                                  icon: Icons.lock_outline,
                                  controller: passwordController,
                                  obscure: obscurePassword,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(
                                        () =>
                                            obscurePassword = !obscurePassword,
                                      );
                                    },
                                    icon: Icon(
                                      obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: _textSecondary,
                                    ),
                                  ),
                                  validator: (v) {
                                    final value = v ?? '';
                                    if (value.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    if (!_isStrongPassword(value)) {
                                      return 'Use 8+ chars with upper/lower/number';
                                    }
                                    return null;
                                  },
                                ),
                                _customField(
                                  label: null,
                                  hint: 'Confirm Password',
                                  icon: Icons.verified_user_outlined,
                                  controller: confirmPasswordController,
                                  obscure: obscureConfirmPassword,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(
                                        () => obscureConfirmPassword =
                                            !obscureConfirmPassword,
                                      );
                                    },
                                    icon: Icon(
                                      obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: _textSecondary,
                                    ),
                                  ),
                                  validator: (v) {
                                    if ((v ?? '').isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (v != passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                _passwordRuleHint(),
                                const SizedBox(height: 4),
                                _sectionHeading(
                                  Icons.assignment_ind_outlined,
                                  _detailsSectionTitle(),
                                ),
                                _buildProfileImagePicker(),
                                _buildOptionalImageUrl(),
                                _buildAddressRow(),
                                _buildMapSelectionHint(),
                                if (selectedRole == 'patient') ...[
                                  _customField(
                                    label: null,
                                    hint: 'Date of Birth',
                                    icon: Icons.calendar_today_outlined,
                                    controller: dateOfBirthController,
                                    readOnly: true,
                                    onTap: _pickDateOfBirth,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Date of birth is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  _buildGenderDropdown(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Health baseline (optional)',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Helps providers give safer care. You can update this anytime in your profile.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: _textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _customField(
                                    label: null,
                                    hint: 'Chronic conditions (if any)',
                                    icon: Icons.healing_outlined,
                                    controller: chronicDiseasesController,
                                    maxLines: 4,
                                    keyboardType: TextInputType.multiline,
                                  ),
                                  _customField(
                                    label: null,
                                    hint: 'Allergies (if any)',
                                    icon: Icons.warning_amber_outlined,
                                    controller: allergiesController,
                                    maxLines: 3,
                                    keyboardType: TextInputType.multiline,
                                  ),
                                  _customField(
                                    label: null,
                                    hint: 'Current medications (if any)',
                                    icon: Icons.medication_outlined,
                                    controller: currentMedicationsController,
                                    maxLines: 4,
                                    keyboardType: TextInputType.multiline,
                                  ),
                                ] else ...[
                                  _customField(
                                    label: null,
                                    hint: 'Specialization',
                                    icon: Icons.medical_services_outlined,
                                    controller: specializationController,
                                    validator: (v) {
                                      if ((v ?? '').trim().isEmpty) {
                                        return 'Please enter specialization';
                                      }
                                      return null;
                                    },
                                  ),
                                  _customField(
                                    label: null,
                                    hint: 'Service Type (Optional)',
                                    icon: Icons.local_hospital_outlined,
                                    controller: serviceTypeController,
                                  ),
                                  _customField(
                                    label: null,
                                    hint: 'Experience Years',
                                    icon: Icons.workspace_premium_outlined,
                                    controller: experienceYearsController,
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      final value = (v ?? '').trim();
                                      final years = int.tryParse(value);
                                      if (value.isEmpty) {
                                        return 'Please enter experience years';
                                      }
                                      if (years == null ||
                                          years < 0 ||
                                          years > 80) {
                                        return 'Invalid years';
                                      }
                                      return null;
                                    },
                                  ),
                                  _customField(
                                    label: null,
                                    hint: selectedRole == 'doctor'
                                        ? 'License Number'
                                        : 'License Number (Optional)',
                                    icon: Icons.badge_outlined,
                                    controller: licenseNumberController,
                                    validator: (v) {
                                      if (selectedRole == 'doctor' &&
                                          (v == null || v.trim().isEmpty)) {
                                        return 'License number is required for doctor';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                const SizedBox(height: 10),
                                _buildSubmitButton(),
                                const SizedBox(height: 18),
                                Center(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account? ',
                                        style: GoogleFonts.inter(
                                          color: _textSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () =>
                                            appNavigatorKey.currentState?.pop(),
                                        child: Text(
                                          'Sign In',
                                          style: GoogleFonts.inter(
                                            color: _accent,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedLocation {
  const _PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.placeName,
  });

  final double latitude;
  final double longitude;
  final String address;
  final String placeName;
}

class _PlaceSearchResult {
  const _PlaceSearchResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  factory _PlaceSearchResult.fromNominatim(Map<String, dynamic> json) {
    final lat = double.tryParse((json['lat'] ?? '').toString()) ?? 0;
    final lng = double.tryParse((json['lon'] ?? '').toString()) ?? 0;
    final displayName = (json['display_name'] ?? '').toString();
    final name = (json['name'] ?? '').toString().trim();
    final address = json['address'];
    String title = name.isNotEmpty ? name : displayName;
    String subtitle = displayName;

    if (address is Map<String, dynamic>) {
      final city =
          (address['city'] ??
                  address['town'] ??
                  address['village'] ??
                  address['state'] ??
                  '')
              .toString();
      final country = (address['country'] ?? '').toString();
      final compact = [
        city,
        country,
      ].where((e) => e.trim().isNotEmpty).join(', ');
      if (compact.isNotEmpty) {
        subtitle = compact;
      }
    }

    if (title.trim().isEmpty) {
      title = subtitle;
    }

    return _PlaceSearchResult(
      title: title,
      subtitle: subtitle,
      latitude: lat,
      longitude: lng,
    );
  }

  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
}

class _MapLocationPickerSheet extends StatefulWidget {
  const _MapLocationPickerSheet({
    required this.initialLat,
    required this.initialLng,
    required this.initialAddress,
    required this.initialPlaceName,
  });

  final double? initialLat;
  final double? initialLng;
  final String initialAddress;
  final String? initialPlaceName;

  @override
  State<_MapLocationPickerSheet> createState() =>
      _MapLocationPickerSheetState();
}

class _MapLocationPickerSheetState extends State<_MapLocationPickerSheet> {
  static const LatLng _defaultCenter = LatLng(31.9539, 35.9106);
  static const Color _sheetCard = Color(0xFF0E3D3A);
  static const Color _sheetInput = Color(0xFF123F3C);
  static const Color _sheetBorder = Color(0xFF3A6863);
  static const Color _sheetAccent = AppColors.primary;
  static const Color _sheetMuted = Color(0xFFC5D9D4);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  late LatLng _pickedPoint;
  late String _address;
  late String _placeName;
  final List<String> _recentSearches = [];
  final List<_PlaceSearchResult> _searchResults = [];
  Timer? _searchDebounce;
  bool _resolvingAddress = false;
  bool _locatingCurrent = false;
  bool _searchingPlace = false;

  @override
  void initState() {
    super.initState();
    _pickedPoint = (widget.initialLat != null && widget.initialLng != null)
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : _defaultCenter;
    _address = widget.initialAddress;
    _placeName = widget.initialPlaceName?.trim() ?? '';
    _searchController.text = _placeName.isNotEmpty ? _placeName : _address;

    if (_address.isEmpty) {
      _resolveAddressForPoint(_pickedPoint);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _runPlacesSearch(value);
    });
  }

  Future<List<_PlaceSearchResult>> _fetchPlacesFromNominatim(
    String query,
  ) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '6',
      'accept-language': 'ar,en',
    });

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'carelink.app',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Search service unavailable');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_PlaceSearchResult.fromNominatim)
        .where((e) => e.latitude != 0 || e.longitude != 0)
        .toList();
  }

  Future<void> _runPlacesSearch(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _searchingPlace = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() => _searchingPlace = true);
    try {
      final nominatimResults = await _fetchPlacesFromNominatim(query);
      if (!mounted) return;
      setState(() {
        _searchResults
          ..clear()
          ..addAll(nominatimResults);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchResults.clear());
    } finally {
      if (mounted) {
        setState(() => _searchingPlace = false);
      }
    }
  }

  Future<void> _applySearchResult(_PlaceSearchResult result) async {
    FocusScope.of(context).unfocus();
    final point = LatLng(result.latitude, result.longitude);
    setState(() {
      _pickedPoint = point;
      _searchController.text = result.title;
      _recentSearches.removeWhere(
        (entry) => entry.toLowerCase() == result.title.toLowerCase(),
      );
      _recentSearches.insert(0, result.title);
      if (_recentSearches.length > 6) {
        _recentSearches.removeRange(6, _recentSearches.length);
      }
      _searchResults.clear();
    });
    _mapController.move(point, 16.5);
    await _resolveAddressForPoint(point);
  }

  Future<void> _searchPlaceByName([String? customQuery]) async {
    final query = (customQuery ?? _searchController.text).trim();
    if (query.isEmpty) return;

    if (_searchResults.isEmpty) {
      await _runPlacesSearch(query);
    }

    if (_searchResults.isNotEmpty) {
      await _applySearchResult(_searchResults.first);
      return;
    }

    // Fallback to platform geocoding if remote search returns nothing.
    try {
      final fallback = await locationFromAddress(query);
      if (fallback.isNotEmpty) {
        final first = fallback.first;
        await _applySearchResult(
          _PlaceSearchResult(
            title: query,
            subtitle: 'Location from device geocoder',
            latitude: first.latitude,
            longitude: first.longitude,
          ),
        );
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Could not find this place name'),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    final query = _searchController.text.trim();
    if (query.length < 2 && _recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_searchingPlace && _searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: LinearProgressIndicator(
          minHeight: 2,
          color: _sheetAccent,
          backgroundColor: _sheetBorder,
        ),
      );
    }

    final showRecentOnly = query.length < 2 || _searchResults.isEmpty;
    if (showRecentOnly && _recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: _sheetInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _sheetBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: showRecentOnly
              ? _recentSearches
                    .map(
                      (entry) => ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.history,
                          size: 18,
                          color: _sheetMuted,
                        ),
                        title: Text(
                          entry,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () {
                          _searchController.text = entry;
                          _searchPlaceByName(entry);
                        },
                      ),
                    )
                    .toList()
              : _searchResults
                    .map(
                      (result) => ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: _sheetMuted,
                        ),
                        title: Text(
                          result.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          result.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _sheetMuted,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => _applySearchResult(result),
                      ),
                    )
                    .toList(),
        ),
      ),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _locatingCurrent = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('Location services are disabled');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is not granted');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final point = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _pickedPoint = point);
      _mapController.move(point, 16);
      await _resolveAddressForPoint(point);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not get current location'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _locatingCurrent = false);
      }
    }
  }

  Future<void> _resolveAddressForPoint(LatLng point) async {
    setState(() => _resolvingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      final first = placemarks.isNotEmpty ? placemarks.first : null;

      final place = [
        first?.name,
        first?.subLocality,
        first?.locality,
      ].whereType<String>().where((e) => e.trim().isNotEmpty).join(', ');

      final fullAddress = [
        first?.street,
        first?.subLocality,
        first?.locality,
        first?.administrativeArea,
        first?.country,
      ].whereType<String>().where((e) => e.trim().isNotEmpty).join(', ');

      if (!mounted) return;
      setState(() {
        _placeName = place;
        _address = fullAddress;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _placeName = '';
        _address = '';
      });
    } finally {
      if (mounted) setState(() => _resolvingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latText = _pickedPoint.latitude.toStringAsFixed(6);
    final lngText = _pickedPoint.longitude.toStringAsFixed(6);
    final title = _placeName.isNotEmpty ? _placeName : 'Selected location';
    final address = _address.isNotEmpty
        ? _address
        : 'Address could not be resolved';

    return Container(
      decoration: const BoxDecoration(
        color: _sheetCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: _sheetBorder,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose Location from Map',
                      style: GoogleFonts.inter(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: _sheetAccent),
                    onPressed: _locatingCurrent ? null : _moveToCurrentLocation,
                    icon: _locatingCurrent
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _sheetAccent,
                            ),
                          )
                        : const Icon(Icons.my_location_outlined, size: 18),
                    label: Text(
                      'My Location',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: _sheetAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _searchPlaceByName(),
                textInputAction: TextInputAction.search,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                cursorColor: _sheetAccent,
                decoration: InputDecoration(
                  hintText: 'Search city, street, or area',
                  hintStyle: GoogleFonts.inter(color: _sheetMuted),
                  prefixIcon: const Icon(Icons.search, color: _sheetMuted),
                  suffixIcon: _searchingPlace
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _sheetAccent,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded),
                          color: _sheetAccent,
                          onPressed: _searchPlaceByName,
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: _sheetInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _sheetBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _sheetBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: _sheetAccent,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            _buildSearchSuggestions(),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _pickedPoint,
                  initialZoom: 15,
                  onTap: (_, point) {
                    setState(() => _pickedPoint = point);
                    _resolveAddressForPoint(point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'carelink.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pickedPoint,
                        width: 52,
                        height: 52,
                        child: const Icon(
                          Icons.location_pin,
                          size: 42,
                          color: _sheetAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: const BoxDecoration(
                color: _sheetInput,
                border: Border(top: BorderSide(color: _sheetBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_resolvingAddress)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: _sheetAccent,
                        backgroundColor: _sheetBorder,
                      ),
                    ),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: _sheetMuted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Lat: $latText  |  Lng: $lngText',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _sheetMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [_sheetAccent, Color(0xFF2DD4E8)],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            final locationAddress = _address.isNotEmpty
                                ? _address
                                : '$latText, $lngText';
                            Navigator.pop(
                              context,
                              _PickedLocation(
                                latitude: _pickedPoint.latitude,
                                longitude: _pickedPoint.longitude,
                                address: locationAddress,
                                placeName: _placeName,
                              ),
                            );
                          },
                          child: Center(
                            child: Text(
                              'Use This Location',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

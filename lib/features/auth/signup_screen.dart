import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_nav.dart';
import 'package:carelink/core/carelink_date_picker.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/core/post_auth_navigation.dart';
import 'package:carelink/core/phone_number_utils.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/auth_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/features/auth/registration/getx/signup_location_picker_screen.dart';

class Country {
  final String name;
  final String nameAr;
  final String code;
  final String dialCode;
  final String flag;
  final int phoneNumberLength;

  const Country({
    required this.name,
    required this.nameAr,
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.phoneNumberLength,
  });
}

const List<Country> _countries = [
  Country(
    name: 'Palestine',
    nameAr: 'فلسطين',
    code: 'PS',
    dialCode: '+972',
    flag: '🇵🇸',
    phoneNumberLength: 10,
  ),
  Country(
    name: 'Jordan',
    nameAr: 'الأردن',
    code: 'JO',
    dialCode: '+962',
    flag: '🇯🇴',
    phoneNumberLength: 9,
  ),
  Country(
    name: 'Egypt',
    nameAr: 'مصر',
    code: 'EG',
    dialCode: '+20',
    flag: '🇪🇬',
    phoneNumberLength: 10,
  ),
  Country(
    name: 'Saudi Arabia',
    nameAr: 'المملكة العربية السعودية',
    code: 'SA',
    dialCode: '+966',
    flag: '🇸🇦',
    phoneNumberLength: 9,
  ),
  Country(
    name: 'United Arab Emirates',
    nameAr: 'الإمارات العربية المتحدة',
    code: 'AE',
    dialCode: '+971',
    flag: '🇦🇪',
    phoneNumberLength: 9,
  ),
  Country(
    name: 'Qatar',
    nameAr: 'قطر',
    code: 'QA',
    dialCode: '+974',
    flag: '🇶🇦',
    phoneNumberLength: 8,
  ),
  Country(
    name: 'Kuwait',
    nameAr: 'الكويت',
    code: 'KW',
    dialCode: '+965',
    flag: '🇰🇼',
    phoneNumberLength: 8,
  ),
  Country(
    name: 'Bahrain',
    nameAr: 'البحرين',
    code: 'BH',
    dialCode: '+973',
    flag: '🇧🇭',
    phoneNumberLength: 8,
  ),
  Country(
    name: 'Oman',
    nameAr: 'عمان',
    code: 'OM',
    dialCode: '+968',
    flag: '🇴🇲',
    phoneNumberLength: 8,
  ),
];

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
    final p1 = Path()
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
    final p2 = Path()
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
  int _stepIndex = 0; // 0: Choose Account Type, 1: Form, 2: OTP Verification
  bool _isLoading = false;
  String _selectedRole = 'patient';

  // Form keys and Controllers
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Role specific controllers
  final TextEditingController dateOfBirthController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController chronicDiseasesController =
      TextEditingController();
  final TextEditingController allergiesController = TextEditingController();
  final TextEditingController currentMedicationsController =
      TextEditingController();
  final TextEditingController emergencyContactController =
      TextEditingController();

  // Doctor/Nurse specific controllers
  final TextEditingController specialtyController = TextEditingController();
  final TextEditingController customSpecialtyController =
      TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  final TextEditingController experienceController = TextEditingController();
  final TextEditingController clinicNameController = TextEditingController();
  final TextEditingController serviceAreasController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController cvFileController = TextEditingController();
  final TextEditingController medicalCertificateController =
      TextEditingController();
  final TextEditingController nursingLicenseFileController =
      TextEditingController();
  final TextEditingController idCardController = TextEditingController();
  final TextEditingController workplaceHistoryController =
      TextEditingController();
  String? _cvFileName;
  String? _medicalCertificateFileName;
  String? _nursingLicenseFileName;
  String? _idCardFileName;

  String _selectedGender = 'male';
  String _consultationType = 'both'; // home, online, both
  bool _homeCareAvailability = true;
  String? _selectedDoctorSpecialty;
  PlatformFile? _doctorCvFile;
  final List<PlatformFile?> _doctorRequiredCertificates =
      List<PlatformFile?>.filled(3, null);
  final List<PlatformFile?> _doctorAdditionalCertificates = <PlatformFile?>[];

  static const List<String> _doctorSpecialties = [
    'Cardiology',
    'General Medicine',
    'Orthopedics',
    'Neurology',
    'Dermatology',
    'ENT Specialist',
    'Other',
  ];

  double? _gpsLat;
  double? _gpsLng;

  // Country Picker State
  late Country _selectedCountry;

  // Verification state
  final AuthService _authService = AuthService();
  final TextEditingController _otpController = TextEditingController();
  String? _emailVerificationToken;
  String? _phoneVerificationToken;
  String? _lastVerificationRequestEmail;
  String? _verifiedEmail;

  Timer? _countdownTimer;
  Timer? _resendCooldownTimer;
  int _secondsRemaining = 0;
  int _resendSecondsRemaining = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get _isDark => themeController.isDark;
  bool get _showLegacyDoctorSpecialtyField => false;

  @override
  void initState() {
    super.initState();
    // Default country based on region
    try {
      final countryCode = PlatformDispatcher.instance.locale.countryCode
          ?.toUpperCase();
      if (countryCode == 'JO') {
        _selectedCountry = _countries.firstWhere((c) => c.code == 'JO');
      } else if (countryCode == 'EG') {
        _selectedCountry = _countries.firstWhere((c) => c.code == 'EG');
      } else {
        _selectedCountry = _countries.firstWhere((c) => c.code == 'PS');
      }
    } catch (_) {
      _selectedCountry = _countries.first;
    }

    passwordController.addListener(_onPasswordChanged);
    emailController.addListener(_onEmailChanged);
  }

  void _onPasswordChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _normalizeEmail(String value) => value.trim().toLowerCase();

  void _onEmailChanged() {
    final lastRequestedEmail = _lastVerificationRequestEmail;
    if (lastRequestedEmail == null ||
        _normalizeEmail(emailController.text) == lastRequestedEmail) {
      return;
    }

    final hasVerificationState =
        _resendSecondsRemaining > 0 ||
        _secondsRemaining > 0 ||
        _otpController.text.isNotEmpty ||
        _emailVerificationToken != null ||
        _phoneVerificationToken != null ||
        _verifiedEmail != null;
    if (!hasVerificationState) return;

    _resendCooldownTimer?.cancel();
    _countdownTimer?.cancel();
    _otpController.clear();
    _emailVerificationToken = null;
    _phoneVerificationToken = null;
    _verifiedEmail = null;

    if (mounted) {
      setState(() {
        _resendSecondsRemaining = 0;
        _secondsRemaining = 0;
      });
    }
  }

  String get _fullPhoneNumber {
    return PhoneNumberUtils.normalizeForCountry(
          input: phoneController.text,
          countryCode: _selectedCountry.code,
          dialCode: _selectedCountry.dialCode,
        ) ??
        '';
  }

  void _normalizePhoneFieldInput(String value) {
    if (_selectedCountry.code != 'PS') return;

    final digits = PhoneNumberUtils.digitsOnly(value);
    String? local;
    if (digits.startsWith('9720') && digits.length > 4) {
      local = '0${digits.substring(4)}';
    } else if (digits.startsWith('972') && digits.length > 3) {
      local = '0${digits.substring(3)}';
    }
    if (local == null || local == phoneController.text) return;

    phoneController.value = TextEditingValue(
      text: local,
      selection: TextSelection.collapsed(offset: local.length),
    );
  }

  void _selectCountry(Country country) {
    final maxLength = country.phoneNumberLength;
    final currentNumber = phoneController.text;
    if (currentNumber.length > maxLength) {
      phoneController.value = TextEditingValue(
        text: currentNumber.substring(0, maxLength),
        selection: TextSelection.collapsed(offset: maxLength),
      );
    }
    setState(() => _selectedCountry = country);
  }

  void _showCountryPicker() {
    final p = CarelinkPalette.of(context);
    final isAr = CarelinkL10n.of(context).isArabic;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            final filteredCountries = _countries.where((c) {
              final query = searchQuery.toLowerCase();
              return c.name.toLowerCase().contains(query) ||
                  c.nameAr.contains(query) ||
                  c.dialCode.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: p.stroke)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: p.stroke,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAr ? 'اختر الدولة' : 'Select Country',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: p.inkDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: p.isDark
                              ? const Color(0xFF123640).withValues(alpha: 0.55)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.stroke),
                        ),
                        child: TextField(
                          style: GoogleFonts.inter(
                            color: p.inkDark,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: isAr
                                ? 'البحث عن دولة...'
                                : 'Search country...',
                            hintStyle: GoogleFonts.inter(
                              color: p.inkMuted,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: p.inkMuted,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          onChanged: (val) {
                            setStateBottomSheet(() {
                              searchQuery = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredCountries.isEmpty
                          ? Center(
                              child: Text(
                                isAr ? 'لا توجد نتائج' : 'No countries found',
                                style: GoogleFonts.inter(color: p.inkMuted),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredCountries.length,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              itemBuilder: (context, index) {
                                final country = filteredCountries[index];
                                final isSelected =
                                    country.code == _selectedCountry.code;
                                return ListTile(
                                  onTap: () {
                                    _selectCountry(country);
                                    Navigator.pop(context);
                                  },
                                  leading: Text(
                                    country.flag,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  title: Text(
                                    isAr ? country.nameAr : country.name,
                                    style: GoogleFonts.inter(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: p.inkDark,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        country.dialCode,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? AppColors.primary
                                              : p.inkMuted,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGenderCard({
    required String label,
    required String value,
    required IconData icon,
    required bool isSelected,
    required CarelinkPalette p,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGender = value;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: p.isDark ? 0.15 : 0.08)
                : (p.isDark
                      ? const Color(0xFF123640).withValues(alpha: 0.55)
                      : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : p.stroke,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : p.inkMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : p.inkDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String text, bool isMet, CarelinkPalette p) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isMet ? Colors.green.shade600 : p.inkMuted,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: isMet ? Colors.green.shade700 : p.inkMuted,
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    passwordController.removeListener(_onPasswordChanged);
    emailController.removeListener(_onEmailChanged);
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    dateOfBirthController.dispose();
    addressController.dispose();
    chronicDiseasesController.dispose();
    allergiesController.dispose();
    currentMedicationsController.dispose();
    emergencyContactController.dispose();
    specialtyController.dispose();
    customSpecialtyController.dispose();
    licenseController.dispose();
    experienceController.dispose();
    clinicNameController.dispose();
    serviceAreasController.dispose();
    bioController.dispose();
    cvFileController.dispose();
    medicalCertificateController.dispose();
    nursingLicenseFileController.dispose();
    idCardController.dispose();
    workplaceHistoryController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  void _showMessage(String text, {Color? color}) {
    final cleanText = text.replaceFirst('Exception: ', '');
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final width = MediaQuery.sizeOf(context).width;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              color == Colors.green.shade700
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Flexible(child: Text(cleanText)),
          ],
        ),
        backgroundColor: color ?? const Color(0xFF1E2E2E),
        behavior: SnackBarBehavior.floating,
        width: width > 492 ? 460 : width - 32,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showCooldownMessage(int seconds) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final width = MediaQuery.sizeOf(context).width;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF8A5A00),
              size: 20,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                context.tr('auth.cooldownWait', args: {'seconds': '$seconds'}),
                style: GoogleFonts.inter(
                  color: const Color(0xFF5D4300),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFF4CE),
        behavior: SnackBarBehavior.floating,
        width: width > 452 ? 420 : width - 32,
        duration: const Duration(seconds: 4),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFFD66B)),
        ),
      ),
    );
  }

  int? _cooldownSecondsFrom(Object error) {
    if (error is AuthServiceException && error.retryAfterSeconds != null) {
      return error.retryAfterSeconds;
    }

    final message = error.toString().replaceFirst('Exception: ', '');
    final match = RegExp(
      r'(?:wait|retry(?:\s+after)?)\D*(\d+)\s*(?:seconds?|secs?|s)\b',
      caseSensitive: false,
    ).firstMatch(message);
    return int.tryParse(match?.group(1) ?? '');
  }

  void _startResendCooldown(int seconds) {
    _resendCooldownTimer?.cancel();
    if (!mounted) return;

    setState(() => _resendSecondsRemaining = seconds);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _resendSecondsRemaining = 0);
      } else {
        setState(() => _resendSecondsRemaining--);
      }
    });
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = 300); // 5 minutes code expiry
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get _hasRequiredNurseDocuments =>
      medicalCertificateController.text.trim().isNotEmpty &&
      nursingLicenseFileController.text.trim().isNotEmpty &&
      idCardController.text.trim().isNotEmpty;

  void _showMissingNurseDocumentsMessage() {
    _showMessage(
      'Please upload Medical Certificate, Nursing License, and ID Card.',
      color: Colors.red.shade700,
    );
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showCarelinkDateOfBirthPicker(
      context,
      currentIsoDate: dateOfBirthController.text,
    );
    if (picked != null) {
      setState(() {
        dateOfBirthController.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<SignupLocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SignupLocationPickerScreen(
          initialAddress: addressController.text.trim(),
          initialLatitude: _gpsLat,
          initialLongitude: _gpsLng,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        addressController.text = result.address;
        _gpsLat = result.latitude;
        _gpsLng = result.longitude;
      });
      if (!mounted) return;
      _showMessage(
        context.tr('auth.locationVerifiedSuccess'),
        color: Colors.green.shade700,
      );
    }
  }

  Future<void> _pickProviderDocument({
    required TextEditingController controller,
    required ValueChanged<String?> setFileName,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showMessage(
        'Could not read this file. Please choose another PDF or image.',
        color: Colors.red.shade700,
      );
      return;
    }
    if (bytes.length > 6 * 1024 * 1024) {
      _showMessage(
        'File is too large. Please choose a file under 6 MB.',
        color: Colors.red.shade700,
      );
      return;
    }

    final ext = (file.extension ?? '').toLowerCase();
    final mime = switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
    controller.text = 'data:$mime;base64,${base64Encode(bytes)}';
    setState(() => setFileName(file.name));
  }

  Future<PlatformFile?> _pickDoctorDocument({required bool pdfOnly}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: pdfOnly
          ? const ['pdf']
          : const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return null;

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showMessage(
        'Could not read this file. Please choose another file.',
        color: Colors.red.shade700,
      );
      return null;
    }
    if (bytes.length > 10 * 1024 * 1024) {
      _showMessage(
        'File is too large. Maximum size is 10 MB.',
        color: Colors.red.shade700,
      );
      return null;
    }
    return file;
  }

  bool get _hasRequiredDoctorDocuments =>
      _doctorCvFile != null &&
      _doctorRequiredCertificates.every((file) => file != null);

  void _showMissingDoctorDocumentsMessage() {
    _showMessage(
      'Upload your CV and all three required certificates.',
      color: Colors.red.shade700,
    );
  }

  String _doctorDocumentMimeType(PlatformFile file) {
    return switch ((file.extension ?? '').toLowerCase()) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
  }

  Map<String, dynamic> _doctorCertificatePayload(
    PlatformFile file,
    String name,
  ) {
    return <String, dynamic>{
      'name': name,
      'fileName': file.name,
      'fileData': base64Encode(file.bytes!),
      'mimeType': _doctorDocumentMimeType(file),
      'fileSize': file.size,
    };
  }

  bool _isStrongPassword(String input) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
    return regex.hasMatch(input);
  }

  Future<void> _sendVerificationCode() async {
    FocusScope.of(context).unfocus();
    if (_stepIndex != 2 && !(_step2FormKey.currentState?.validate() ?? false)) {
      _showMessage(context.tr('auth.checkForm'), color: Colors.red.shade700);
      return;
    }

    if (_selectedRole == 'doctor' &&
        _showLegacyDoctorSpecialtyField &&
        addressController.text.trim().isEmpty) {
      _showMessage(
        CarelinkL10n.of(context).isArabic
            ? 'موقع العيادة مطلوب للطبيب'
            : 'Location/Clinic address is required for Doctors',
        color: Colors.red.shade700,
      );
      return;
    }
    if (_selectedRole == 'doctor' && !_hasRequiredDoctorDocuments) {
      _showMissingDoctorDocumentsMessage();
      return;
    }
    if (_selectedRole == 'nurse' && addressController.text.trim().isEmpty) {
      _showMessage(
        CarelinkL10n.of(context).isArabic
            ? 'موقع منطقة الخدمة مطلوب للممرض'
            : 'Location/Service area address is required for Nurses',
        color: Colors.red.shade700,
      );
      return;
    }
    final requestedEmail = _normalizeEmail(emailController.text);
    if (_resendSecondsRemaining > 0 &&
        _lastVerificationRequestEmail == requestedEmail) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _authService.sendUnifiedVerificationCode(
        email: requestedEmail,
        phoneDigits: _fullPhoneNumber,
        purpose: VerificationPurpose.signup,
      );

      if (!mounted) return;
      if (_normalizeEmail(emailController.text) != requestedEmail) {
        return;
      }
      final isAr = CarelinkL10n.of(context).isArabic;
      if (res.emailDeliveryFailed) {
        throw Exception(
          isAr
              ? 'تعذر إرسال رسالة التحقق. يرجى المحاولة مرة أخرى.'
              : 'Failed to send verification email. Please try again.',
        );
      }

      final successMsg = isAr
          ? 'تم إرسال رمز التحقق إلى $requestedEmail.'
          : 'A verification code has been sent to $requestedEmail.';

      _startTimer();
      _startResendCooldown(60);
      _otpController.clear();
      setState(() {
        _lastVerificationRequestEmail = requestedEmail;
        _emailVerificationToken = null;
        _phoneVerificationToken = null;
        _verifiedEmail = null;
        _stepIndex = 2; // advance to Step 3
      });
      _showMessage(successMsg, color: Colors.green.shade700);
    } catch (e) {
      if (_normalizeEmail(emailController.text) != requestedEmail) {
        return;
      }
      final cooldownSeconds = _cooldownSecondsFrom(e);
      if (cooldownSeconds != null &&
          cooldownSeconds > 0 &&
          _normalizeEmail(emailController.text) == requestedEmail) {
        _lastVerificationRequestEmail = requestedEmail;
        _startResendCooldown(cooldownSeconds);
        _showCooldownMessage(cooldownSeconds);
      } else {
        _showMessage(e.toString(), color: Colors.red.shade700);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtpAndRegister() async {
    FocusScope.of(context).unfocus();
    final requestedEmail = _lastVerificationRequestEmail;
    final currentEmail = _normalizeEmail(emailController.text);
    if (requestedEmail == null || requestedEmail != currentEmail) {
      _otpController.clear();
      _emailVerificationToken = null;
      _phoneVerificationToken = null;
      _verifiedEmail = null;
      setState(() => _stepIndex = 1);
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showMessage(context.tr('auth.invalidOtp'), color: Colors.red.shade700);
      return;
    }
    if (_selectedRole == 'nurse' && !_hasRequiredNurseDocuments) {
      setState(() => _stepIndex = 1);
      _showMissingNurseDocumentsMessage();
      return;
    }
    if (_selectedRole == 'doctor' && !_hasRequiredDoctorDocuments) {
      setState(() => _stepIndex = 1);
      _showMissingDoctorDocumentsMessage();
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Verify unified code
      final tokens = await _authService.verifyUnifiedCode(
        email: requestedEmail,
        phoneDigits: _fullPhoneNumber,
        code: otp,
        purpose: VerificationPurpose.signup,
      );

      if (!mounted || _normalizeEmail(emailController.text) != requestedEmail) {
        _emailVerificationToken = null;
        _phoneVerificationToken = null;
        _verifiedEmail = null;
        return;
      }
      _emailVerificationToken = tokens.emailVerificationToken;
      _phoneVerificationToken = tokens.phoneVerificationToken;
      _verifiedEmail = requestedEmail;
      if (_verifiedEmail != requestedEmail ||
          _emailVerificationToken == null ||
          _phoneVerificationToken == null) {
        return;
      }

      final cvFile = _doctorCvFile;
      final cvBytes = cvFile?.bytes;
      final doctorCertificates = _selectedRole == 'doctor'
          ? <Map<String, dynamic>>[
              for (var i = 0; i < _doctorRequiredCertificates.length; i++)
                _doctorCertificatePayload(
                  _doctorRequiredCertificates[i]!,
                  'Certificate ${i + 1}',
                ),
              for (var i = 0; i < _doctorAdditionalCertificates.length; i++)
                if (_doctorAdditionalCertificates[i] != null)
                  _doctorCertificatePayload(
                    _doctorAdditionalCertificates[i]!,
                    'Additional Certificate ${i + 1}',
                  ),
            ]
          : null;

      // 2. Perform register
      final response = await ApiService().register(
        nameController.text.trim(),
        requestedEmail,
        _fullPhoneNumber,
        passwordController.text,
        _selectedRole,
        confirmPassword: confirmPasswordController.text,
        specialization: _selectedRole == 'patient'
            ? null
            : _selectedRole == 'doctor'
            ? _doctorSpecializationValue()
            : specialtyController.text.trim(),
        addressText: addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
        gpsLat: _gpsLat,
        gpsLng: _gpsLng,
        dateOfBirth: _selectedRole == 'patient'
            ? dateOfBirthController.text.trim()
            : null,
        gender: _selectedRole == 'patient' ? _selectedGender : null,
        chronicDiseases: _selectedRole == 'patient'
            ? chronicDiseasesController.text.trim()
            : null,
        allergies: _selectedRole == 'patient'
            ? allergiesController.text.trim()
            : null,
        currentMedications: _selectedRole == 'patient'
            ? currentMedicationsController.text.trim()
            : null,
        experienceYears: _selectedRole == 'patient'
            ? null
            : int.tryParse(experienceController.text.trim()),
        licenseNumber: _selectedRole == 'patient'
            ? null
            : licenseController.text.trim(),
        serviceType: _selectedRole == 'patient'
            ? null
            : (_selectedRole == 'doctor'
                  ? _consultationType
                  : (_homeCareAvailability ? 'home care' : 'online')),
        serviceAreas: _selectedRole == 'patient'
            ? null
            : serviceAreasController.text.trim(),
        biography: _selectedRole == 'patient'
            ? null
            : bioController.text.trim(),
        previousWorkplaces: _selectedRole == 'patient'
            ? null
            : workplaceHistoryController.text.trim(),
        cvFile: _selectedRole == 'patient'
            ? null
            : cvFileController.text.trim(),
        medicalCertificate: _selectedRole == 'patient'
            ? null
            : medicalCertificateController.text.trim(),
        nursingLicense: _selectedRole == 'patient'
            ? null
            : nursingLicenseFileController.text.trim(),
        idCard: _selectedRole == 'patient'
            ? null
            : idCardController.text.trim(),
        homeCareAvailability: _selectedRole == 'nurse'
            ? _homeCareAvailability
            : null,
        phoneVerificationToken: _phoneVerificationToken,
        emailVerificationToken: _emailVerificationToken,
        cvFileName: _selectedRole == 'doctor' ? cvFile?.name : null,
        cvFileData: _selectedRole == 'doctor' && cvBytes != null
            ? base64Encode(cvBytes)
            : null,
        cvMimeType: _selectedRole == 'doctor' ? 'application/pdf' : null,
        cvFileSize: _selectedRole == 'doctor' ? cvFile?.size : null,
        certificates: doctorCertificates,
      );

      // Add emergency contact if it was entered and table supports it
      final newUserId = response['userId']?.toString();
      if (newUserId != null &&
          _selectedRole == 'patient' &&
          emergencyContactController.text.trim().isNotEmpty) {
        try {
          await ApiService().updatePatientProfile(newUserId, {
            'emergencyContact': emergencyContactController.text.trim(),
          });
        } catch (e) {
          debugPrint('Could not save emergency contact: $e');
        }
      }

      _showMessage(
        response['message']?.toString() ?? 'Account created successfully',
        color: Colors.green.shade700,
      );

      // Redirect home
      navigateCarelinkHomeForUserMap(response);
    } catch (e) {
      _showMessage(e.toString(), color: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStepIndicator(CarelinkPalette p) {
    final isAr = CarelinkL10n.of(context).isArabic;
    final steps = isAr
        ? ['معلومات الحساب', 'تفاصيل الدور', 'التحقق']
        : ['Account Info', 'Role Details', 'Verification'];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(steps.length, (index) {
            final isCompleted = _stepIndex > index;
            final isCurrent = _stepIndex == index;
            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppColors.primary
                          : (isCurrent ? AppColors.primary : p.stroke),
                      border: isCurrent
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : Text(
                              '${index + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isCurrent || isCompleted
                                    ? Colors.white
                                    : p.inkMuted,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      steps[index],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrent ? p.inkDark : p.inkMuted,
                      ),
                    ),
                  ),
                  if (index < steps.length - 1)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        height: 2,
                        color: _stepIndex > index
                            ? AppColors.primary
                            : p.stroke,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: (_stepIndex + 1) / steps.length,
          backgroundColor: p.stroke,
          color: AppColors.primary,
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildStep1BasicInfo(CarelinkPalette p) {
    final isAr = CarelinkL10n.of(context).isArabic;
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name Field
          _buildTextField(
            p,
            label: context.tr('auth.fullName'),
            hint: context.tr('auth.placeholder.fullName'),
            icon: Icons.person_outline_rounded,
            controller: nameController,
            validator: (v) {
              if ((v ?? '').trim().length < 2) {
                return isAr
                    ? 'يرجى إدخال الاسم الكامل'
                    : 'Please enter your full name';
              }
              return null;
            },
          ),

          // Phone number
          _buildFieldWrapper(
            p,
            label: context.tr('auth.phoneNumber'),
            child: TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              onChanged: _normalizePhoneFieldInput,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                LengthLimitingTextInputFormatter(
                  _selectedCountry.code == 'PS'
                      ? 14
                      : _selectedCountry.phoneNumberLength + 4,
                ),
              ],
              style: GoogleFonts.inter(
                color: p.inkDark,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: AppColors.primary,
              validator: (v) {
                final raw = v ?? '';
                if (raw.isEmpty) {
                  return isAr
                      ? 'يرجى إدخال رقم الهاتف'
                      : 'Please enter phone number';
                }
                if (PhoneNumberUtils.normalizeForCountry(
                      input: raw,
                      countryCode: _selectedCountry.code,
                      dialCode: _selectedCountry.dialCode,
                    ) ==
                    null) {
                  return isAr
                      ? 'رقم الهاتف غير صحيح.'
                      : 'Invalid phone number.';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: context.tr('auth.placeholder.phone'),
                hintStyle: GoogleFonts.inter(
                  color: p.inkMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.5,
                ),
                prefixIcon: InkWell(
                  onTap: _showCountryPicker,
                  borderRadius: isAr
                      ? const BorderRadius.only(
                          topRight: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        )
                      : const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 14),
                      Text(
                        _selectedCountry.flag,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 6),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          _selectedCountry.dialCode,
                          style: GoogleFonts.inter(
                            color: p.inkDark,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: p.inkMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 24, color: p.stroke),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                filled: true,
                fillColor: p.isDark
                    ? const Color(0xFF123640).withValues(alpha: 0.55)
                    : Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.stroke, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.stroke, width: 1),
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
                  borderSide: BorderSide(color: Colors.red.shade400, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.red.shade600,
                    width: 1.5,
                  ),
                ),
                errorStyle: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.red.shade600,
                ),
              ),
            ),
          ),

          // Email
          _buildTextField(
            p,
            label: context.tr('auth.emailAddress'),
            hint: context.tr('auth.placeholder.email'),
            icon: Icons.email_outlined,
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final email = (v ?? '').trim();
              if (email.isEmpty) {
                return isAr ? 'البريد الإلكتروني مطلوب' : 'Email is required';
              }
              if (!AuthService.isValidEmailFormat(email)) {
                return context.tr('auth.enterValidEmail');
              }
              return null;
            },
          ),

          // Password
          _buildTextField(
            p,
            label: context.tr('auth.password'),
            hint: context.tr('auth.placeholder.password'),
            icon: Icons.lock_outline_rounded,
            controller: passwordController,
            obscure: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: p.inkMuted,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return context.tr('auth.passwordRequired');
              }
              if (!_isStrongPassword(v)) {
                return isAr
                    ? 'كلمة المرور لا تستوفي الشروط'
                    : 'Password does not meet requirements';
              }
              return null;
            },
          ),

          // Password Checklist
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChecklistItem(
                  context.tr('auth.passwordChecklist.minChars'),
                  passwordController.text.length >= 8,
                  p,
                ),
                _buildChecklistItem(
                  context.tr('auth.passwordChecklist.uppercase'),
                  passwordController.text.contains(RegExp(r'[A-Z]')),
                  p,
                ),
                _buildChecklistItem(
                  context.tr('auth.passwordChecklist.number'),
                  passwordController.text.contains(RegExp(r'\d')),
                  p,
                ),
              ],
            ),
          ),

          // Confirm Password
          _buildTextField(
            p,
            label: context.tr('auth.confirmPassword'),
            hint: context.tr('auth.placeholder.confirmPassword'),
            icon: Icons.lock_outline_rounded,
            controller: confirmPasswordController,
            obscure: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: p.inkMuted,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            validator: (v) {
              if (v != passwordController.text) {
                return context.tr('auth.passwordsNoMatch');
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Continue Button
          ElevatedButton(
            onPressed: () {
              if (_step1FormKey.currentState!.validate()) {
                setState(() {
                  _stepIndex = 1;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              isAr ? 'متابعة' : 'Continue',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldWrapper(
    CarelinkPalette p, {
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(
    CarelinkPalette p, {
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    List<TextInputFormatter>? formatters,
  }) {
    return _buildFieldWrapper(
      p,
      label: label,
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        readOnly: readOnly,
        onTap: onTap,
        inputFormatters: formatters,
        style: GoogleFonts.inter(
          color: p.inkDark,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: p.inkMuted,
            fontWeight: FontWeight.w500,
            fontSize: 14.5,
          ),
          prefixIcon: Icon(icon, color: p.inkMuted, size: 22),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: p.isDark
              ? const Color(0xFF123640).withValues(alpha: 0.55)
              : Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.stroke, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.stroke, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
          ),
          errorStyle: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.red.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildUploadTile(
    CarelinkPalette p, {
    required String title,
    required TextEditingController controller,
    required String? fileName,
    required VoidCallback onTap,
    bool required = false,
  }) {
    final hasFile = controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.isDark
                ? const Color(0xFF123640).withValues(alpha: 0.55)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasFile ? AppColors.primary : p.stroke,
              width: hasFile ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasFile
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                color: hasFile ? AppColors.primary : p.inkMuted,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title${required ? ' *' : ''}',
                      style: GoogleFonts.inter(
                        color: p.inkDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasFile ? (fileName ?? 'Selected file') : 'PDF / Image',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: p.inkMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
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

  Widget _buildProviderDocumentsUpload(CarelinkPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documents Upload',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 8),
          _buildUploadTile(
            p,
            title: 'Medical Certificate',
            required: _selectedRole == 'nurse',
            controller: medicalCertificateController,
            fileName: _medicalCertificateFileName,
            onTap: () => _pickProviderDocument(
              controller: medicalCertificateController,
              setFileName: (name) => _medicalCertificateFileName = name,
            ),
          ),
          _buildUploadTile(
            p,
            title: _selectedRole == 'nurse'
                ? 'Nursing License'
                : 'Professional License',
            required: _selectedRole == 'nurse',
            controller: nursingLicenseFileController,
            fileName: _nursingLicenseFileName,
            onTap: () => _pickProviderDocument(
              controller: nursingLicenseFileController,
              setFileName: (name) => _nursingLicenseFileName = name,
            ),
          ),
          _buildUploadTile(
            p,
            title: 'ID Card',
            required: _selectedRole == 'nurse',
            controller: idCardController,
            fileName: _idCardFileName,
            onTap: () => _pickProviderDocument(
              controller: idCardController,
              setFileName: (name) => _idCardFileName = name,
            ),
          ),
          _buildUploadTile(
            p,
            title: 'CV File',
            controller: cvFileController,
            fileName: _cvFileName,
            onTap: () => _pickProviderDocument(
              controller: cvFileController,
              setFileName: (name) => _cvFileName = name,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2RoleDetails(CarelinkPalette p) {
    final isAr = CarelinkL10n.of(context).isArabic;
    final roles = [
      (
        'patient',
        context.tr('auth.patient'),
        context.tr('auth.patientDesc'),
        Icons.person_pin_rounded,
      ),
      (
        'doctor',
        context.tr('auth.doctor'),
        context.tr('auth.doctorDesc'),
        Icons.medical_services_rounded,
      ),
      (
        'nurse',
        context.tr('auth.nurse'),
        context.tr('auth.nurseDesc'),
        Icons.local_hospital_rounded,
      ),
    ];

    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('auth.chooseAccountType'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: p.inkDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ...roles.map((item) {
            final roleKey = item.$1;
            final title = item.$2;
            final desc = item.$3;
            final icon = item.$4;
            final isSelected = _selectedRole == roleKey;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedRole = roleKey);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : p.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : p.stroke,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : p.stroke.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            color: isSelected ? Colors.white : p.inkMuted,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppColors.primary
                                      : p.inkDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: p.inkMuted,
                                  height: 1.4,
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
            );
          }),
          const SizedBox(height: 24),

          // Date of Birth
          _buildTextField(
            p,
            label: context.tr('auth.dateOfBirth'),
            hint: context.tr('auth.placeholder.dateOfBirth'),
            icon: Icons.calendar_today_rounded,
            controller: dateOfBirthController,
            readOnly: true,
            onTap: _pickDateOfBirth,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return isAr
                    ? 'تاريخ الميلاد مطلوب'
                    : 'Date of birth is required';
              }
              return null;
            },
          ),

          // Gender
          _buildFieldWrapper(
            p,
            label: context.tr('auth.gender'),
            child: Row(
              children: [
                Expanded(
                  child: _buildGenderCard(
                    label: isAr ? 'ذكر' : 'Male',
                    value: 'male',
                    icon: Icons.male_rounded,
                    isSelected: _selectedGender == 'male',
                    p: p,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGenderCard(
                    label: isAr ? 'أنثى' : 'Female',
                    value: 'female',
                    icon: Icons.female_rounded,
                    isSelected: _selectedGender == 'female',
                    p: p,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Location (Required for Doctors/Nurses, Optional for Patients)
          _buildTextField(
            p,
            label: context.tr('auth.location'),
            hint: isAr ? 'اختر الموقع' : 'Select location',
            icon: Icons.location_on_outlined,
            controller: addressController,
            readOnly: true,
            onTap: _pickLocation,
            suffixIcon: IconButton(
              tooltip: isAr ? 'تحديد على الخريطة' : 'Pick on map',
              icon: const Icon(Icons.map_outlined, color: AppColors.primary),
              onPressed: _pickLocation,
            ),
            validator: (v) {
              if (_selectedRole == 'nurse') {
                if (v == null || v.trim().isEmpty) {
                  return isAr ? 'الموقع مطلوب' : 'Location is required';
                }
              }
              return null;
            },
          ),

          // Role specific Patient fields
          if (_selectedRole == 'patient') ...[
            _buildTextField(
              p,
              label: context.tr('auth.chronicDiseases'),
              hint: isAr
                  ? 'مثال: السكري، ضغط الدم'
                  : 'e.g. Diabetes, Hypertension',
              icon: Icons.medical_information_outlined,
              controller: chronicDiseasesController,
            ),
            _buildTextField(
              p,
              label: context.tr('auth.allergies'),
              hint: isAr
                  ? 'مثال: البنسلين، الفول السوداني'
                  : 'e.g. Penicillin, Peanuts',
              icon: Icons.warning_amber_rounded,
              controller: allergiesController,
            ),
            _buildTextField(
              p,
              label: context.tr('auth.currentMedications'),
              hint: isAr ? 'مثال: ميتفورمين 500 ملغ' : 'e.g. Metformin 500mg',
              icon: Icons.medication_outlined,
              controller: currentMedicationsController,
            ),
            _buildTextField(
              p,
              label: context.tr('auth.emergencyContact'),
              hint: isAr
                  ? 'مثال: الأخ: +970599000000'
                  : 'e.g. Brother: +970599000000',
              icon: Icons.contact_phone_outlined,
              controller: emergencyContactController,
            ),
          ],

          // Role specific Doctor fields
          if (_selectedRole == 'doctor') ...[
            _buildDoctorSpecialtyDropdown(p),
            if (_selectedDoctorSpecialty == 'Other')
              _buildTextField(
                p,
                label: 'Please specify your specialization',
                hint: 'Enter your medical specialization',
                icon: Icons.edit_note_outlined,
                controller: customSpecialtyController,
                validator: (v) {
                  if (_selectedDoctorSpecialty == 'Other' &&
                      (v == null || v.trim().isEmpty)) {
                    return 'Custom specialization is required';
                  }
                  return null;
                },
              ),
            if (_showLegacyDoctorSpecialtyField)
              _buildTextField(
                p,
                label: context.tr('auth.specialization'),
                hint: isAr ? 'مثال: طبيب قلب' : 'e.g. Cardiologist',
                icon: Icons.health_and_safety_outlined,
                controller: specialtyController,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return isAr ? 'التخصص مطلوب' : 'Specialty is required';
                  }
                  return null;
                },
              ),
            _buildTextField(
              p,
              label: context.tr('auth.licenseNumber'),
              hint: isAr ? 'رقم الترخيص الطبي' : 'Medical license ID number',
              icon: Icons.badge_outlined,
              controller: licenseController,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return isAr
                      ? 'رقم الترخيص مطلوب'
                      : 'License number is required';
                }
                return null;
              },
            ),
            _buildTextField(
              p,
              label: context.tr('auth.experienceYears'),
              hint: isAr ? 'عدد سنوات الخبرة' : 'Years of experience',
              icon: Icons.timeline_outlined,
              controller: experienceController,
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0 || n > 80) {
                  return isAr
                      ? 'أدخل رقماً صحيحاً بين 0 و80'
                      : 'Enter a valid number between 0 and 80';
                }
                return null;
              },
            ),
            _buildTextField(
              p,
              label: context.tr('auth.bio'),
              hint: isAr
                  ? 'نبذة مختصرة عن خبرتك المهنية'
                  : 'Brief professional background bio',
              icon: Icons.description_outlined,
              controller: bioController,
            ),
            _buildDoctorProfessionalDocuments(p),
            _buildFieldWrapper(
              p,
              label: context.tr('auth.consultationType'),
              child: DropdownButtonFormField<String>(
                initialValue: _consultationType,
                dropdownColor: p.surface,
                icon: Icon(Icons.expand_more_rounded, color: p.inkMuted),
                style: GoogleFonts.inter(
                  color: p.inkDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: p.isDark
                      ? const Color(0xFF123640).withValues(alpha: 0.55)
                      : Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: p.stroke, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: p.stroke, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'home',
                    child: Text(
                      isAr ? 'زيارات منزلية فقط' : 'Home visits only',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'online',
                    child: Text(
                      isAr
                          ? 'استشارات عن بُعد فقط'
                          : 'Online consultations only',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'both',
                    child: Text(
                      isAr
                          ? 'زيارات منزلية واستشارات عن بُعد'
                          : 'Home & Online consultations',
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _consultationType = v);
                  }
                },
              ),
            ),
            const SizedBox(height: 18),
            _buildTextField(
              p,
              label: 'Previous workplaces',
              hint: 'Hospitals, clinics, home care agencies',
              icon: Icons.business_center_outlined,
              controller: workplaceHistoryController,
            ),
          ],

          // Role specific Nurse fields
          if (_selectedRole == 'nurse') ...[
            _buildTextField(
              p,
              label: isAr ? 'تخصص التمريض' : 'Nursing Specialty',
              hint: isAr ? 'مثال: تمريض أطفال' : 'e.g. Pediatric Nurse',
              icon: Icons.health_and_safety_outlined,
              controller: specialtyController,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return isAr ? 'التخصص مطلوب' : 'Specialty is required';
                }
                return null;
              },
            ),
            _buildTextField(
              p,
              label: context.tr('auth.licenseNumber'),
              hint: isAr ? 'رقم ترخيص التمريض' : 'Nursing license ID number',
              icon: Icons.badge_outlined,
              controller: licenseController,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return isAr
                      ? 'رقم الترخيص مطلوب'
                      : 'License number is required';
                }
                return null;
              },
            ),
            _buildTextField(
              p,
              label: context.tr('auth.experienceYears'),
              hint: isAr ? 'عدد سنوات الخبرة' : 'Years of experience',
              icon: Icons.timeline_outlined,
              controller: experienceController,
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0 || n > 80) {
                  return isAr
                      ? 'أدخل رقماً صحيحاً بين 0 و80'
                      : 'Enter a valid number between 0 and 80';
                }
                return null;
              },
            ),
            _buildFieldWrapper(
              p,
              label: isAr ? 'متاح للرعاية المنزلية' : 'Home Care Availability',
              child: SwitchListTile(
                title: Text(
                  context.tr('auth.homeCareAvailability'),
                  style: GoogleFonts.inter(fontSize: 14, color: p.inkDark),
                ),
                value: _homeCareAvailability,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => setState(() => _homeCareAvailability = val),
              ),
            ),
            _buildTextField(
              p,
              label: context.tr('auth.serviceAreas'),
              hint: isAr ? 'مثال: رام الله، البيرة' : 'e.g. Ramallah, Al-Bireh',
              icon: Icons.map_outlined,
              controller: serviceAreasController,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return isAr
                      ? 'مناطق الخدمة مطلوبة'
                      : 'Service areas are required';
                }
                return null;
              },
            ),
            _buildTextField(
              p,
              label: context.tr('auth.bio'),
              hint: isAr ? 'نبذة تعريفية مختصرة' : 'Brief background bio',
              icon: Icons.description_outlined,
              controller: bioController,
            ),
            _buildTextField(
              p,
              label: 'Previous workplaces',
              hint: 'Hospitals, clinics, home care agencies',
              icon: Icons.business_center_outlined,
              controller: workplaceHistoryController,
            ),
            _buildProviderDocumentsUpload(p),
          ],

          const SizedBox(height: 24),

          // Sticky action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _stepIndex = 0),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.inkDark,
                    side: BorderSide(color: p.stroke),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(isAr ? 'السابق' : 'Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _resendSecondsRemaining > 0
                      ? null
                      : _sendVerificationCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _resendSecondsRemaining > 0
                              ? context.tr(
                                  'auth.sendCodeAfter',
                                  args: {'seconds': '$_resendSecondsRemaining'},
                                )
                              : context.tr('auth.sendCode'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3VerifyOtp(CarelinkPalette p) {
    final isAr = CarelinkL10n.of(context).isArabic;
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 52,
      textStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: p.inkDark,
      ),
      decoration: BoxDecoration(
        color: p.isDark
            ? const Color(0xFF123640).withValues(alpha: 0.55)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.stroke),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('auth.otpCode'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: p.inkDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isAr
              ? 'لقد أرسلنا رمز التحقق إلى بريدك الإلكتروني:\n${emailController.text.trim()}'
              : 'We sent a verification code to your email:\n${emailController.text.trim()}',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: p.inkMuted,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // OTP inputs using pinput
        Center(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Pinput(
              length: 6,
              controller: _otpController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: defaultPinTheme.copyWith(
                decoration: defaultPinTheme.decoration!.copyWith(
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
              ),
              submittedPinTheme: defaultPinTheme.copyWith(
                decoration: defaultPinTheme.decoration!.copyWith(
                  color: AppColors.primary.withValues(alpha: 0.05),
                ),
              ),
              hapticFeedbackType: HapticFeedbackType.lightImpact,
              onCompleted: (pin) => _verifyOtpAndRegister(),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Countdown Timer & Resend
        Column(
          children: [
            if (_secondsRemaining > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAr
                        ? 'ينتهي خلال ${_formatTime(_secondsRemaining)}'
                        : 'Expires in ${_formatTime(_secondsRemaining)}',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _isLoading || _resendSecondsRemaining > 0
                  ? null
                  : _sendVerificationCode,
              icon: Icon(
                _resendSecondsRemaining > 0
                    ? Icons.schedule_rounded
                    : Icons.refresh_rounded,
                size: 18,
              ),
              label: Text(
                _resendSecondsRemaining > 0
                    ? context.tr(
                        'auth.sendCodeAfter',
                        args: {'seconds': '$_resendSecondsRemaining'},
                      )
                    : context.tr('auth.resendCode'),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                disabledForegroundColor: p.inkMuted,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Verify button
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _stepIndex = 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.inkDark,
                  side: BorderSide(color: p.stroke),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(isAr ? 'السابق' : 'Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtpAndRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        context.tr('auth.verifyAndContinue'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final isAr = CarelinkL10n.of(context).isArabic;

    return Scaffold(
      backgroundColor: p.pageBg,
      resizeToAvoidBottomInset: true,
      body: Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: Stack(
          children: [
            // Healthcare background custom painter
            Positioned.fill(
              child: CustomPaint(
                painter: _SignupBackdropPainter(isDark: _isDark),
              ),
            ),

            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Custom Back Button Header
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: p.inkDark,
                            onPressed: () {
                              if (_stepIndex > 0) {
                                setState(() {
                                  _stepIndex--;
                                });
                              } else {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                        const Spacer(),
                        const CarelinkBrandLogo(height: 28),
                        const Spacer(),
                        PatientHeaderActions(color: AppColors.primary),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  // Form Container Card
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          20 + viewInsets,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: p.surface.withValues(
                                alpha: _isDark ? 0.94 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: p.stroke.withValues(alpha: 0.7),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: _isDark ? 0.4 : 0.06,
                                  ),
                                  blurRadius: 36,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStepIndicator(p),
                                const SizedBox(height: 24),
                                if (_stepIndex == 0)
                                  _buildStep1BasicInfo(p)
                                else if (_stepIndex == 1)
                                  _buildStep2RoleDetails(p)
                                else if (_stepIndex == 2)
                                  _buildStep3VerifyOtp(p),
                              ],
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

  String _doctorSpecializationValue() {
    if (_selectedDoctorSpecialty == 'Other') {
      return customSpecialtyController.text.trim();
    }
    return _selectedDoctorSpecialty?.trim() ?? '';
  }

  Widget _buildDoctorSpecialtyDropdown(CarelinkPalette p) {
    return _buildFieldWrapper(
      p,
      label: 'Medical Specialty',
      child: DropdownButtonFormField<String>(
        initialValue: _selectedDoctorSpecialty,
        isExpanded: true,
        dropdownColor: p.surface,
        icon: Icon(Icons.expand_more_rounded, color: p.inkMuted),
        style: GoogleFonts.inter(
          color: p.inkDark,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Select your medical specialty',
          prefixIcon: Icon(Icons.health_and_safety_outlined, color: p.inkMuted),
          filled: true,
          fillColor: p.isDark
              ? const Color(0xFF123640).withValues(alpha: 0.55)
              : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        items: _doctorSpecialties
            .map(
              (specialty) => DropdownMenuItem<String>(
                value: specialty,
                child: Text(specialty),
              ),
            )
            .toList(),
        validator: (value) => value == null || value.isEmpty
            ? 'Medical specialty is required'
            : null,
        onChanged: (value) {
          setState(() {
            _selectedDoctorSpecialty = value;
            if (value != 'Other') customSpecialtyController.clear();
          });
        },
      ),
    );
  }

  Widget _buildDoctorDocumentTile(
    CarelinkPalette p, {
    required String title,
    required String helper,
    required PlatformFile? file,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasFile = file != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.isDark
                  ? const Color(0xFF123640).withValues(alpha: 0.55)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasFile ? AppColors.primary : p.stroke,
                width: hasFile ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasFile
                        ? Icons.description_rounded
                        : Icons.upload_file_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: p.inkDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasFile ? file.name : helper,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: hasFile ? AppColors.primary : p.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasFile)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.red.shade600,
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: p.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorProfessionalDocuments(CarelinkPalette p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.isDark
            ? const Color(0xFF0D2D36).withValues(alpha: 0.55)
            : const Color(0xFFF7FBFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_copy_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Professional Documents',
                style: GoogleFonts.inter(
                  color: p.inkDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your account remains pending until these documents are reviewed.',
            style: GoogleFonts.inter(
              color: p.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _buildDoctorDocumentTile(
            p,
            title: 'Upload CV *',
            helper: 'PDF only, maximum 10 MB',
            file: _doctorCvFile,
            onPick: () async {
              final file = await _pickDoctorDocument(pdfOnly: true);
              if (file != null) setState(() => _doctorCvFile = file);
            },
            onRemove: () => setState(() => _doctorCvFile = null),
          ),
          const SizedBox(height: 4),
          Text(
            'Required Certificates',
            style: GoogleFonts.inter(
              color: p.inkDark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _doctorRequiredCertificates.length; i++)
            _buildDoctorDocumentTile(
              p,
              title: 'Certificate ${i + 1} *',
              helper: 'PDF, JPG, or PNG',
              file: _doctorRequiredCertificates[i],
              onPick: () async {
                final file = await _pickDoctorDocument(pdfOnly: false);
                if (file != null) {
                  setState(() => _doctorRequiredCertificates[i] = file);
                }
              },
              onRemove: () =>
                  setState(() => _doctorRequiredCertificates[i] = null),
            ),
          if (_doctorAdditionalCertificates.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Additional Certificates (Optional)',
              style: GoogleFonts.inter(
                color: p.inkDark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _doctorAdditionalCertificates.length; i++)
              _buildDoctorDocumentTile(
                p,
                title: 'Additional Certificate ${i + 1}',
                helper: 'PDF, JPG, or PNG',
                file: _doctorAdditionalCertificates[i],
                onPick: () async {
                  final file = await _pickDoctorDocument(pdfOnly: false);
                  if (file != null) {
                    setState(() => _doctorAdditionalCertificates[i] = file);
                  }
                },
                onRemove: () =>
                    setState(() => _doctorAdditionalCertificates.removeAt(i)),
              ),
          ],
          OutlinedButton.icon(
            onPressed: () =>
                setState(() => _doctorAdditionalCertificates.add(null)),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Another Certificate'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

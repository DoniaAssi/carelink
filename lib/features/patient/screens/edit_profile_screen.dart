import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, MissingPluginException;
import 'package:image_picker/image_picker.dart';

import 'package:carelink/core/carelink_date_picker.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/profile_avatar.dart' show profileImageUrlFromMap;
import 'package:carelink/features/auth/registration/getx/signup_location_picker_screen.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

enum _PhotoSheetAction { gallery, camera, remove }

class EditProfileScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController fullNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController profileImageUrlController;
  late TextEditingController dateOfBirthController;

  String? selectedGender;
  double? _gpsLat;
  double? _gpsLng;
  bool isLoading = false; // saving
  Uint8List? _pickedImageBytes;

  bool get _isArabic => localeController.isArabic;
  String _t(String en, String ar) => _isArabic ? ar : en;

  // Dedicated AudioPlayer for the success sound.
  // Created once, reused, disposed with the screen.
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    fullNameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
    addressController = TextEditingController();
    profileImageUrlController = TextEditingController();
    dateOfBirthController = TextEditingController();

    // Seed instantly from the data passed in (no broken empty fields)…
    _populateFrom(widget.userData);
    // …then refresh from the backend so the DB image/fields are authoritative.
    _initialLoad();
  }

  void _populateFrom(Map<String, dynamic> d) {
    fullNameController.text = d['fullName']?.toString() ?? '';
    emailController.text = d['email']?.toString() ?? '';
    phoneController.text = d['phone']?.toString() ?? '';
    addressController.text = d['addressText']?.toString() ?? '';
    profileImageUrlController.text =
        profileImageUrlFromMap(Map<String, dynamic>.from(d)) ?? '';
    dateOfBirthController.text = _normalizeDateOfBirth(d['dateOfBirth']);
    selectedGender = d['gender']?.toString();
    _gpsLat = _asDouble(d['gpsLat']);
    _gpsLng = _asDouble(d['gpsLng']);
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _normalizeDateOfBirth(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return value;

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final localDate = parsed.isUtc ? parsed.toLocal() : parsed;
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '${localDate.year}-$month-$day';
  }

  String _formatDateOfBirthForDisplay() {
    return dateOfBirthController.text.trim();
  }

  Future<void> _initialLoad() async {
    try {
      final fresh = await ApiService().getPatientProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _populateFrom(fresh);
      });
    } catch (_) {
      // Keep the seeded values. The form remains visible and editable.
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    profileImageUrlController.dispose();
    dateOfBirthController.dispose();
    super.dispose();
  }

  String _formatGenderForDisplay() {
    switch (selectedGender) {
      case 'male':
        return _t('Male', 'ذكر');
      case 'female':
        return _t('Female', 'أنثى');
      case 'other':
        return _t('Other', 'آخر');
      case 'prefer_not_to_say':
        return _t('Prefer not to say', 'يفضل عدم الإفصاح');
      default:
        return '';
    }
  }

  String? _networkProfileImageUrl() {
    var url = profileImageUrlController.text.trim();
    if (url.isEmpty) return null;
    final lower = url.toLowerCase();
    if (lower.contains('robot') ||
        lower.contains('robohash') ||
        lower.startsWith('data:image')) {
      return null;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final separator = url.startsWith('/') ? '' : '/';
      url = '${ApiService.baseUrl}$separator$url';
    }
    return url.startsWith('http://') || url.startsWith('https://') ? url : null;
  }

  Future<void> _reloadProfileFromBackend() async {
    final fresh = await ApiService().getPatientProfile(widget.userId);
    if (!mounted) return;
    final imageUrl = profileImageUrlFromMap(fresh);
    setState(() {
      if (imageUrl != null) {
        profileImageUrlController.text = imageUrl;
      } else {
        profileImageUrlController.clear();
      }
      _pickedImageBytes = null;
    });
  }

  void _clearProfilePhoto() {
    setState(() {
      _pickedImageBytes = null;
      profileImageUrlController.clear();
    });
  }

  // ───────────────────────── Feedback helpers ─────────────────────────

  /// Premium success feedback:
  ///   1. Light haptic  (immediate, tactile)
  ///   2. Real WAV tone (assets/sounds/success.wav — ~320 ms, 880 Hz)
  ///
  /// Called ONLY after a confirmed backend success response.
  /// Never called on validation failure or network error.
  Future<void> _celebrateSuccess() async {
    // Haptic first (instant).
    await HapticFeedback.lightImpact();
    // Then play the real asset sound.
    try {
      await _audioPlayer.stop(); // stop any lingering playback
      await _audioPlayer.setVolume(0.85);
      await _audioPlayer.play(AssetSource('sounds/success.wav'));
    } catch (e) {
      // Audio failure must never break the save UX — just log and continue.
      debugPrint('[EditProfile] success sound error: $e');
    }
  }

  void _showPolishedSnack(String message, {bool success = false}) {
    if (!mounted) return;
    final p = CarelinkPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final accent = success ? scheme.primary : scheme.error;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surface,
        elevation: 8,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        duration: Duration(milliseconds: success ? 2200 : 3200),
        content: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_rounded : Icons.error_outline_rounded,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: p.inkDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Photo sheet ────────────────────────────

  Future<void> _showImageSourceSheet() async {
    final p = CarelinkPalette.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final hasExisting =
        _pickedImageBytes != null ||
        profileImageUrlController.text.trim().isNotEmpty;

    final choice = await showModalBottomSheet<_PhotoSheetAction>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  _t('Profile Photo', 'الصورة الشخصية'),
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: colorScheme.primary,
                ),
                title: Text(
                  _t('Choose from gallery', 'اختر من المعرض'),
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(context, _PhotoSheetAction.gallery),
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: colorScheme.primary,
                ),
                title: Text(
                  _t('Take a photo', 'التقط صورة'),
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(context, _PhotoSheetAction.camera),
              ),
              if (hasExisting)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: p.inkMuted),
                  title: Text(
                    _t('Remove photo', 'إزالة الصورة'),
                    style: TextStyle(
                      color: p.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, _PhotoSheetAction.remove),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    switch (choice) {
      case _PhotoSheetAction.gallery:
        await _pickProfileImage(ImageSource.gallery);
      case _PhotoSheetAction.camera:
        await _pickProfileImage(ImageSource.camera);
      case _PhotoSheetAction.remove:
        _clearProfilePhoto();
      case null:
        break;
    }
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (!mounted) return;
        _showPolishedSnack(
          _t(
            'Image size must be less than 5MB',
            'يجب أن يكون حجم الصورة أقل من 5 ميجابايت',
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _pickedImageBytes = bytes;
        if (profileImageUrlController.text.trim().isNotEmpty) {
          profileImageUrlController.clear();
        }
      });
      if (!mounted) return;
      _showPolishedSnack(
        _t(
          'Photo selected — tap Save to apply',
          'تم تحديد الصورة - اضغط حفظ للتطبيق',
        ),
        success: true,
      );
    } on MissingPluginException {
      if (!mounted) return;
      _showPolishedSnack(
        _t(
          'Image picker needs a full app restart. Stop and run again.',
          'يحتاج منتقي الصور إلى إعادة تشغيل كاملة للتطبيق.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showPolishedSnack(
        kIsWeb && source == ImageSource.camera
            ? _t(
                'Camera not available. Try the gallery option.',
                'الكاميرا غير متوفرة. جرب خيار المعرض.',
              )
            : _t(
                'Could not pick image. Please try again.',
                'تعذر اختيار الصورة. يرجى المحاولة مرة أخرى.',
              ),
      );
    }
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
    if (result == null || !mounted) return;
    setState(() {
      addressController.text = result.address;
      _gpsLat = result.latitude;
      _gpsLng = result.longitude;
    });
  }

  Future<void> _showGenderSheet() async {
    final items = <MapEntry<String, String>>[
      MapEntry('male', _t('Male', 'ذكر')),
      MapEntry('female', _t('Female', 'أنثى')),
      MapEntry('other', _t('Other', 'آخر')),
      MapEntry(
        'prefer_not_to_say',
        _t('Prefer not to say', 'يفضل عدم الإفصاح'),
      ),
    ];
    final p = CarelinkPalette.of(context);
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                _t('Gender', 'الجنس'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Divider(height: 1),
            ...items.map(
              (e) => ListTile(
                title: Text(
                  e.value,
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                onTap: () => Navigator.pop(context, e.key),
              ),
            ),
          ],
        ),
      ),
    );
    if (v != null) setState(() => selectedGender = v);
  }

  // ─────────────────────────── Success overlay ────────────────────────

  Future<void> _showSuccessOverlay() async {
    final p = CarelinkPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimatedCheckmark(color: scheme.primary),
              const SizedBox(height: 20),
              Text(
                _t(
                  'Profile updated successfully',
                  'تم تحديث الملف الشخصي بنجاح',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: p.inkDark,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1250));
    if (mounted) Navigator.pop(context); // close dialog
  }

  // ─────────────────────────────── Save ───────────────────────────────

  Future<void> saveChanges() async {
    final nameStr = fullNameController.text.trim();
    final emailStr = emailController.text.trim();
    final phoneStr = phoneController.text.trim();
    final emailReg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    // Validation (no success feedback here).
    if (nameStr.isEmpty) {
      return _showPolishedSnack(
        _t('Please enter your full name', 'يرجى إدخال الاسم الكامل'),
      );
    }
    if (emailStr.isEmpty || !emailReg.hasMatch(emailStr)) {
      return _showPolishedSnack(
        _t(
          'Please enter a valid email address',
          'يرجى إدخال بريد إلكتروني صحيح',
        ),
      );
    }
    if (phoneStr.isEmpty) {
      return _showPolishedSnack(
        _t('Please enter your phone number', 'يرجى إدخال رقم الهاتف'),
      );
    }

    setState(() => isLoading = true);

    String? imagePayload;
    final pickedImageBytes = _pickedImageBytes;
    if (pickedImageBytes != null && pickedImageBytes.isNotEmpty) {
      try {
        final filename =
            'profile_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        imagePayload = await ApiService().uploadProfileImage(
          pickedImageBytes,
          filename,
        );
      } catch (e) {
        if (mounted) {
          _showPolishedSnack(
            _t(
              'Profile image upload failed. Saving other changes…',
              'فشل رفع الصورة. جاري حفظ التغييرات الأخرى…',
            ),
          );
        }
        final t = profileImageUrlController.text.trim();
        imagePayload = t.isEmpty ? null : t;
      }
    } else {
      final t = profileImageUrlController.text.trim();
      imagePayload = t.isEmpty ? null : t;
    }

    final body = <String, dynamic>{
      'fullName': nameStr,
      'email': emailStr,
      'phone': phoneStr,
      'addressText': addressController.text.trim().isEmpty
          ? null
          : addressController.text.trim(),
      'profileImageUrl': imagePayload,
      'dateOfBirth': dateOfBirthController.text.trim().isEmpty
          ? null
          : dateOfBirthController.text.trim(),
      'gender': selectedGender,
      'gpsLat': _gpsLat,
      'gpsLng': _gpsLng,
    };
    try {
      await ApiService().updatePatientProfile(widget.userId, body);
      await _reloadProfileFromBackend();
      if (!mounted) return;

      // Success only: real WAV tone + haptic + animated overlay.
      // _celebrateSuccess is async but we don't block the overlay on it —
      // sound starts immediately and the overlay appears in parallel.
      unawaited(_celebrateSuccess());
      await _showSuccessOverlay();

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showPolishedSnack(
        _t(
          'Could not save your changes. Please try again.',
          'تعذر حفظ التغييرات. يرجى المحاولة مرة أخرى.',
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ─────────────────────────────── Build ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pageBackground = scheme.brightness == Brightness.dark
        ? Theme.of(context).scaffoldBackgroundColor
        : Colors.white;
    return PatientScaffold(
      enabled: false,
      backgroundColor: pageBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: BackButton(color: scheme.primary),
        centerTitle: true,
        title: Text(
          _t('Edit Profile', 'تعديل الملف الشخصي'),
          style: TextStyle(
            color: p.inkDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          CarelinkLocaleIconButton(color: scheme.primary),
          CarelinkThemeIconButton(color: scheme.primary),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _buildContent(p),
                  ),
                ),
              ),
            ),
            _buildSaveBar(p, pageBackground),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveBar(CarelinkPalette p, Color pageBackground) {
    final disabled = isLoading;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: pageBackground,
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: Material(
              color: disabled
                  ? const Color(0xFF9E9E9E)
                  : const Color(0xFF0E8A78),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: disabled ? null : saveChanges,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.save_outlined,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _t('Save Changes', 'حفظ التغييرات'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
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
    );
  }

  Widget _buildContent(CarelinkPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileHeader(p),
        const SizedBox(height: 16),

        // 1 · Personal Information
        _buildSectionCard(
          p,
          title: _t('Personal Information', 'المعلومات الشخصية'),
          children: [
            _buildTextInput(
              label: _t('Full Name', 'الاسم الكامل'),
              controller: fullNameController,
              icon: Icons.person_outline_rounded,
              placeholder: _t('Your full name', 'اسمك الكامل'),
            ),
            _buildDateAndGenderFields(),
          ],
        ),

        // 2 · Contact Information
        _buildSectionCard(
          p,
          title: _t('Contact Information', 'معلومات الاتصال'),
          children: [
            _buildTextInput(
              label: _t('Email Address', 'البريد الإلكتروني'),
              controller: emailController,
              icon: Icons.email_outlined,
              placeholder: 'you@email.com',
              keyboardType: TextInputType.emailAddress,
            ),
            _buildTextInput(
              label: _t('Phone Number', 'رقم الهاتف'),
              controller: phoneController,
              icon: Icons.phone_outlined,
              placeholder: '059xxxxxxx',
              keyboardType: TextInputType.phone,
              last: true,
            ),
          ],
        ),

        // 3 · Address / Location
        _buildLocationCard(p),
      ],
    );
  }

  // ───────────────────────────── Header ──────────────────────────────

  Widget _buildProfileHeader(CarelinkPalette p) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        GestureDetector(
          onTap: _showImageSourceSheet,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.surfaceSoft,
                  border: Border.all(color: p.surface, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(child: _avatarImage(scheme, size: 90)),
              ),
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: Material(
                  color: const Color(0xFF16A085),
                  shape: const CircleBorder(),
                  elevation: 1,
                  child: InkWell(
                    onTap: _showImageSourceSheet,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: p.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _t('Tap to change photo', 'اضغط لتغيير الصورة'),
          style: TextStyle(
            color: p.inkMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _avatarImage(ColorScheme scheme, {double size = 96}) {
    final pickedImageBytes = _pickedImageBytes;
    if (pickedImageBytes != null && pickedImageBytes.isNotEmpty) {
      return Image.memory(
        pickedImageBytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _defaultAvatar(scheme),
      );
    }
    final imageUrl = _networkProfileImageUrl();
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        headers: const {'Accept': 'image/*'},
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stack) => _defaultAvatar(scheme),
      );
    }
    return _defaultAvatar(scheme);
  }

  Widget _defaultAvatar(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.primary.withValues(alpha: 0.05),
      child: Icon(Icons.person_rounded, size: 48, color: scheme.primary),
    );
  }

  Widget _buildDateAndGenderFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildPickerInput(
            label: _t('Gender', 'الجنس'),
            value: _formatGenderForDisplay(),
            placeholder: _t('Select', 'اختر'),
            icon: Icons.wc_outlined,
            onTap: _showGenderSheet,
            last: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPickerInput(
            label: _t('Date of Birth', 'تاريخ الميلاد'),
            value: _formatDateOfBirthForDisplay(),
            placeholder: _t('Select date', 'اختر التاريخ'),
            icon: Icons.calendar_today_outlined,
            onTap: _pickDateOfBirth,
            last: true,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────── Sections ────────────────────────────

  Widget _buildSectionCard(
    CarelinkPalette p, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 12),
          Column(children: children),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label, CarelinkPalette p) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.inkMuted,
        ),
      ),
    );
  }

  Widget _buildTextInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? placeholder,
    bool last = false,
  }) {
    final p = CarelinkPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, p),
          SizedBox(
            height: 52,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              onChanged: (_) {
                if (controller == fullNameController) setState(() {});
              },
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: p.inkDark,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(
                  color: p.inkMuted.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                suffixIcon: Icon(
                  icon,
                  color: const Color(0xFF16A085),
                  size: 20,
                ),
                filled: true,
                fillColor: p.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: _border(p.surfaceSoft),
                enabledBorder: _border(p.surfaceSoft),
                focusedBorder: _border(const Color(0xFF16A085), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _buildPickerInput({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    String? placeholder,
    bool last = false,
  }) {
    final p = CarelinkPalette.of(context);
    final hasValue = value.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, p),
          Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.surfaceSoft),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasValue ? value : (placeholder ?? ''),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: hasValue
                              ? p.inkDark
                              : p.inkMuted.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: const Color(0xFF16A085), size: 20),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: p.inkMuted,
                      size: 20,
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

  Widget _buildLocationCard(CarelinkPalette p) {
    return _buildSectionCard(
      p,
      title: _t('Location', 'الموقع'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(_t('Edit Location', 'تعديل الموقع'), p),
            Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _pickLocation,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.surfaceSoft),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          addressController.text.isNotEmpty
                              ? addressController.text
                              : _t('Choose your location', 'اختر موقعك'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: addressController.text.isNotEmpty
                                ? p.inkDark
                                : p.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.map_outlined,
                        color: Color(0xFF16A085),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────────── Widgets ───────────────────────────────

class _AnimatedCheckmark extends StatefulWidget {
  const _AnimatedCheckmark({required this.color});

  final Color color;

  @override
  State<_AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<_AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.4),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
      ),
    );
  }
}

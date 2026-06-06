import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, MissingPluginException;
import 'package:image_picker/image_picker.dart';

import 'package:carelink/core/carelink_date_picker.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/profile_avatar.dart' show profileImageUrlFromMap;
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
  String? selectedBloodType;
  bool isLoading = false; // saving
  bool _loading = true; // initial profile load (skeleton)
  Uint8List? _pickedImageBytes;

  List<String> allergiesList = [];
  List<String> chronicList = [];
  List<String> medicationsList = [];

  bool get _isArabic => localeController.isArabic;
  String _t(String en, String ar) => _isArabic ? ar : en;

  bool get _isPatient =>
      (widget.userData['role'] ?? 'patient').toString() == 'patient';

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
    dateOfBirthController.text = d['dateOfBirth']?.toString() ?? '';
    selectedGender = d['gender']?.toString();
    selectedBloodType = d['bloodType']?.toString();

    allergiesList = _splitCsv(d['allergies']);
    chronicList = _splitCsv(d['chronicDiseases'] ?? d['chronicConditions']);
    medicationsList = _splitCsv(d['currentMedications']);
  }

  List<String> _splitCsv(Object? raw) => (raw?.toString() ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _initialLoad() async {
    try {
      final fresh = await ApiService().getPatientProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _populateFrom(fresh);
        _loading = false;
      });
    } catch (_) {
      // Keep the seeded values; just stop the skeleton.
      if (mounted) setState(() => _loading = false);
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
                  style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w600),
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
                  style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w600),
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

  Future<void> _showGenderSheet() async {
    final items = <MapEntry<String, String>>[
      MapEntry('male', _t('Male', 'ذكر')),
      MapEntry('female', _t('Female', 'أنثى')),
      MapEntry('other', _t('Other', 'آخر')),
      MapEntry('prefer_not_to_say', _t('Prefer not to say', 'يفضل عدم الإفصاح')),
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
                  style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w600),
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

  Future<void> _showBloodTypeSheet() async {
    const items = <String>['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    final p = CarelinkPalette.of(context);
    final colorScheme = Theme.of(context).colorScheme;
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
                _t('Blood Type', 'فصيلة الدم'),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: items.map((type) {
                  return ListTile(
                    title: Text(
                      type,
                      style: TextStyle(
                        color: p.inkDark,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    onTap: () => Navigator.pop(context, type),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (v != null) setState(() => selectedBloodType = v);
  }

  /// Bottom sheet to add a chip item (allergy / condition / medication).
  Future<void> _showAddChipSheet(String title, List<String> list) async {
    final controller = TextEditingController();
    final p = CarelinkPalette.of(context);
    final scheme = Theme.of(context).colorScheme;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _t('Add $title', 'إضافة $title'),
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => Navigator.pop(context, v.trim()),
                style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: _t('Enter value…', 'أدخل القيمة…'),
                  hintStyle: TextStyle(color: p.inkMuted.withValues(alpha: 0.55)),
                  filled: true,
                  fillColor: p.pageBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                    borderSide: BorderSide(color: scheme.primary, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: Text(
                    _t('Add', 'إضافة'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() => list.add(result));
    }
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
                _t('Profile updated successfully', 'تم تحديث الملف الشخصي بنجاح'),
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
        _t('Please enter a valid email address', 'يرجى إدخال بريد إلكتروني صحيح'),
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
        imagePayload =
            await ApiService().uploadProfileImage(pickedImageBytes, filename);
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
      'bloodType': selectedBloodType,
    };
    if (_isPatient) {
      body['chronicDiseases'] =
          chronicList.isEmpty ? null : chronicList.join(', ');
      body['allergies'] = allergiesList.isEmpty ? null : allergiesList.join(', ');
      body['currentMedications'] =
          medicationsList.isEmpty ? null : medicationsList.join(', ');
    }

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
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: const PatientTopActions(showBack: true),
      bottomNavigationBar: _buildSaveBar(p),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _loading ? _buildSkeleton(p) : _buildContent(p),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveBar(CarelinkPalette p) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = isLoading || _loading;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: disabled ? null : saveChanges,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                disabledBackgroundColor: scheme.primary.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _t('Save Changes', 'حفظ التغييرات'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          _t('Edit Profile', 'تعديل الملف الشخصي'),
          style: TextStyle(
            color: p.inkDark,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        _buildProfileHeader(p),
        const SizedBox(height: 22),

        // 1 · Personal Information
        _buildSectionCard(
          p,
          title: _t('Personal Information', 'المعلومات الشخصية'),
          icon: Icons.person_outline_rounded,
          children: [
            _buildTextInput(
              label: _t('Full Name', 'الاسم الكامل'),
              controller: fullNameController,
              icon: Icons.badge_outlined,
              placeholder: _t('Your full name', 'اسمك الكامل'),
            ),
            _buildPickerInput(
              label: _t('Date of Birth', 'تاريخ الميلاد'),
              value: dateOfBirthController.text,
              placeholder: _t('Select date', 'اختر التاريخ'),
              icon: Icons.calendar_today_outlined,
              onTap: _pickDateOfBirth,
            ),
            _buildPickerInput(
              label: _t('Gender', 'الجنس'),
              value: _formatGenderForDisplay(),
              placeholder: _t('Select gender', 'اختر الجنس'),
              icon: Icons.wc_outlined,
              onTap: _showGenderSheet,
              last: true,
            ),
          ],
        ),

        // 2 · Contact Information
        _buildSectionCard(
          p,
          title: _t('Contact Information', 'معلومات الاتصال'),
          icon: Icons.contact_phone_outlined,
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

        // 3 · Health Information
        if (_isPatient)
          _buildSectionCard(
            p,
            title: _t('Health Information', 'المعلومات الصحية'),
            icon: Icons.favorite_outline_rounded,
            children: [
              _buildPickerInput(
                label: _t('Blood Type', 'فصيلة الدم'),
                value: selectedBloodType ?? '',
                placeholder: _t('Select blood type', 'اختر فصيلة الدم'),
                icon: Icons.bloodtype_outlined,
                onTap: _showBloodTypeSheet,
              ),
              _buildChipsField(
                label: _t('Allergies', 'الحساسية'),
                items: allergiesList,
                icon: Icons.warning_amber_outlined,
                onAdd: () =>
                    _showAddChipSheet(_t('Allergy', 'حساسية'), allergiesList),
                onRemove: (i) => setState(() => allergiesList.removeAt(i)),
              ),
              _buildChipsField(
                label: _t('Chronic Conditions', 'الأمراض المزمنة'),
                items: chronicList,
                icon: Icons.healing_outlined,
                onAdd: () =>
                    _showAddChipSheet(_t('Condition', 'مرض مزمن'), chronicList),
                onRemove: (i) => setState(() => chronicList.removeAt(i)),
              ),
              _buildChipsField(
                label: _t('Current Medications', 'الأدوية الحالية'),
                items: medicationsList,
                icon: Icons.medication_outlined,
                onAdd: () => _showAddChipSheet(
                    _t('Medication', 'دواء'), medicationsList),
                onRemove: (i) => setState(() => medicationsList.removeAt(i)),
                last: true,
              ),
            ],
          ),

        // 4 · Address / Location
        _buildSectionCard(
          p,
          title: _t('Address / Location', 'العنوان / الموقع'),
          icon: Icons.location_on_outlined,
          children: [
            _buildTextInput(
              label: _t('Address', 'العنوان'),
              controller: addressController,
              icon: Icons.home_outlined,
              placeholder: _t('Enter your address', 'أدخل عنوانك'),
              maxLines: 2,
              last: true,
            ),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────── Header ──────────────────────────────

  Widget _buildProfileHeader(CarelinkPalette p) {
    final scheme = Theme.of(context).colorScheme;
    final name = fullNameController.text.trim();
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImageSourceSheet,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.surfaceSoft,
                    border: Border.all(color: scheme.primary, width: 2.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(child: _avatarImage(scheme)),
                  ),
                ),
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: Material(
                    color: scheme.primary,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      onTap: _showImageSourceSheet,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.camera_alt_rounded,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name.isEmpty ? _t('Your Profile', 'ملفك الشخصي') : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.inkDark,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _t('Personal & Health Information', 'المعلومات الشخصية والصحية'),
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarImage(ColorScheme scheme) {
    final pickedImageBytes = _pickedImageBytes;
    if (pickedImageBytes != null && pickedImageBytes.isNotEmpty) {
      return Image.memory(
        pickedImageBytes,
        width: 106,
        height: 106,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _defaultAvatar(scheme),
      );
    }
    final imageUrl = _networkProfileImageUrl();
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        width: 106,
        height: 106,
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
      color: scheme.primary.withValues(alpha: 0.10),
      child: Icon(Icons.person_rounded, size: 54, color: scheme.primary),
    );
  }

  // ───────────────────────────── Sections ────────────────────────────

  Widget _buildSectionCard(
    CarelinkPalette p, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.16 : 0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: p.inkDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String label, CarelinkPalette p) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 8 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, p),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: (_) {
              // keep header name live
              if (controller == fullNameController) setState(() {});
            },
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.inkDark,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: placeholder,
              hintStyle: TextStyle(
                color: p.inkMuted.withValues(alpha: 0.55),
                fontSize: 14,
              ),
              prefixIcon: Icon(icon, color: scheme.primary, size: 20),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              filled: true,
              fillColor: p.pageBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: _border(p.stroke),
              enabledBorder: _border(p.stroke),
              focusedBorder: _border(scheme.primary, width: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
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
    final scheme = Theme.of(context).colorScheme;
    final hasValue = value.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 8 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, p),
          Material(
            color: p.pageBg,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.stroke),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: scheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasValue ? value : (placeholder ?? ''),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: hasValue
                              ? p.inkDark
                              : p.inkMuted.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded,
                        color: scheme.primary, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsField({
    required String label,
    required List<String> items,
    required IconData icon,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
    bool last = false,
  }) {
    final p = CarelinkPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 8 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(child: _fieldLabel(label, p)),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...items.asMap().entries.map((e) {
                return Container(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(12, 7, 6, 7),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: p.isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.value,
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => onRemove(e.key),
                        customBorder: const CircleBorder(),
                        child: Icon(Icons.close_rounded,
                            size: 15, color: scheme.primary),
                      ),
                    ],
                  ),
                );
              }),
              // Add button (chip style).
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: scheme.primary, width: 1.3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: scheme.primary),
                      const SizedBox(width: 3),
                      Text(
                        _t('Add', 'إضافة'),
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── Skeleton ────────────────────────────

  Widget _buildSkeleton(CarelinkPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _Skeleton(width: 160, height: 26, radius: 8),
        const SizedBox(height: 18),
        Center(
          child: Column(
            children: [
              _Skeleton(width: 112, height: 112, radius: 56),
              const SizedBox(height: 14),
              _Skeleton(width: 140, height: 18, radius: 6),
              const SizedBox(height: 8),
              _Skeleton(width: 200, height: 12, radius: 6),
            ],
          ),
        ),
        const SizedBox(height: 22),
        for (int s = 0; s < 3; s++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Skeleton(width: 32, height: 32, radius: 10),
                    const SizedBox(width: 10),
                    _Skeleton(width: 140, height: 14, radius: 6),
                  ],
                ),
                const SizedBox(height: 16),
                for (int f = 0; f < 2; f++) ...[
                  _Skeleton(width: 90, height: 11, radius: 4),
                  const SizedBox(height: 7),
                  _Skeleton(width: double.infinity, height: 48, radius: 14),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ───────────────────────────── Widgets ───────────────────────────────

class _Skeleton extends StatefulWidget {
  const _Skeleton({
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final base = p.isDark ? Colors.white : Colors.black;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.05 + 0.05 * _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

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

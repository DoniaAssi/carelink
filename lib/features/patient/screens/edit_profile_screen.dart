import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
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
  bool isLoading = false;
  Uint8List? _pickedImageBytes;

  List<String> allergiesList = [];
  List<String> chronicList = [];
  List<String> medicationsList = [];

  bool get _isArabic => localeController.isArabic;

  String _t(String en, String ar) {
    return _isArabic ? ar : en;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.userData;
    fullNameController = TextEditingController(
      text: d['fullName']?.toString() ?? '',
    );
    emailController = TextEditingController(text: d['email']?.toString() ?? '');
    phoneController = TextEditingController(text: d['phone']?.toString() ?? '');
    addressController = TextEditingController(
      text: d['addressText']?.toString() ?? '',
    );
    profileImageUrlController = TextEditingController(
      text: profileImageUrlFromMap(Map<String, dynamic>.from(d)) ?? '',
    );
    dateOfBirthController = TextEditingController(
      text: d['dateOfBirth']?.toString() ?? '',
    );

    selectedGender = d['gender']?.toString();
    selectedBloodType = d['bloodType']?.toString();

    allergiesList = (d['allergies']?.toString() ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    chronicList =
        (d['chronicDiseases']?.toString() ??
                d['chronicConditions']?.toString() ??
                '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    medicationsList = (d['currentMedications']?.toString() ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Image size must be less than 5MB',
                'يجب أن يكون حجم الصورة أقل من 5 ميجابايت',
              ),
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Photo selected — tap Save to apply',
              'تم تحديد الصورة - اضغط حفظ للتطبيق',
            ),
          ),
        ),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Image picker needs a full app restart. Stop and run again.',
              'يحتاج منتقي الصور إلى إعادة تشغيل كاملة للتطبيق.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (kIsWeb && source == ImageSource.camera) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Camera not available. Try the gallery option.',
                'الكاميرا غير متوفرة. جرب خيار المعرض.',
              ),
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Could not pick image. Please try again.',
              'تعذر اختيار الصورة. يرجى المحاولة مرة أخرى.',
            ),
          ),
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
                _t('Gender (optional)', 'الجنس (اختياري)'),
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
    if (v != null) {
      setState(() => selectedGender = v);
    }
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
                _t('Blood Type (optional)', 'فصيلة الدم (اختياري)'),
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
    if (v != null) {
      setState(() => selectedBloodType = v);
    }
  }

  Future<void> _showAddChipDialog(String title, List<String> list) async {
    final controller = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _t('Add $title', 'إضافة $title'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _t('Enter value...', 'أدخل القيمة...'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(_t('Add', 'إضافة')),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        list.add(result);
      });
    }
  }

  Future<void> _showSuccessOverlay() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CarelinkPalette.of(context).surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _AnimatedCheckmark(),
                const SizedBox(height: 20),
                Text(
                  _t('Saved successfully!', 'تم الحفظ بنجاح!'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: CarelinkPalette.of(context).inkDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t('Your profile has been updated.', 'تم تحديث ملفك الشخصي.'),
                  style: TextStyle(
                    fontSize: 14,
                    color: CarelinkPalette.of(context).inkMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.pop(context); // Pop dialog
    }
  }

  Future<void> saveChanges() async {
    // Validation
    final nameStr = fullNameController.text.trim();
    if (nameStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Please enter your full name', 'يرجى إدخال الاسم الكامل'),
          ),
        ),
      );
      return;
    }
    final emailStr = emailController.text.trim();
    if (emailStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Please enter your email address',
              'يرجى إدخال البريد الإلكتروني',
            ),
          ),
        ),
      );
      return;
    }
    final emailReg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailReg.hasMatch(emailStr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Please enter a valid email address',
              'يرجى إدخال بريد إلكتروني صحيح',
            ),
          ),
        ),
      );
      return;
    }
    final phoneStr = phoneController.text.trim();
    if (phoneStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Please enter your phone number', 'يرجى إدخال رقم الهاتف'),
          ),
        ),
      );
      return;
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _t(
                  'Profile image upload failed. Saving other changes...',
                  'فشل رفع الصورة. جاري حفظ التغييرات الأخرى...',
                ),
              ),
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
    final isPatient =
        (widget.userData['role'] ?? 'patient').toString() == 'patient';
    if (isPatient) {
      body['chronicDiseases'] = chronicList.isEmpty
          ? null
          : chronicList.join(', ');
      body['allergies'] = allergiesList.isEmpty
          ? null
          : allergiesList.join(', ');
      body['currentMedications'] = medicationsList.isEmpty
          ? null
          : medicationsList.join(', ');
    }

    try {
      await ApiService().updatePatientProfile(widget.userId, body);
      await _reloadProfileFromBackend();

      if (!mounted) return;

      await _showSuccessOverlay();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isPatient =
        (widget.userData['role'] ?? 'patient').toString() == 'patient';
    return Scaffold(
      backgroundColor: p.pageBg,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        _t('Save Changes', 'حفظ التغييرات'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(p),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfilePhoto(p),
                        const SizedBox(height: 20),

                        // 1. Personal Information Section
                        _buildSectionHeader(
                          _t('Personal Information', 'معلومات شخصية'),
                        ),
                        _buildTextInput(
                          label: _t('Full Name', 'الاسم الكامل'),
                          controller: fullNameController,
                          icon: Icons.person_outline_rounded,
                          placeholder: _t('Your full name', 'اسمك الكامل'),
                        ),
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
                        ),
                        _buildTextInput(
                          label: _t('Address', 'العنوان'),
                          controller: addressController,
                          icon: Icons.location_on_outlined,
                          placeholder: _t('Enter your address', 'أدخل عنوانك'),
                          maxLines: 2,
                        ),

                        // 2. Medical Information Section
                        if (isPatient) ...[
                          _buildSectionHeader(
                            _t('Medical Information', 'المعلومات الطبية'),
                          ),
                          _buildPickerInput(
                            label: _t('Blood Type', 'فصيلة الدم'),
                            value: selectedBloodType ?? '',
                            placeholder: _t(
                              'Select blood type',
                              'اختر فصيلة الدم',
                            ),
                            icon: Icons.bloodtype_outlined,
                            onTap: _showBloodTypeSheet,
                            trailing: Icon(
                              Icons.expand_more,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          _buildChipsInputCard(
                            label: _t('Allergies', 'الحساسية'),
                            items: allergiesList,
                            icon: Icons.warning_amber_outlined,
                            onAddPressed: () => _showAddChipDialog(
                              _t('Allergy', 'الحساسية'),
                              allergiesList,
                            ),
                            onDeletePressed: (idx) =>
                                setState(() => allergiesList.removeAt(idx)),
                          ),
                          _buildChipsInputCard(
                            label: _t('Chronic Conditions', 'الأمراض المزمنة'),
                            items: chronicList,
                            icon: Icons.healing_outlined,
                            onAddPressed: () => _showAddChipDialog(
                              _t('Chronic Condition', 'المرض المزمن'),
                              chronicList,
                            ),
                            onDeletePressed: (idx) =>
                                setState(() => chronicList.removeAt(idx)),
                          ),
                          _buildChipsInputCard(
                            label: _t('Current Medications', 'الأدوية الحالية'),
                            items: medicationsList,
                            icon: Icons.medication_outlined,
                            onAddPressed: () => _showAddChipDialog(
                              _t('Medication', 'الدواء'),
                              medicationsList,
                            ),
                            onDeletePressed: (idx) =>
                                setState(() => medicationsList.removeAt(idx)),
                          ),
                        ],

                        // 3. Additional Information Section
                        _buildSectionHeader(
                          _t('Additional Information', 'معلومات إضافية'),
                        ),
                        _buildPickerInput(
                          label: _t('Date of Birth', 'تاريخ الميلاد'),
                          value: dateOfBirthController.text,
                          placeholder: _t('Select Date', 'اختر التاريخ'),
                          icon: Icons.calendar_today_outlined,
                          onTap: _pickDateOfBirth,
                          trailing: Icon(
                            Icons.calendar_month,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        _buildPickerInput(
                          label: _t('Gender', 'الجنس'),
                          value: _formatGenderForDisplay(),
                          placeholder: _t('Select Gender', 'اختر الجنس'),
                          icon: Icons.wc_outlined,
                          onTap: _showGenderSheet,
                          trailing: Icon(
                            Icons.expand_more,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 14),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(CarelinkPalette p) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = _networkProfileImageUrl();

    Widget image;
    final pickedImageBytes = _pickedImageBytes;
    if (pickedImageBytes != null && pickedImageBytes.isNotEmpty) {
      image = Image.memory(
        pickedImageBytes,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _defaultAvatar(colorScheme),
      );
    } else if (imageUrl != null) {
      image = Image.network(
        imageUrl,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        headers: const {'Accept': 'image/*'},
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            _defaultAvatar(colorScheme),
      );
    } else {
      image = _defaultAvatar(colorScheme);
    }

    return Center(
      child: GestureDetector(
        onTap: _showImageSourceSheet,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.surfaceSoft,
                border: Border.all(color: p.stroke, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipOval(child: image),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: colorScheme.primary,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  onTap: _showImageSourceSheet,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(ColorScheme colorScheme) {
    return ColoredBox(
      color: colorScheme.primary.withValues(alpha: 0.10),
      child: Icon(Icons.person_rounded, size: 52, color: colorScheme.primary),
    );
  }

  Widget _buildTextInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? placeholder,
  }) {
    final p = CarelinkPalette.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, p),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: maxLines == 1 ? 52 : 96),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: p.inkDark,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(
                  color: p.inkMuted.withValues(alpha: 0.55),
                  fontSize: 14,
                ),
                prefixIcon: Icon(icon, color: colorScheme.primary, size: 20),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 46,
                  minHeight: 46,
                ),
                filled: true,
                fillColor: p.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
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
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerInput({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required Widget trailing,
    String? placeholder,
  }) {
    final p = CarelinkPalette.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final hasValue = value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, p),
          const SizedBox(height: 6),
          Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 12, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.stroke),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: colorScheme.primary, size: 20),
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
                    trailing,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label, CarelinkPalette p) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: p.inkMuted,
      ),
    );
  }

  Widget _buildChipsInputCard({
    required String label,
    required List<String> items,
    required IconData icon,
    required VoidCallback onAddPressed,
    required Function(int) onDeletePressed,
  }) {
    final p = CarelinkPalette.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, p),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.stroke),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Icon(icon, color: colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            _t('None added', 'لا يوجد'),
                            style: TextStyle(
                              color: p.inkMuted.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final val = entry.value;
                            return InputChip(
                              label: Text(
                                val,
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: colorScheme.primary.withValues(
                                alpha: p.isDark ? 0.18 : 0.08,
                              ),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              deleteIcon: Icon(
                                Icons.close,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              onDeleted: () => onDeletePressed(idx),
                            );
                          }).toList(),
                        ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.add_circle, color: colorScheme.primary),
                  onPressed: onAddPressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(CarelinkPalette p) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _t('Edit Profile', 'تعديل الملف الشخصي'),
              style: TextStyle(
                color: p.inkDark,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          CarelinkLocaleIconButton(color: primaryColor),
          CarelinkThemeIconButton(color: primaryColor),
        ],
      ),
    );
  }
}

class _AnimatedCheckmark extends StatefulWidget {
  const _AnimatedCheckmark();

  @override
  State<_AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<_AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:image_picker/image_picker.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_date_picker.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder, profileImageUrlFromMap;
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

const Color _kTealDeep = AppColors.primary;
const Color _kLabelMuted = Color(0xFF6B8A84);

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
  late TextEditingController gpsLatController;
  late TextEditingController gpsLngController;
  late TextEditingController chronicDiseasesController;
  late TextEditingController allergiesController;
  late TextEditingController currentMedicationsController;

  String? selectedGender;
  bool isLoading = false;
  Uint8List? _pickedImageBytes;

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
    final lat = d['gpsLat'];
    final lng = d['gpsLng'];
    gpsLatController = TextEditingController(
      text: lat != null && lat.toString() != 'null' ? lat.toString() : '',
    );
    gpsLngController = TextEditingController(
      text: lng != null && lng.toString() != 'null' ? lng.toString() : '',
    );
    chronicDiseasesController = TextEditingController(
      text: d['chronicDiseases']?.toString() ?? '',
    );
    allergiesController = TextEditingController(
      text: d['allergies']?.toString() ?? '',
    );
    currentMedicationsController = TextEditingController(
      text: d['currentMedications']?.toString() ?? '',
    );
    selectedGender = d['gender']?.toString();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    profileImageUrlController.dispose();
    dateOfBirthController.dispose();
    gpsLatController.dispose();
    gpsLngController.dispose();
    chronicDiseasesController.dispose();
    allergiesController.dispose();
    currentMedicationsController.dispose();
    super.dispose();
  }

  String _formatGenderForDisplay() {
    switch (selectedGender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return '';
    }
  }

  String _locationRowValue() {
    final l = gpsLatController.text.trim();
    final g = gpsLngController.text.trim();
    if (l.isNotEmpty && g.isNotEmpty) {
      return '$l, $g';
    }
    final a = addressController.text.trim();
    if (a.isNotEmpty) return a;
    return '';
  }

  String _profilePhotoRowValue() {
    if (_pickedImageBytes != null) {
      return 'New photo — tap Save to apply';
    }
    final t = profileImageUrlController.text.trim();
    if (t.isEmpty) return '';
    if (t.startsWith('data:image')) {
      return 'Photo on your account';
    }
    if (t.startsWith('http://') || t.startsWith('https://')) {
      return 'Photo from your account';
    }
    return 'Photo on your account';
  }

  void _clearProfilePhoto() {
    setState(() {
      _pickedImageBytes = null;
      profileImageUrlController.clear();
    });
  }

  Future<void> _showTextEditDialog({
    required String title,
    required TextEditingController controller,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) async {
    final t = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: controller.text);
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            title,
            style: const TextStyle(
              color: _kTealDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLines: maxLines,
            style: const TextStyle(
              color: _kTealDeep,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            keyboardType: maxLines > 1
                ? TextInputType.multiline
                : (title.contains('Phone')
                    ? TextInputType.phone
                    : TextInputType.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _kLabelMuted),
              ),
            ),
            TextButton(
              onPressed: () {
                if (validator != null) {
                  final err = validator(c.text);
                  if (err != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err)));
                    return;
                  }
                }
                Navigator.pop(ctx, c.text);
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: _kTealDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (t != null) {
      controller.text = t;
      setState(() {});
    }
  }

  Future<void> _openLocationDialog() async {
    final la = TextEditingController(text: gpsLatController.text);
    final lo = TextEditingController(text: gpsLngController.text);
    final ad = TextEditingController(text: addressController.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Location',
          style: TextStyle(color: _kTealDeep, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Address',
                style: TextStyle(fontSize: 12, color: _kLabelMuted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: ad,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Latitude',
                style: TextStyle(fontSize: 12, color: _kLabelMuted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: la,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Longitude',
                style: TextStyle(fontSize: 12, color: _kLabelMuted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: lo,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _kLabelMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'OK',
              style: TextStyle(color: _kTealDeep, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      addressController.text = ad.text.trim();
      gpsLatController.text = la.text.trim();
      gpsLngController.text = lo.text.trim();
      setState(() {});
    }
  }

  Future<void> _showImageSourceSheet() async {
    final p = CarelinkPalette.of(context);
    final hasExisting = _pickedImageBytes != null ||
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
                  'Profile photo',
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
                  color: AppColors.primary,
                ),
                title: Text(
                  'Choose from gallery',
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () =>
                    Navigator.pop(context, _PhotoSheetAction.gallery),
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
                title: Text(
                  'Take a photo',
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
                    'Remove photo',
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
        maxWidth: 1080,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedImageBytes = bytes;
        if (profileImageUrlController.text.trim().isNotEmpty) {
          profileImageUrlController.clear();
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo selected — tap Save to apply')),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image picker needs a full app restart. Stop and run again.',
          ),
        ),
      );
    } catch (_) {
      if (kIsWeb && source == ImageSource.camera) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera not available. Try the gallery option.'),
          ),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not pick image. Please try again.'),
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
    const items = <MapEntry<String, String>>[
      MapEntry('male', 'Male'),
      MapEntry('female', 'Female'),
      MapEntry('other', 'Other'),
      MapEntry('prefer_not_to_say', 'Prefer not to say'),
    ];
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Gender (optional)',
                style: TextStyle(
                  color: _kTealDeep,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final e in items)
              ListTile(
                title: Text(e.value, style: const TextStyle(color: _kTealDeep)),
                onTap: () => Navigator.pop(context, e.key),
              ),
          ],
        ),
      ),
    );
    if (v != null) {
      setState(() => selectedGender = v);
    }
  }

  double? _parseGps(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> saveChanges() async {
    if (fullNameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => isLoading = true);

    String? imagePayload;
    if (_pickedImageBytes != null && _pickedImageBytes!.isNotEmpty) {
      imagePayload =
          'data:image/jpeg;base64,${base64Encode(_pickedImageBytes!)}';
    } else {
      final t = profileImageUrlController.text.trim();
      imagePayload = t.isEmpty ? null : t;
    }

    final lat = _parseGps(gpsLatController.text);
    final lng = _parseGps(gpsLngController.text);
    final body = <String, dynamic>{
      'fullName': fullNameController.text.trim(),
      'email': emailController.text.trim(),
      'phone': phoneController.text.trim(),
      'addressText': addressController.text.trim().isEmpty
          ? null
          : addressController.text.trim(),
      'profileImageUrl': imagePayload,
      'dateOfBirth': dateOfBirthController.text.trim().isEmpty
          ? null
          : dateOfBirthController.text.trim(),
      'gender': selectedGender,
    };
    if (lat != null) body['gpsLat'] = lat;
    if (lng != null) body['gpsLng'] = lng;

    final isPatient =
        (widget.userData['role'] ?? 'patient').toString() == 'patient';
    if (isPatient) {
      body['chronicDiseases'] = chronicDiseasesController.text.trim().isEmpty
          ? null
          : chronicDiseasesController.text.trim();
      body['allergies'] = allergiesController.text.trim().isEmpty
          ? null
          : allergiesController.text.trim();
      body['currentMedications'] =
          currentMedicationsController.text.trim().isEmpty
              ? null
              : currentMedicationsController.text.trim();
    }
    if (lat == null && gpsLatController.text.trim().isNotEmpty) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid latitude number')),
        );
      }
      return;
    }
    if (lng == null && gpsLngController.text.trim().isNotEmpty) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid longitude number'),
          ),
        );
      }
      return;
    }

    try {
      await ApiService().updatePatientProfile(widget.userId, body);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      Navigator.pop(context, true);
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
    final isPatient =
        (widget.userData['role'] ?? 'patient').toString() == 'patient';
    return Scaffold(
      backgroundColor: p.pageBg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildHeader(p),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              child: Column(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _showImageSourceSheet,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.surfaceSoft,
                              border: Border.all(color: p.surface, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.07),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: profileAvatarOrPlaceholder(
                                imageUrl: profileImageUrlController.text,
                                localBytes: _pickedImageBytes,
                                size: 100,
                                placeholderColor: AppColors.primary,
                                placeholderIcon: Icons.person,
                                iconSize: 48,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Material(
                              color: AppColors.primary,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                onTap: _showImageSourceSheet,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.stroke),
                      boxShadow: [_cardShadow(p)],
                    ),
                    child: Column(
                      children: [
                        _ProfileInfoRow(
                          label: 'Full Name',
                          value: fullNameController.text.trim().isNotEmpty
                              ? fullNameController.text.trim()
                              : null,
                          placeholder: 'Your full name',
                          icon: Icons.person_outline,
                          trailing: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onTap: () => _showTextEditDialog(
                            title: 'Full Name',
                            controller: fullNameController,
                          ),
                        ),
                        const _RowDivider(),
                        _ProfileInfoRow(
                          label: 'Email Address',
                          value: emailController.text.trim().isNotEmpty
                              ? emailController.text.trim()
                              : null,
                          placeholder: 'you@email.com',
                          icon: Icons.email_outlined,
                          trailing: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onTap: () => _showTextEditDialog(
                            title: 'Email',
                            controller: emailController,
                          ),
                        ),
                        const _RowDivider(),
                        _ProfileInfoRow(
                          label: 'Phone Number',
                          value: phoneController.text.trim().isNotEmpty
                              ? phoneController.text.trim()
                              : null,
                          placeholder: 'Phone number',
                          icon: Icons.phone_outlined,
                          trailing: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onTap: () => _showTextEditDialog(
                            title: 'Phone Number',
                            controller: phoneController,
                          ),
                        ),
                        const _RowDivider(),
                        _ProfileInfoRow(
                          label: 'Location (Latitude, Longitude)',
                          value: _locationRowValue().isNotEmpty
                              ? _locationRowValue()
                              : null,
                          placeholder: 'Set location or address',
                          icon: Icons.location_on_outlined,
                          trailing: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onTap: _openLocationDialog,
                        ),
                        const _RowDivider(),
                        _ProfileInfoRow(
                          label: 'Profile photo (optional)',
                          value: _profilePhotoRowValue().isNotEmpty
                              ? _profilePhotoRowValue()
                              : null,
                          placeholder: 'Gallery or camera',
                          icon: Icons.add_a_photo_outlined,
                          trailing: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onTap: _showImageSourceSheet,
                        ),
                        const _RowDivider(),
                        _ProfileInfoRow(
                          label: 'Date of Birth (optional)',
                          value: dateOfBirthController.text.trim().isNotEmpty
                              ? dateOfBirthController.text.trim()
                              : null,
                          placeholder: 'Select date of birth',
                          icon: Icons.calendar_today,
                          trailing: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onTap: _pickDateOfBirth,
                        ),
                        const _RowDivider(),
                        _ProfileInfoRow(
                          label: 'Gender (optional)',
                          value: _formatGenderForDisplay().isNotEmpty
                              ? _formatGenderForDisplay()
                              : null,
                          placeholder: 'Select gender',
                          icon: Icons.group,
                          trailing: const Icon(
                            Icons.expand_more,
                            size: 24,
                            color: AppColors.primary,
                          ),
                          onTap: _showGenderSheet,
                        ),
                        if (isPatient) ...[
                          const _RowDivider(),
                          _ProfileInfoRow(
                            label: 'Chronic conditions (baseline)',
                            value: chronicDiseasesController.text
                                    .trim()
                                    .isNotEmpty
                                ? chronicDiseasesController.text.trim()
                                : null,
                            placeholder: 'Optional — list ongoing conditions',
                            icon: Icons.healing_outlined,
                            trailing: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            onTap: () => _showTextEditDialog(
                              title: 'Chronic conditions',
                              controller: chronicDiseasesController,
                              maxLines: 6,
                            ),
                          ),
                          const _RowDivider(),
                          _ProfileInfoRow(
                            label: 'Allergies (baseline)',
                            value: allergiesController.text.trim().isNotEmpty
                                ? allergiesController.text.trim()
                                : null,
                            placeholder: 'Optional — drugs, food, etc.',
                            icon: Icons.warning_amber_outlined,
                            trailing: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            onTap: () => _showTextEditDialog(
                              title: 'Allergies',
                              controller: allergiesController,
                              maxLines: 5,
                            ),
                          ),
                          const _RowDivider(),
                          _ProfileInfoRow(
                            label: 'Current medications (baseline)',
                            value: currentMedicationsController.text
                                    .trim()
                                    .isNotEmpty
                                ? currentMedicationsController.text.trim()
                                : null,
                            placeholder: 'Optional — names & doses if known',
                            icon: Icons.medication_outlined,
                            trailing: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            onTap: () => _showTextEditDialog(
                              title: 'Current medications',
                              controller: currentMedicationsController,
                              maxLines: 6,
                            ),
                          ),
                        ],
                        const _RowDivider(),
                        _ProfileInfoRow(
                          label: 'Account Type',
                          value: (widget.userData['role'] ?? 'patient')
                              .toString()
                              .toUpperCase(),
                          icon: Icons.admin_panel_settings,
                          placeholder: '—',
                          trailing: const Icon(
                            Icons.verified_user,
                            size: 22,
                            color: AppColors.primary,
                          ),
                          onTap: null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isLoading ? null : saveChanges,
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
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_outlined, size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
        boxShadow: [_cardShadow(p)],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.stroke),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: p.inkDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CarelinkBrandLogo(
            height: 28,
            fallbackTextColor: p.inkDark,
            forceDarkLogo: p.isDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Edit Profile',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.inkDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.stroke),
            ),
            child: CarelinkThemeIconButton(color: p.inkDark),
          ),
        ],
      ),
    );
  }

  BoxShadow _cardShadow(CarelinkPalette p) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: p.isDark ? 0.22 : 0.045),
      blurRadius: 16,
      offset: const Offset(0, 8),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Divider(height: 1, thickness: 1, color: p.stroke, indent: 72);
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.label,
    required this.icon,
    this.value,
    this.placeholder,
    this.trailing,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final String? value;
  final String? placeholder;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final has = value != null && value!.trim().isNotEmpty;
    final v = has ? value!.trim() : (placeholder ?? '');
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: p.isDark ? 0.16 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: p.inkMuted,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  v,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: has
                        ? AppColors.primary
                        : p.inkMuted.withValues(alpha: 0.75),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: row,
      ),
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/auth/login_screen.dart';
import 'package:carelink/shared/models/provider_profile.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/provider_profile_service.dart';

import 'nurse_notifications_screen.dart';
import 'nurse_ui.dart';

class NurseProfile extends StatefulWidget {
  const NurseProfile({super.key, required this.user});

  final User user;

  @override
  State<NurseProfile> createState() => _NurseProfileState();
}

class _NurseProfileState extends State<NurseProfile> {
  ProviderProfile? profile;
  bool isLoading = true;
  bool isSaving = false;
  bool isUploadingPhoto = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final loaded = await ProviderProfileService.getProfile(
        widget.user.userId,
      );
      if (!mounted) return;
      setState(() {
        profile = loaded;
        error = loaded == null ? 'Unable to load nurse profile' : null;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive((context) {
      final palette = CarelinkPalette.of(context);
      return Scaffold(
        backgroundColor: palette.pageBg,
        appBar: AppBar(
          title: Text(NurseUi.t('Nurse Profile')),
          centerTitle: true,
          backgroundColor: palette.pageBg,
          foregroundColor: palette.inkDark,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Edit profile',
              onPressed: profile == null ? null : () => _openEditProfile(),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadProfile,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? _errorState(palette)
              : _profileBody(profile!, palette),
        ),
      );
    });
  }

  Widget _profileBody(ProviderProfile p, CarelinkPalette palette) {
    return SafeArea(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroSection(p, palette),
                  if (!p.canWork) ...[
                    const SizedBox(height: 12),
                    _lockedBanner(p, palette),
                  ],
                  const SizedBox(height: 12),
                  _profileDetailsCard(p, palette),
                  const SizedBox(height: 12),
                  _professionalCard(p, palette),
                  const SizedBox(height: 12),
                  _documentsCard(p, palette),
                  const SizedBox(height: 12),
                  _actionList(palette),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroSection(ProviderProfile p, CarelinkPalette palette) {
    final name = _fallback(p.fullName, widget.user.fullName);
    return Column(
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surfaceSoft,
                  border: Border.all(color: palette.surface, width: 3),
                  boxShadow: NurseUi.softShadow,
                ),
                child: ClipOval(
                  child: _profileAvatarImage(p, name, palette, size: 104),
                ),
              ),
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  elevation: 1,
                  child: InkWell(
                    onTap: isUploadingPhoto ? null : _showProfilePhotoSheet,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.surface, width: 2),
                      ),
                      child: isUploadingPhoto
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
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
        const SizedBox(height: 8),
        Text(
          'Tap to change photo',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.inkMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.inkDark,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _profileChip(_fallback(p.specialization, 'Nurse')),
            if (p.serviceAreas.trim().isNotEmpty)
              _profileChip(
                _fallback(p.serviceAreas, 'Location not provided'),
                icon: Icons.location_on_outlined,
              ),
            if (p.rating > 0)
              _profileChip(
                p.rating.toStringAsFixed(1),
                icon: Icons.star_rounded,
              ),
          ],
        ),
        if (p.email.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            p.email,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.inkMuted, fontSize: 14),
          ),
        ],
      ],
    );
  }

  Widget _profileDetailsCard(ProviderProfile p, CarelinkPalette palette) {
    final rows = <_ProfileRow>[
      _ProfileRow(
        Icons.badge_outlined,
        'Full name',
        _fallback(p.fullName, 'Not provided'),
      ),
      _ProfileRow(
        Icons.email_outlined,
        'Email',
        _fallback(p.email, 'Not provided'),
      ),
      _ProfileRow(
        Icons.phone_outlined,
        'Phone',
        _fallback(p.phone, 'Not provided'),
      ),
      _ProfileRow(
        Icons.verified_user_outlined,
        'Approval status',
        _statusLabel(p.approvalStatus),
      ),
    ];
    return _sectionCard(palette: palette, title: 'Profile details', rows: rows);
  }

  Widget _professionalCard(ProviderProfile p, CarelinkPalette palette) {
    final rows = <_ProfileRow>[
      _ProfileRow(
        Icons.work_history_outlined,
        'Years of experience',
        '${p.experienceYears} years',
      ),
      _ProfileRow(
        Icons.location_on_outlined,
        'Location / Service area',
        _fallback(p.serviceAreas, 'Not provided'),
      ),
      _ProfileRow(
        Icons.payments_outlined,
        'Hourly rate',
        p.hourlyRate > 0
            ? '${_formatMoney(p.hourlyRate)} ILS'
            : 'Waiting for admin',
      ),
      _ProfileRow(
        Icons.info_outline_rounded,
        'Biography',
        _fallback(p.bio, 'No biography provided yet.'),
      ),
    ];
    return _sectionCard(
      palette: palette,
      title: 'Professional information',
      rows: rows,
    );
  }

  Widget _documentsCard(ProviderProfile p, CarelinkPalette palette) {
    final certs = p.certifications
        .map((cert) => cert.trim())
        .where((cert) => cert.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(palette),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Certificates & documents',
            style: TextStyle(
              color: palette.inkDark,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _documentTile(
            title: 'Nursing License',
            subtitle: 'PDF / Image',
            url: p.nursingLicenseUrl,
            icon: Icons.badge_outlined,
            palette: palette,
          ),
          _thinDivider(palette),
          _documentTile(
            title: 'Medical Certificate',
            subtitle: 'PDF / Image',
            url: p.medicalCertificateUrl,
            icon: Icons.medical_information_outlined,
            palette: palette,
          ),
          _thinDivider(palette),
          _documentTile(
            title: 'ID Card',
            subtitle: 'PDF / Image',
            url: p.idCardUrl,
            icon: Icons.credit_card_rounded,
            palette: palette,
          ),
          _thinDivider(palette),
          _documentTile(
            title: 'CV File',
            subtitle: 'PDF / Image',
            url: p.cvFileUrl,
            icon: Icons.description_outlined,
            palette: palette,
          ),
          if (certs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Verified certificates',
              style: TextStyle(
                color: palette.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: certs
                  .map(
                    (cert) => _smallStatusChip(
                      cert,
                      Icons.verified_rounded,
                      const Color(0xFF0F766E),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionList(CarelinkPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Account & Settings',
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          decoration: _cardDecoration(palette),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                _actionTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit profile',
                  onTap: _openEditProfile,
                  palette: palette,
                ),
                _listDivider(palette),
                _actionTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  onTap: _openNotifications,
                  palette: palette,
                ),
                _listDivider(palette),
                _actionTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  onTap: _confirmLogout,
                  palette: palette,
                  iconColor: Colors.red.shade400,
                  textColor: Colors.red.shade400,
                  showChevron: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required CarelinkPalette palette,
    required String title,
    required List<_ProfileRow> rows,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(palette),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.inkDark,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < rows.length; i++) ...[
            _detailRow(rows[i], palette),
            if (i != rows.length - 1) _thinDivider(palette),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(_ProfileRow row, CarelinkPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(row.icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: TextStyle(
                  color: palette.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                row.value,
                style: TextStyle(
                  color: palette.inkDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _documentTile({
    required String title,
    required String subtitle,
    required String url,
    required IconData icon,
    required CarelinkPalette palette,
  }) {
    final available = url.trim().isNotEmpty;
    return InkWell(
      onTap: available ? () => _showDocumentPreview(title, url) : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (available ? AppColors.primary : palette.inkMuted)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: available ? AppColors.primary : palette.inkMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: available ? palette.inkDark : palette.inkMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    available ? subtitle : 'Not uploaded',
                    style: TextStyle(color: palette.inkMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              available
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.lock_outline_rounded,
              size: available ? 14 : 18,
              color: palette.inkMuted.withValues(alpha: 0.65),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required CarelinkPalette palette,
    Color? iconColor,
    Color? textColor,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor ?? palette.inkDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (showChevron)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: palette.inkMuted.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }

  Widget _lockedBanner(ProviderProfile p, CarelinkPalette palette) {
    final approval = p.approvalStatus.toLowerCase();
    final message = approval == 'approved'
        ? _fallback(
            p.workGateMessage,
            'Please accept your admin-set hourly rate before starting work.',
          )
        : 'Waiting for Admin Approval';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC46B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, color: Color(0xFFB54708)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7A3E00),
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfilePhotoSheet() async {
    final current = profile;
    if (current == null) return;
    final palette = CarelinkPalette.of(context);
    final hasExisting = current.profileImageUrl.trim().isNotEmpty;

    final choice = await showModalBottomSheet<_PhotoSheetAction>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.stroke,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Text(
                  'Profile Photo',
                  style: TextStyle(
                    color: palette.inkDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: Text(
                  'Choose from gallery',
                  style: TextStyle(
                    color: palette.inkDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(context, _PhotoSheetAction.gallery),
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
                title: Text(
                  'Take a photo',
                  style: TextStyle(
                    color: palette.inkDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(context, _PhotoSheetAction.camera),
              ),
              if (hasExisting)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: palette.inkMuted),
                  title: Text(
                    'Remove photo',
                    style: TextStyle(
                      color: palette.inkMuted,
                      fontWeight: FontWeight.w700,
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
        break;
      case _PhotoSheetAction.camera:
        await _pickProfileImage(ImageSource.camera);
        break;
      case _PhotoSheetAction.remove:
        await _saveProfilePhoto('');
        break;
      case null:
        break;
    }
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _showSnack('Image size must be less than 5MB', error: true);
        return;
      }
      final payload =
          'data:${_imageMimeType(file)};base64,${base64Encode(bytes)}';
      await _saveProfilePhoto(payload);
    } on MissingPluginException {
      _showSnack(
        'Image picker needs a full app restart. Stop and run again.',
        error: true,
      );
    } catch (_) {
      _showSnack('Unable to select photo. Please try again.', error: true);
    }
  }

  Future<void> _saveProfilePhoto(String imagePayload) async {
    final current = profile;
    if (current == null || isUploadingPhoto) return;
    final updated = ProviderProfile.fromJson({
      ...current.toJson(),
      'profileImageUrl': imagePayload,
    });

    setState(() => isUploadingPhoto = true);
    final ok = await ProviderProfileService.updateProfile(updated);
    if (!mounted) return;
    setState(() {
      isUploadingPhoto = false;
      if (ok) profile = updated;
    });
    _showSnack(
      ok
          ? imagePayload.isEmpty
                ? 'Profile photo removed'
                : 'Profile photo updated'
          : 'Failed to update profile photo',
      error: !ok,
    );
    if (ok) await _loadProfile();
  }

  Future<void> _openEditProfile() async {
    final current = profile;
    if (current == null || isSaving) return;
    final nameController = TextEditingController(text: current.fullName);
    final phoneController = TextEditingController(text: current.phone);
    final areaController = TextEditingController(text: current.serviceAreas);
    final experienceController = TextEditingController(
      text: current.experienceYears > 0
          ? current.experienceYears.toString()
          : '',
    );
    final bioController = TextEditingController(text: current.bio);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final palette = CarelinkPalette.of(context);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Edit profile',
                            style: TextStyle(
                              color: palette.inkDark,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _editField(
                      controller: nameController,
                      label: 'Full name',
                      icon: Icons.badge_outlined,
                    ),
                    _editField(
                      controller: phoneController,
                      label: 'Phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    _editField(
                      controller: areaController,
                      label: 'Location / Service area',
                      icon: Icons.location_on_outlined,
                    ),
                    _editField(
                      controller: experienceController,
                      label: 'Years of experience',
                      icon: Icons.work_history_outlined,
                      keyboardType: TextInputType.number,
                      helperText:
                          'You can update your nursing experience here.',
                    ),
                    _editField(
                      controller: bioController,
                      label: 'Biography',
                      icon: Icons.info_outline_rounded,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save changes'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (saved != true) return;
    final experienceYears =
        int.tryParse(experienceController.text.trim()) ??
        current.experienceYears;
    final updated = ProviderProfile.fromJson({
      ...current.toJson(),
      'fullName': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'serviceAreas': areaController.text.trim(),
      'bio': bioController.text.trim(),
      'experienceYears': experienceYears < 0 ? 0 : experienceYears,
      'profileImageUrl': current.profileImageUrl,
    });

    setState(() => isSaving = true);
    final ok = await ProviderProfileService.updateProfile(updated);
    if (!mounted) return;
    setState(() => isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Profile updated successfully' : 'Failed to update profile',
        ),
        backgroundColor: ok ? AppColors.success : Colors.red.shade700,
      ),
    );
    if (ok) await _loadProfile();
  }

  Widget _editField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon, color: AppColors.primary),
          filled: true,
          fillColor: const Color(0xFFF7FBFA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFD7ECE9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFD7ECE9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }

  Future<void> _showDocumentPreview(String title, String rawUrl) async {
    final url = _absoluteUrl(rawUrl);
    final isImage = RegExp(
      r'\.(png|jpe?g|gif|webp)(\?.*)?$',
      caseSensitive: false,
    ).hasMatch(url);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final palette = CarelinkPalette.of(context);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: palette.inkDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isImage)
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InteractiveViewer(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              _previewFallback(palette),
                        ),
                      ),
                    ),
                  )
                else
                  _pdfPreviewCard(palette),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openExternal(url),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open file'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pdfPreviewCard(CarelinkPalette palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.stroke),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.picture_as_pdf_rounded,
            color: AppColors.primary,
            size: 54,
          ),
          const SizedBox(height: 12),
          Text(
            'PDF document',
            style: TextStyle(
              color: palette.inkDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Open the file to view the full document.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _previewFallback(CarelinkPalette palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: palette.surfaceSoft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: palette.inkMuted, size: 44),
          const SizedBox(height: 10),
          Text(
            'Unable to preview this file',
            style: TextStyle(color: palette.inkDark),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _absoluteUrl(String raw) {
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return '${ApiService.baseUrl}$value';
    return '${ApiService.baseUrl}/$value';
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NurseNotificationsScreen(user: widget.user),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(NurseUi.t('Logout')),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    const exactKeys = <String>{
      'session_user_id',
      'session_display_name',
      'auth_token',
      'access_token',
      'refresh_token',
      'token',
      'user',
      'user_data',
      'current_user',
      'doctor_token',
      'doctor_userId',
      'doctor_fullName',
      'doctor_email',
      'doctor_role',
    };
    final keysToRemove = prefs.getKeys().where((key) {
      final lower = key.toLowerCase();
      return exactKeys.contains(key) ||
          lower.startsWith('session_') ||
          lower.contains('auth_token') ||
          lower.contains('access_token') ||
          lower.contains('refresh_token');
    }).toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _errorState(CarelinkPalette palette) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFB42318),
          size: 48,
        ),
        const SizedBox(height: 14),
        Text(
          error ?? 'Unable to load nurse profile',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.inkDark, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _loadProfile,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _profileAvatarImage(
    ProviderProfile p,
    String name,
    CarelinkPalette palette, {
    required double size,
  }) {
    final bytes = _dataImageBytes(p.profileImageUrl);
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultAvatar(name, palette),
      );
    }

    final imageUrl = _networkImageUrl(p.profileImageUrl);
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
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _defaultAvatar(name, palette),
      );
    }

    return _defaultAvatar(name, palette);
  }

  Widget _defaultAvatar(String name, CarelinkPalette palette) {
    return ColoredBox(
      color: palette.surfaceSoft,
      child: Center(
        child: Text(
          _initial(name),
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Uint8List? _dataImageBytes(String raw) {
    final value = raw.trim();
    if (!value.toLowerCase().startsWith('data:image')) return null;
    final comma = value.indexOf(',');
    if (comma == -1) return null;
    try {
      return base64Decode(value.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  String? _networkImageUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty || value.toLowerCase().startsWith('data:image')) {
      return null;
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      final separator = value.startsWith('/') ? '' : '/';
      value = '${ApiService.baseUrl}$separator$value';
    }
    return value.startsWith('http://') || value.startsWith('https://')
        ? value
        : null;
  }

  String _imageMimeType(XFile file) {
    final mime = file.mimeType?.trim();
    if (mime != null && mime.startsWith('image/')) return mime;
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : AppColors.success,
      ),
    );
  }

  Widget _profileChip(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.amber.shade700),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallStatusChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(CarelinkPalette palette) {
    return NurseUi.cardDecoration();
  }

  Widget _thinDivider(CarelinkPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: palette.stroke,
        indent: 32,
      ),
    );
  }

  Widget _listDivider(CarelinkPalette palette) {
    return Divider(height: 1, thickness: 1, color: palette.stroke, indent: 52);
  }

  String _fallback(String value, String fallback) {
    final text = value.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  String _initial(String name) {
    final clean = name.trim();
    return clean.isEmpty ? 'N' : clean[0].toUpperCase();
  }

  String _statusLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'approved') return 'Approved';
    if (normalized == 'rejected') return 'Rejected';
    if (normalized == 'inactive') return 'Inactive';
    return 'Pending approval';
  }

  String _formatMoney(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}

class _ProfileRow {
  const _ProfileRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

enum _PhotoSheetAction { gallery, camera, remove }



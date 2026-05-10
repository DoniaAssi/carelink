import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/post_auth_navigation.dart';
import 'package:carelink/features/auth/registration/getx/widgets/custom_text_field.dart';
import 'package:carelink/shared/models/user.dart';

/// Post-signup step for nurses & doctors (license, specialization, certificate).
class ProfessionalProfileCompletionScreen extends StatefulWidget {
  const ProfessionalProfileCompletionScreen({super.key, required this.user});

  final User user;

  @override
  State<ProfessionalProfileCompletionScreen> createState() =>
      _ProfessionalProfileCompletionScreenState();
}

class _ProfessionalProfileCompletionScreenState
    extends State<ProfessionalProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseCtrl = TextEditingController();
  XFile? _certificateFile;
  String? _specialization;
  bool _uploading = false;

  static const List<String> _specializations = [
    'General practice',
    'Family medicine',
    'Internal medicine',
    'Emergency & critical care',
    'Cardiology',
    'Pediatrics',
    'Surgery',
    'Orthopedics',
    'Neurology',
    'Psychiatry & mental health',
    'Obstetrics & gynecology',
    'Oncology',
    'Dermatology',
    'Anesthesiology',
    'Radiology',
    'Nursing (general)',
    'Nursing (ICU)',
    'Other',
  ];

  @override
  void dispose() {
    _licenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCertificate() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (x != null) setState(() => _certificateFile = x);
  }

  Future<void> _continue() async {
    final loc = context;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_specialization == null || _specialization!.isEmpty) {
      ScaffoldMessenger.of(loc).showSnackBar(
        SnackBar(content: Text(loc.tr('auth.professionalSelectSpecialization'))),
      );
      return;
    }
    if (_certificateFile == null) {
      ScaffoldMessenger.of(loc).showSnackBar(
        SnackBar(content: Text(loc.tr('auth.professionalAttachCertificate'))),
      );
      return;
    }
    setState(() => _uploading = true);

    // TODO: multipart POST e.g. `/api/providers/complete-profile` with
    // user id, license, specialization, and certificate bytes.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _uploading = false);

    navigateCarelinkHomeForUserMap(widget.user.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final u = widget.user;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: p.pageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(22, topInset + 18, 22, 26),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('auth.professionalProfileTitle'),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  u.fullName.isNotEmpty ? u.fullName : context.tr('auth.signUp'),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: p.isDark
                          ? const Color(0xFF123640).withValues(alpha: 0.55)
                          : const Color(0xFFE8F5F2),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: AppColors.primary,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.tr(
                                  'auth.professionalVerificationBanner',
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                  color: p.inkDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    CustomTextField(
                      controller: _licenseCtrl,
                      hintText: context.tr('auth.professionalLicenseHint'),
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 3) {
                          return context.tr('auth.professionalLicenseInvalid');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('auth.professionalSpecializationLabel'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _specialization,
                      hint: Text(
                        context.tr('auth.professionalSpecializationHint'),
                        style: GoogleFonts.inter(
                          color: p.inkMuted,
                          fontSize: 15,
                        ),
                      ),
                      isExpanded: true,
                      icon: Icon(Icons.expand_more_rounded, color: p.inkMuted),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: p.isDark
                            ? const Color(0xFF123640)
                                .withValues(alpha: 0.55)
                            : Colors.white,
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
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      items: _specializations
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(
                                s,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: p.inkDark,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _specialization = v),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr('auth.professionalCertificateLabel'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Material(
                        color: p.isDark
                            ? const Color(0xFF123640).withValues(alpha: 0.55)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: _pickCertificate,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: p.stroke),
                            ),
                            child: _certificatePreview(p),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('auth.professionalCertificateHelp'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: p.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _uploading ? null : _continue,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _uploading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              context.tr('auth.professionalContinue'),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
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

  Widget _certificatePreview(CarelinkPalette p) {
    final f = _certificateFile;
    if (f == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 44,
            color: AppColors.primary.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('auth.professionalTapToUpload'),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      );
    }
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: f.readAsBytes(),
        builder: (context, snap) {
          if (snap.error != null) {
            return Center(
              child: Text(
                context.tr('auth.professionalPreviewError'),
                style: GoogleFonts.inter(color: p.inkMuted),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(snap.data!, fit: BoxFit.cover),
          );
        },
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(File(f.path), fit: BoxFit.cover),
    );
  }
}

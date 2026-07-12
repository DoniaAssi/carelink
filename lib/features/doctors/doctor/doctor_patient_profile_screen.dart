import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/profile_avatar.dart';
import 'package:carelink/services/api_service.dart';

import 'doctor_ui_constants.dart';

class DoctorPatientProfileScreen extends StatefulWidget {
  const DoctorPatientProfileScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<DoctorPatientProfileScreen> createState() =>
      _DoctorPatientProfileScreenState();
}

class _DoctorPatientProfileScreenState
    extends State<DoctorPatientProfileScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _profile = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _apiService.getPatientProfile(widget.patientId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cleanError(error);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = CarelinkPalette.of(context);

    return DoctorTypographyScope(
      child: Scaffold(
        backgroundColor: DoctorUiConstants.pageColor(context),
        appBar: AppBar(
          title: Text(context.dx('Patient Profile')),
          centerTitle: true,
          backgroundColor: DoctorUiConstants.pageColor(context),
          foregroundColor: AppColors.primary,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _errorMessage != null
            ? _buildErrorState(palette)
            : RefreshIndicator(
                onRefresh: _loadProfile,
                color: AppColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildPatientHeader(palette),
                            const SizedBox(height: 18),
                            _buildPersonalInformationCard(palette),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPatientHeader(CarelinkPalette palette) {
    final imageUrl = profileImageUrlFromMap(_profile);
    final name = _value(['fullName', 'name'], fallback: 'Patient');

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(palette),
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.surfaceSoft,
              border: Border.all(color: palette.stroke, width: 2),
            ),
            child: ClipOval(
              child: profileAvatarOrPlaceholder(
                imageUrl: imageUrl,
                size: 98,
                placeholderColor: AppColors.primary,
                placeholderIcon: Icons.person_outline_rounded,
                iconSize: 48,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.inkDark,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInformationCard(CarelinkPalette palette) {
    final dateOfBirth = _dateValue(_value(['dateOfBirth', 'date_of_birth']));
    final rows = <_PersonalInfoRow>[
      _PersonalInfoRow(
        icon: Icons.badge_outlined,
        label: context.dx('Full Name'),
        value: _value(['fullName', 'name'], fallback: 'Not set'),
      ),
      _PersonalInfoRow(
        icon: Icons.wc_outlined,
        label: context.dx('Gender'),
        value: _displayWord(_value(['gender', 'sex']), fallback: 'Not set'),
      ),
      _PersonalInfoRow(
        icon: Icons.cake_outlined,
        label: context.dx('Date of Birth'),
        value: dateOfBirth.isEmpty ? 'Not set' : dateOfBirth,
      ),
      _PersonalInfoRow(
        icon: Icons.calendar_today_outlined,
        label: context.dx('Age'),
        value: _ageText(_value(['dateOfBirth', 'date_of_birth'])),
      ),
      _PersonalInfoRow(
        icon: Icons.phone_outlined,
        label: context.dx('Phone Number'),
        value: _value(['phone', 'phoneNumber'], fallback: 'Not set'),
      ),
      _PersonalInfoRow(
        icon: Icons.location_on_outlined,
        label: context.dx('Address'),
        value: _value([
          'addressText',
          'address',
          'location',
        ], fallback: 'Not set'),
      ),
      _PersonalInfoRow(
        icon: Icons.email_outlined,
        label: context.dx('Email'),
        value: _value(['email'], fallback: 'Not set'),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(palette),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: TextStyle(
              color: palette.inkDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < rows.length; index++) ...[
            _buildInformationRow(rows[index], palette),
            if (index != rows.length - 1)
              Divider(height: 25, color: palette.stroke),
          ],
        ],
      ),
    );
  }

  Widget _buildInformationRow(_PersonalInfoRow row, CarelinkPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(row.icon, color: AppColors.primary, size: 21),
        ),
        const SizedBox(width: 13),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(CarelinkPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_outlined,
              color: AppColors.primary,
              size: 54,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.inkMuted, fontSize: 15),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.dx('Try Again')),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _value(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = _profile[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return fallback;
  }

  String _dateValue(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _ageText(String raw) {
    final birthDate = DateTime.tryParse(raw);
    if (birthDate == null) return 'Not set';

    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age >= 0 ? '$age years' : 'Not set';
  }

  String _displayWord(String value, {String fallback = ''}) {
    final text = value.trim().replaceAll('_', ' ');
    if (text.isEmpty) return fallback;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _cleanError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = text.toLowerCase();
    if (text.isEmpty ||
        text.length > 180 ||
        lower.contains('<html') ||
        lower.contains('<!doctype')) {
      return 'Unable to load the patient profile right now.';
    }
    return text;
  }

  BoxDecoration _cardDecoration(CarelinkPalette palette) {
    return BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: palette.stroke),
      boxShadow: [
        BoxShadow(
          color: palette.cardShadowColor(0.05),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }
}

class _PersonalInfoRow {
  const _PersonalInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

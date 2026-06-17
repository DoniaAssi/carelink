import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder, profileImageUrlFromMap;
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/auth/login_screen.dart';
import 'package:carelink/features/notifications/notifications_screen.dart';
import 'package:carelink/features/patient/screens/patient_favorites_screen.dart';
import 'package:carelink/features/patient/widgets/patient_navigation_shell.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? errorMessage;

  bool get _isArabic => localeController.isArabic;

  String _t(String en, String ar) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    if (widget.userId.isEmpty) {
      setState(() {
        errorMessage = _t(
          'No patient profile selected or session expired.',
          'لم يتم تحديد ملف مريض أو انتهت الجلسة.',
        );
        isLoading = false;
      });
      return;
    }

    try {
      final response = await ApiService().getPatientProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        userData = response;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = _cleanProfileError(e);
        isLoading = false;
      });
    }
  }

  Future<void> handleItemTap(String action) async {
    if (action == 'editProfile') {
      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => EditProfileScreen(
            userId: widget.userId,
            userData: userData ?? const <String, dynamic>{},
          ),
        ),
      );
      if (updated == true) {
        await loadProfile();
      }
    } else if (action == 'medicalRecords') {
      PatientNavigationShell.switchTab(context, 3);
    } else if (action == 'favorites') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientFavoritesScreen(patientUserId: widget.userId),
        ),
      );
    } else if (action == 'notifications') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationsScreen(userId: widget.userId),
        ),
      );
    } else if (action == 'language') {
      await localeController.toggle();
      if (mounted) setState(() {});
    } else if (action == 'appearance') {
      await themeController.toggle();
      if (mounted) setState(() {});
    } else if (action == 'logout') {
      await _confirmAndLogout();
    }
  }

  String _cleanProfileError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 180 ||
        lower.contains('<html') ||
        lower.contains('<!doctype') ||
        lower.contains('<pre>')) {
      return _t(
        'Unable to load your profile right now. Please try again.',
        'تعذر تحميل ملفك الشخصي الآن. يرجى المحاولة مرة أخرى.',
      );
    }
    return raw;
  }

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.tr('patient.logout')),
        content: Text(
          _t(
            'Are you sure you want to logout?',
            'هل أنت متأكد أنك تريد تسجيل الخروج؟',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('patient.logout')),
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

  String _value(List<String> keys) {
    for (final key in keys) {
      final raw = userData?[key];
      final text = raw?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  String _displayDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final date = DateTime.tryParse(text);
    if (date == null) return text;
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _displayWord(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final normalized = text.replaceAll('_', ' ');
    return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: const PatientTopActions(showBack: false),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _buildErrorState(p)
          : SafeArea(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroSection(p),
                          const SizedBox(height: 12),
                          _buildProfileDetailsCard(p),
                          const SizedBox(height: 12),
                          _buildMedicalSummaryCard(p),
                          const SizedBox(height: 12),
                          _buildActionList(p),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeroSection(CarelinkPalette p) {
    final profileImageUrl = profileImageUrlFromMap(userData);
    final role = _displayWord(_value(['role']));
    final email = _value(['email']);
    final name = _value(['fullName', 'name']);

    return Column(
      children: [
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.surfaceSoft,
              border: Border.all(color: p.stroke, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: profileAvatarOrPlaceholder(
                  imageUrl: profileImageUrl,
                  size: 100,
                  placeholderColor: AppColors.primaryDark,
                  placeholderIcon: Icons.person,
                  iconSize: 50,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (name.isNotEmpty)
          Text(
            name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: p.inkDark,
            ),
            textAlign: TextAlign.center,
          ),
        if (role.isNotEmpty) ...[const SizedBox(height: 6), _profileChip(role)],
        if (email.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            email,
            style: TextStyle(color: p.inkMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildProfileDetailsCard(CarelinkPalette p) {
    final rows = <_ProfileRow>[];
    void add(IconData icon, String label, String value) {
      final text = value.trim();
      if (text.isNotEmpty) rows.add(_ProfileRow(icon, label, text));
    }

    add(
      Icons.badge_outlined,
      _t('Full name', 'الاسم الكامل'),
      _value(['fullName', 'name']),
    );
    add(
      Icons.email_outlined,
      context.tr('patient.emailLabel'),
      _value(['email']),
    );
    add(
      Icons.phone_outlined,
      context.tr('patient.phoneLabel'),
      _value(['phone']),
    );
    add(
      Icons.location_on_outlined,
      context.tr('patient.addressLabel'),
      _value(['addressText', 'address']),
    );
    add(
      Icons.verified_user_outlined,
      _t('Account type', 'نوع الحساب'),
      _displayWord(_value(['role'])),
    );
    add(
      Icons.cake_outlined,
      _t('Date of birth', 'تاريخ الميلاد'),
      _displayDate(_value(['dateOfBirth'])),
    );
    add(
      Icons.wc_outlined,
      _t('Gender', 'الجنس'),
      _displayWord(_value(['gender'])),
    );

    if (rows.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      p: p,
      title: _t('Profile details', 'تفاصيل الملف الشخصي'),
      rows: rows,
    );
  }

  Widget _buildMedicalSummaryCard(CarelinkPalette p) {
    final rows = <_ProfileRow>[];
    void add(IconData icon, String label, List<String> keys) {
      final text = _value(keys);
      if (text.isNotEmpty) rows.add(_ProfileRow(icon, label, text));
    }

    add(Icons.bloodtype_outlined, _t('Blood type', 'فصيلة الدم'), [
      'bloodType',
    ]);
    add(Icons.medical_information_outlined, _t('Allergies', 'الحساسية'), [
      'allergies',
    ]);
    add(Icons.healing_outlined, _t('Chronic conditions', 'الأمراض المزمنة'), [
      'chronicDiseases',
      'chronicConditions',
    ]);
    add(
      Icons.medication_outlined,
      _t('Current medications', 'الأدوية الحالية'),
      ['currentMedications'],
    );

    if (rows.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      p: p,
      title: _t('Medical summary', 'الملخص الطبي'),
      rows: rows,
    );
  }

  Widget _sectionCard({
    required CarelinkPalette p,
    required String title,
    required List<_ProfileRow> rows,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.15 : 0.03),
            blurRadius: 10,
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
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < rows.length; i++) ...[
            _detailRow(rows[i], p),
            if (i != rows.length - 1) _thinDivider(p),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(_ProfileRow row, CarelinkPalette p) {
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.inkMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                row.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: p.inkDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionList(CarelinkPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            _t('Account & Settings', 'إعدادات الحساب'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: p.inkMuted,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.15 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                _actionTile(
                  icon: Icons.person_outline_rounded,
                  title: context.tr('patient.editProfile'),
                  onTap: () => handleItemTap('editProfile'),
                  p: p,
                ),
                _listDivider(p),
                _actionTile(
                  icon: Icons.folder_open_outlined,
                  title: context.tr('patient.medicalRecords'),
                  onTap: () => handleItemTap('medicalRecords'),
                  p: p,
                ),
                _listDivider(p),
                _actionTile(
                  icon: Icons.favorite_border_rounded,
                  title: _t('Favorites', 'المفضلة'),
                  onTap: () => handleItemTap('favorites'),
                  p: p,
                ),
                _listDivider(p),
                _actionTile(
                  icon: Icons.notifications_none_rounded,
                  title: context.tr('patient.notifications'),
                  onTap: () => handleItemTap('notifications'),
                  p: p,
                ),
                _listDivider(p),
                _actionTile(
                  icon: Icons.logout_rounded,
                  title: context.tr('patient.logout'),
                  onTap: () => handleItemTap('logout'),
                  iconColor: Colors.red.shade400,
                  textColor: Colors.red.shade400,
                  showChevron: false,
                  p: p,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required CarelinkPalette p,
    Color? iconColor,
    Color? textColor,
    bool showChevron = true,
  }) {
    return PatientPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? p.inkDark,
                ),
              ),
            ),
            if (showChevron)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: p.inkMuted.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thinDivider(CarelinkPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, thickness: 1, color: p.stroke, indent: 32),
    );
  }

  Widget _listDivider(CarelinkPalette p) {
    return Divider(height: 1, thickness: 1, color: p.stroke, indent: 52);
  }

  Widget _profileChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildErrorState(CarelinkPalette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: loadProfile,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_t('Retry', 'إعادة المحاولة')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow {
  const _ProfileRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:carelink/core/app_colors.dart';
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
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: const Color(0xFFF4FAF9),
        appBar: AppBar(
          title: const Text('Nurse Profile'),
          backgroundColor: const Color(0xFFF4FAF9),
          foregroundColor: const Color(0xFF163235),
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: _openNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            IconButton(
              tooltip: 'Logout',
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadProfile,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? _errorState()
              : _profileBody(profile!),
        ),
      ),
    );
  }

  Widget _profileBody(ProviderProfile p) {
    final canWork = p.canWork;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
      children: [
        _headerCard(p),
        if (!canWork) ...[const SizedBox(height: 14), _lockedBanner(p)],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _infoCard(
                icon: Icons.work_history_rounded,
                label: 'Experience',
                value: '${p.experienceYears} years',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoCard(
                icon: Icons.workspace_premium_rounded,
                label: 'Tier',
                value: _displayTier(p.experienceTier),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.location_on_outlined,
          label: 'Location / Service Area',
          value: _fallback(p.serviceAreas, 'Not provided'),
          wide: true,
        ),
        const SizedBox(height: 22),
        _sectionTitle('Biography'),
        const SizedBox(height: 10),
        _textCard(_fallback(p.bio, 'No biography provided yet.')),
        const SizedBox(height: 22),
        _sectionTitle('Uploaded Documents'),
        const SizedBox(height: 10),
        _documentCard(
          title: 'Nursing License',
          subtitle: 'PDF / Image',
          url: p.nursingLicenseUrl,
          icon: Icons.badge_outlined,
        ),
        _documentCard(
          title: 'Medical Certificate',
          subtitle: 'PDF / Image',
          url: p.medicalCertificateUrl,
          icon: Icons.medical_information_outlined,
        ),
        _documentCard(
          title: 'ID Card',
          subtitle: 'PDF / Image',
          url: p.idCardUrl,
          icon: Icons.credit_card_rounded,
        ),
        _documentCard(
          title: 'CV File',
          subtitle: 'PDF / Image',
          url: p.cvFileUrl,
          icon: Icons.description_outlined,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openNotifications,
                icon: const Icon(Icons.notifications_none_rounded),
                label: const Text('Notifications'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9F97),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB42318),
                  side: const BorderSide(color: Color(0xFFFFDAD6)),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerCard(ProviderProfile p) {
    final initial = _fallback(p.fullName, widget.user.fullName).trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F9F97), Color(0xFF0B6F6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,
                child: Text(
                  (initial.isEmpty ? 'N' : initial[0]).toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF0B6F6B),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fallback(p.fullName, widget.user.fullName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _pill(_fallback(p.specialization, 'Nursing')),
                        if (p.rating > 0)
                          _pill(
                            p.rating.toStringAsFixed(1),
                            icon: Icons.star_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _statusChip(
                label: _statusLabel(p.approvalStatus),
                good: p.approvalStatus.toLowerCase() == 'approved',
              ),
              const SizedBox(width: 8),
              _statusChip(
                label: p.rateAcceptanceStatus.toLowerCase() == 'accepted'
                    ? 'Rate accepted'
                    : 'Rate pending',
                good: p.rateAcceptanceStatus.toLowerCase() == 'accepted',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lockedBanner(ProviderProfile p) {
    final approval = p.approvalStatus.toLowerCase();
    final message = approval == 'approved'
        ? _fallback(
            p.workGateMessage,
            'Please accept your admin-set hourly rate before starting work.',
          )
        : 'Waiting for Admin Approval';
    return Container(
      padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waiting for Admin Approval',
                  style: TextStyle(
                    color: Color(0xFF7A3E00),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF7A3E00),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    bool wide = false,
  }) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _iconBox(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6B7C80),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF163235),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentCard({
    required String title,
    required String subtitle,
    required String url,
    required IconData icon,
  }) {
    final available = url.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: available ? () => _showDocumentPreview(title, url) : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: _cardDecoration(
              borderColor: available
                  ? const Color(0xFFD7ECE9)
                  : const Color(0xFFE8EEEE),
            ),
            child: Row(
              children: [
                _iconBox(icon, muted: !available),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: available
                              ? const Color(0xFF163235)
                              : const Color(0xFF8A999C),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        available ? subtitle : 'Not uploaded',
                        style: const TextStyle(
                          color: Color(0xFF73878B),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  available
                      ? Icons.chevron_right_rounded
                      : Icons.lock_outline_rounded,
                  color: available
                      ? const Color(0xFF0F9F97)
                      : const Color(0xFF9AA9AC),
                ),
              ],
            ),
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
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF163235),
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
                              _previewFallback(),
                        ),
                      ),
                    ),
                  )
                else
                  _pdfPreviewCard(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openExternal(url),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open file'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F9F97),
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

  Widget _pdfPreviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7ECE9)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            color: Color(0xFF0F9F97),
            size: 54,
          ),
          SizedBox(height: 12),
          Text(
            'PDF preview',
            style: TextStyle(
              color: Color(0xFF163235),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Open the file to view the full document.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF73878B)),
          ),
        ],
      ),
    );
  }

  Widget _previewFallback() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: const Color(0xFFF3FAF8),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Color(0xFF73878B), size: 44),
          SizedBox(height: 10),
          Text('Unable to preview this file'),
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
        title: const Text('Logout'),
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF163235),
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _textCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF3E5559),
          fontSize: 14.5,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon, {bool muted = false}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF0F3F3) : const Color(0xFFE8F7F5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: muted ? const Color(0xFF9AA9AC) : const Color(0xFF0F9F97),
      ),
    );
  }

  Widget _pill(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.amber.shade200),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip({required String label, required bool good}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: good ? const Color(0xFFDDF8EE) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: good ? const Color(0xFF067647) : const Color(0xFFB54708),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration({Color borderColor = const Color(0xFFD7ECE9)}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF104C49).withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _errorState() {
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
          style: const TextStyle(
            color: Color(0xFF3E5559),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _loadProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F9F97),
            foregroundColor: Colors.white,
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }

  String _fallback(String value, String fallback) {
    final text = value.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  String _displayTier(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
    if (normalized == 'mid') return 'Mid';
    if (normalized == 'senior') return 'Senior';
    return 'Junior';
  }

  String _statusLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'approved') return 'Approved';
    if (normalized == 'rejected') return 'Rejected';
    if (normalized == 'inactive') return 'Inactive';
    return 'Pending approval';
  }
}

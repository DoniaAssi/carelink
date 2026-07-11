// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/provider_profile_service.dart';
import 'nurse_profile.dart';
import 'nurse_ui.dart';

class NurseSettings extends StatefulWidget {
  final User user;

  const NurseSettings({super.key, required this.user});

  @override
  State<NurseSettings> createState() => _NurseSettingsState();
}

class _NurseSettingsState extends State<NurseSettings> {
  // Notification preferences
  bool newRequestsNotifications = true;
  bool scheduleReminders = true;
  bool paymentNotifications = true;
  bool messageNotifications = false;
  bool emergencyAlerts = true;

  // Privacy settings
  bool profileVisible = true;
  bool showPhoneNumber = false;
  bool showEmail = false;

  // App settings
  bool darkMode = false;
  String language = 'English';

  // Availability slots
  List<Map<String, String>> availabilitySlots = [];
  bool _loadingAvailability = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAvailability();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(
            NurseUi.label(
              'Settings',
              '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a',
            ),
          ),
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
          actions: [
            NurseModeControls(
              providerUserId: widget.user.userId,
              onChanged: () {
                setState(() {
                  darkMode = NurseUi.isDarkMode.value;
                  language = NurseUi.isArabic.value ? 'Arabic' : 'English';
                });
                _saveSettings();
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account Section
                Text(
                  NurseUi.t('Account'),
                  style: TextStyle(
                    color: NurseUi.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSettingsCard(
                  'Profile',
                  'Manage your professional profile and certifications',
                  Icons.person,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NurseProfile(user: widget.user),
                    ),
                  ),
                ),
                _buildSettingsCard(
                  'Change Password',
                  'Update your account password',
                  Icons.lock,
                  () => _showChangePasswordDialog(),
                ),
                _buildSettingsCard(
                  'Account Verification',
                  'Manage your account verification status',
                  Icons.verified,
                  () => _showVerificationDialog(),
                ),
                const SizedBox(height: 20),

                // Notifications Section
                Text(
                  NurseUi.t('Notifications'),
                  style: TextStyle(
                    color: NurseUi.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: NurseUi.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: NurseUi.border.withOpacity(0.8)),
                  ),
                  child: Column(
                    children: [
                      _buildNotificationToggle(
                        'New Service Requests',
                        'Get notified when patients request your services',
                        newRequestsNotifications,
                        (value) =>
                            setState(() => newRequestsNotifications = value),
                      ),
                      const Divider(height: 1),
                      _buildNotificationToggle(
                        'Schedule Reminders',
                        'Reminders for upcoming appointments',
                        scheduleReminders,
                        (value) => setState(() => scheduleReminders = value),
                      ),
                      const Divider(height: 1),
                      _buildNotificationToggle(
                        'Payment Notifications',
                        'Updates on payments and earnings',
                        paymentNotifications,
                        (value) => setState(() => paymentNotifications = value),
                      ),
                      const Divider(height: 1),
                      _buildNotificationToggle(
                        'Messages',
                        'New messages from patients',
                        messageNotifications,
                        (value) => setState(() => messageNotifications = value),
                      ),
                      const Divider(height: 1),
                      _buildNotificationToggle(
                        'Emergency Alerts',
                        'Critical alerts and urgent requests',
                        emergencyAlerts,
                        (value) => setState(() => emergencyAlerts = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Privacy Section
                Text(
                  NurseUi.t('Privacy'),
                  style: TextStyle(
                    color: NurseUi.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: NurseUi.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: NurseUi.border.withOpacity(0.8)),
                  ),
                  child: Column(
                    children: [
                      _buildPrivacyToggle(
                        'Profile Visibility',
                        'Make your profile visible to patients',
                        profileVisible,
                        (value) => setState(() => profileVisible = value),
                      ),
                      const Divider(height: 1),
                      _buildPrivacyToggle(
                        'Show Phone Number',
                        'Display phone number on profile',
                        showPhoneNumber,
                        (value) => setState(() => showPhoneNumber = value),
                      ),
                      const Divider(height: 1),
                      _buildPrivacyToggle(
                        'Show Email',
                        'Display email address on profile',
                        showEmail,
                        (value) => setState(() => showEmail = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // App Settings Section
                Text(
                  NurseUi.label(
                    'App Settings',
                    '\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u062a\u0637\u0628\u064a\u0642',
                  ),
                  style: TextStyle(
                    color: NurseUi.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSettingsCard(
                  NurseUi.label('Language', '\u0627\u0644\u0644\u063a\u0629'),
                  NurseUi.label(
                    'Current: $language',
                    '\u0627\u0644\u062d\u0627\u0644\u064a\u0629: $language',
                  ),
                  Icons.language,
                  () => _showLanguageDialog(),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NurseUi.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: NurseUi.border.withOpacity(0.8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        NurseUi.label(
                          'Dark Mode',
                          '\u0627\u0644\u0648\u0636\u0639 \u0627\u0644\u062f\u0627\u0643\u0646',
                        ),
                        style: TextStyle(color: NurseUi.text, fontSize: 16),
                      ),
                      Switch(
                        value: darkMode,
                        onChanged: (value) {
                          setState(() => darkMode = value);
                          NurseUi.isDarkMode.value = value;
                          NurseUi.persistSettings(widget.user.userId);
                          _saveSettings();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withOpacity(0.30),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Availability Section
                Text(
                  NurseUi.label(
                    'Availability',
                    '\u0627\u0644\u062a\u0648\u0641\u0631',
                  ),
                  style: TextStyle(
                    color: NurseUi.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NurseUi.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.045),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (_loadingAvailability)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        )
                      else if (availabilitySlots.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'No available time slots yet',
                            style: TextStyle(
                              color: NurseUi.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        ...availabilitySlots.map(
                          (slot) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${slot['day']} - ${_displayTime(slot['startTime'])} to ${_displayTime(slot['endTime'])}',
                                    style: TextStyle(
                                      color: NurseUi.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 24),
                                  color: NurseUi.text,
                                  onPressed: () {
                                    setState(() {
                                      availabilitySlots.remove(slot);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: _addAvailabilitySlot,
                            icon: const Icon(Icons.add_rounded, size: 22),
                            label: const Text('Add Time Slot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveAvailability,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Availability',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Support Section
                const Text(
                  'Support',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildSettingsCard(
                  'Help & Support',
                  'Get help and contact support',
                  Icons.help,
                  () => _showHelpDialog(),
                ),
                _buildSettingsCard(
                  'Privacy Policy',
                  'Read our privacy policy',
                  Icons.privacy_tip,
                  () => _showPrivacyPolicy(),
                ),
                _buildSettingsCard(
                  'Terms of Service',
                  'Read our terms and conditions',
                  Icons.description,
                  () => _showTermsOfService(),
                ),
                const SizedBox(height: 20),

                // Danger Zone
                const Text(
                  'Account Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deactivate Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Temporarily disable your account. You can reactivate it anytime.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFc82333),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _deactivateAccount,
                          child: const Text(
                            'Deactivate Account',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // App Version
                Center(
                  child: Text(
                    'Care Link v1.0.0',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NurseUi.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: NurseUi.border.withOpacity(0.8)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryDark),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: NurseUi.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: NurseUi.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: NurseUi.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: (value) {
        onChanged(value);
        _saveSettings();
      },
      activeThumbColor: AppColors.primary,
      activeTrackColor: AppColors.primary.withOpacity(0.30),
    );
  }

  Widget _buildPrivacyToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: (value) {
        onChanged(value);
        _saveSettings();
      },
      activeThumbColor: AppColors.primary,
      activeTrackColor: AppColors.primary.withOpacity(0.30),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(NurseUi.t('Change Password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement password change
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password changed successfully')),
              );
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(NurseUi.t('Account Verification')),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, color: Colors.green, size: 48),
            SizedBox(height: 16),
            Text(
              'Your account is verified',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'All required certifications and documents have been verified.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = ['English', 'Arabic'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(NurseUi.t('Select Language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) {
            return ListTile(
              title: Text(lang),
              trailing: language == lang
                  ? const Icon(Icons.check, color: AppColors.primaryDark)
                  : null,
              onTap: () {
                setState(() => language = lang);
                NurseUi.isArabic.value = lang == 'Arabic';
                NurseUi.persistSettings(widget.user.userId);
                _saveSettings();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Language changed to $lang')),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(NurseUi.t('Help & Support')),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Need help? Contact our support team:',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'ðŸ“§ support@carelink.com\nðŸ“ž +1 (555) 123-4567',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    // TODO: Navigate to privacy policy page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy Policy - Coming Soon')),
    );
  }

  void _showTermsOfService() {
    // TODO: Navigate to terms of service page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terms of Service - Coming Soon')),
    );
  }

  void _deactivateAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(NurseUi.t('Deactivate Account')),
        content: const Text(
          'Are you sure you want to deactivate your account? You can reactivate it anytime by logging back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement account deactivation
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deactivated successfully'),
                ),
              );
            },
            child: const Text(
              'Deactivate',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSettings() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/nurse/settings/${widget.user.userId}'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        newRequestsNotifications =
            data['newRequestsNotifications'] ?? newRequestsNotifications;
        scheduleReminders = data['scheduleReminders'] ?? scheduleReminders;
        paymentNotifications =
            data['paymentNotifications'] ?? paymentNotifications;
        messageNotifications =
            data['messageNotifications'] ?? messageNotifications;
        emergencyAlerts = data['emergencyAlerts'] ?? emergencyAlerts;
        profileVisible = data['profileVisible'] ?? profileVisible;
        showPhoneNumber = data['showPhoneNumber'] ?? showPhoneNumber;
        showEmail = data['showEmail'] ?? showEmail;
        darkMode = data['darkMode'] ?? darkMode;
        language = data['language'] ?? language;
        NurseUi.isDarkMode.value = darkMode;
        NurseUi.isArabic.value = language == 'Arabic';
      });
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    await NurseUi.persistSettings(widget.user.userId);
    try {
      await http.put(
        Uri.parse('${ApiService.baseUrl}/nurse/settings/${widget.user.userId}'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'newRequestsNotifications': newRequestsNotifications,
          'scheduleReminders': scheduleReminders,
          'paymentNotifications': paymentNotifications,
          'messageNotifications': messageNotifications,
          'emergencyAlerts': emergencyAlerts,
          'profileVisible': profileVisible,
          'showPhoneNumber': showPhoneNumber,
          'showEmail': showEmail,
          'darkMode': darkMode,
          'language': language,
        }),
      );
    } catch (_) {}
  }

  Future<void> _loadAvailability() async {
    setState(() => _loadingAvailability = true);
    try {
      final slots = await ProviderProfileService.getAvailability(
        widget.user.userId,
      );
      setState(() {
        availabilitySlots = slots
            .map(
              (e) => {
                'day': e['day']?.toString() ?? '',
                'startTime': e['startTime']?.toString() ?? '',
                'endTime': e['endTime']?.toString() ?? '',
              },
            )
            .toList();
      });
    } catch (_) {}
    setState(() => _loadingAvailability = false);
  }

  Future<void> _saveAvailability() async {
    try {
      final success = await ProviderProfileService.saveAvailability(
        widget.user.userId,
        availabilitySlots,
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Availability updated successfully')),
        );
      } else {
        throw Exception('Failed to update availability');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update availability: $e')),
      );
    }
  }

  void _addAvailabilitySlot() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String selectedDay = 'Monday';
        TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
        TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
        final notesController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
            height: MediaQuery.of(context).size.height * 0.86,
            decoration: BoxDecoration(
              color: NurseUi.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Add Time Slot',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        children: [
                          _sheetLabel('Select Day'),
                          _sheetDropdown(
                            value: selectedDay,
                            items: const [
                              'Monday',
                              'Tuesday',
                              'Wednesday',
                              'Thursday',
                              'Friday',
                              'Saturday',
                              'Sunday',
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setSheetState(() => selectedDay = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _sheetLabel('Start Time'),
                          _sheetTimeTile(_formatClock(startTime), () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            if (time != null) {
                              setSheetState(() => startTime = time);
                            }
                          }),
                          const SizedBox(height: 16),
                          _sheetLabel('End Time'),
                          _sheetTimeTile(_formatClock(endTime), () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                            );
                            if (time != null) {
                              setSheetState(() => endTime = time);
                            }
                          }),
                          const SizedBox(height: 16),
                          _sheetLabel('Notes (Optional)'),
                          TextField(
                            controller: notesController,
                            maxLines: 4,
                            maxLength: 120,
                            decoration: _sheetDecoration('Add a note...'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            availabilitySlots.add({
                              'day': selectedDay,
                              'startTime': _format24(startTime),
                              'endTime': _format24(endTime),
                            });
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Slot',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
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
  }

  Widget _sheetLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: NurseUi.text,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _sheetDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: _sheetDecoration(null),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  color: NurseUi.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _sheetTimeTile(String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _sheetDecoration(null),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: NurseUi.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.access_time_rounded, color: AppColors.primaryDark),
          ],
        ),
      ),
    );
  }

  InputDecoration _sheetDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: NurseUi.surface,
      counterStyle: TextStyle(color: NurseUi.muted, fontSize: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: NurseUi.border.withValues(alpha: 0.8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: NurseUi.border.withValues(alpha: 0.8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  String _displayTime(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '--:--';
    final parts = text.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return text;
  }

  String _format24(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatClock(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }
}

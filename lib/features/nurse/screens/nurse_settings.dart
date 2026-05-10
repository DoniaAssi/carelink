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

  const NurseSettings({Key? key, required this.user}) : super(key: key);

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
    return NurseUi.reactive((context) => Scaffold(
      backgroundColor: NurseUi.background,
      appBar: AppBar(
        title: Text(NurseUi.label('Settings', '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a')),
        backgroundColor: NurseUi.background,
        foregroundColor: NurseUi.text,
        elevation: 0,
        actions: [
          NurseModeControls(onChanged: () {
            setState(() {
              darkMode = NurseUi.isDarkMode.value;
              language = NurseUi.isArabic.value ? 'Arabic' : 'English';
            });
            _saveSettings();
          }),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Section
              const Text(
                'Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              const Text(
                'Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      (value) => setState(() => newRequestsNotifications = value),
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
              const Text(
                'Privacy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                NurseUi.label('App Settings', '\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u062a\u0637\u0628\u064a\u0642'),
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
                      NurseUi.label('Dark Mode', '\u0627\u0644\u0648\u0636\u0639 \u0627\u0644\u062f\u0627\u0643\u0646'),
                      style: TextStyle(color: NurseUi.text, fontSize: 16),
                    ),
                    Switch(
                      value: darkMode,
                      onChanged: (value) {
                        setState(() => darkMode = value);
                        NurseUi.isDarkMode.value = value;
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
                NurseUi.label('Availability', '\u0627\u0644\u062a\u0648\u0641\u0631'),
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
                    if (_loadingAvailability)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      )
                    else
                      ...availabilitySlots.map((slot) => Column(
                        children: [
                          ListTile(
                            title: Text(
                              '${slot['day']} - ${slot['startTime']} to ${slot['endTime']}',
                              style: TextStyle(color: NurseUi.text),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: NurseUi.text),
                              onPressed: () {
                                setState(() {
                                  availabilitySlots.remove(slot);
                                });
                              },
                            ),
                          ),
                          if (availabilitySlots.last != slot) const Divider(height: 1),
                        ],
                      )),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: _addAvailabilitySlot,
                        icon: const Icon(Icons.add),
                        label: Text(NurseUi.label('Add Time Slot', '\u0625\u0636\u0627\u0641\u0629 \u0645\u0647\u0644\u0629 \u0632\u0645\u0646\u064a\u0629')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ElevatedButton(
                        onPressed: _saveAvailability,
                        child: Text(NurseUi.label('Save Availability', '\u062d\u0641\u0638 \u0627\u0644\u062a\u0648\u0641\u0631')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildSettingsCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: NurseUi.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
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

  Widget _buildPrivacyToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
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
        title: const Text('Change Password'),
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
        title: const Text('Account Verification'),
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
        title: const Text('Select Language'),
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
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Need help? Contact our support team:',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              '📧 support@carelink.com\n📞 +1 (555) 123-4567',
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
        title: const Text('Deactivate Account'),
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
                const SnackBar(content: Text('Account deactivated successfully')),
              );
            },
            child: const Text('Deactivate', style: TextStyle(color: Colors.red)),
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
      final slots = await ProviderProfileService.getAvailability(widget.user.userId);
      setState(() {
        availabilitySlots = slots.map((e) => {
          'day': e['day']?.toString() ?? '',
          'startTime': e['startTime']?.toString() ?? '',
          'endTime': e['endTime']?.toString() ?? '',
        }).toList();
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
    showDialog(
      context: context,
      builder: (context) {
        String selectedDay = 'Monday';
        TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
        TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: NurseUi.surface,
            title: Text(
              NurseUi.label('Add Availability Slot', '\u0625\u0636\u0627\u0641\u0629 \u0645\u0647\u0644\u0629 \u062a\u0648\u0641\u0631'),
              style: TextStyle(color: NurseUi.text),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  items: [
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                    'Saturday',
                    'Sunday',
                  ].map((day) => DropdownMenuItem(
                    value: day,
                    child: Text(day, style: TextStyle(color: NurseUi.text)),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedDay = value!),
                  decoration: InputDecoration(
                    labelText: NurseUi.label('Day', '\u0627\u0644\u064a\u0648\u0645'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                          );
                          if (time != null) setState(() => startTime = time);
                        },
                        child: Text(
                          NurseUi.label('Start: ${startTime.format(context)}', '\u0627\u0644\u0628\u062f\u0627\u064a\u0629: ${startTime.format(context)}'),
                          style: TextStyle(color: NurseUi.text),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: endTime,
                          );
                          if (time != null) setState(() => endTime = time);
                        },
                        child: Text(
                          NurseUi.label('End: ${endTime.format(context)}', '\u0627\u0644\u0646\u0647\u0627\u064a\u0629: ${endTime.format(context)}'),
                          style: TextStyle(color: NurseUi.text),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  NurseUi.label('Cancel', '\u0625\u0644\u063a\u0627\u0621'),
                  style: TextStyle(color: NurseUi.text),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  this.setState(() {
                    availabilitySlots.add({
                      'day': selectedDay,
                      'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                      'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                    });
                  });
                  Navigator.pop(context);
                },
                child: Text(NurseUi.label('Add', '\u0625\u0636\u0627\u0641\u0629')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

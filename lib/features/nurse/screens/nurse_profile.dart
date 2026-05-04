import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/models/provider_profile.dart';
import 'package:carelink/shared/services/provider_profile_service.dart';
import 'nurse_ui.dart';

class NurseProfile extends StatefulWidget {
  final User user;

  const NurseProfile({Key? key, required this.user}) : super(key: key);

  @override
  State<NurseProfile> createState() => _NurseProfileState();
}

class _NurseProfileState extends State<NurseProfile> {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final bioController = TextEditingController();
  final specializationController = TextEditingController();
  final experienceController = TextEditingController();
  final hourlyRateController = TextEditingController();
  final phoneController = TextEditingController();

  bool isAvailable = true;
  bool isLoading = false;
  ProviderProfile? provider;
  List<Map<String, dynamic>> availabilitySlots = [];

  final List<String> specializations = [
    'Home Nursing Care',
    'Physiotherapy',
    'Medication Administration',
    'Post-Surgery Care',
    'Pediatric Care',
    'Elderly Care',
    'Wound Care',
    'IV Therapy',
    'Blood Pressure Monitoring',
    'Diabetes Management',
  ];

  final List<String> certifications = [
    'Registered Nurse (RN)',
    'Licensed Practical Nurse (LPN)',
    'Certified Nursing Assistant (CNA)',
    'Advanced Cardiac Life Support (ACLS)',
    'Basic Life Support (BLS)',
    'Pediatric Advanced Life Support (PALS)',
    'Wound Care Certification',
    'IV Therapy Certification',
    'Diabetes Management Certification',
  ];

  List<String> selectedCertifications = [];

  @override
  void initState() {
    super.initState();
    _loadProviderProfile();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive((context) => Scaffold(
      backgroundColor: NurseUi.background,
      appBar: AppBar(
        title: Text(
          NurseUi.label(
            'Professional Profile',
            '\u0627\u0644\u0645\u0644\u0641 \u0627\u0644\u0645\u0647\u0646\u064a',
          ),
        ),
        backgroundColor: NurseUi.background,
        foregroundColor: NurseUi.text,
        elevation: 0,
        actions: [
          NurseModeControls(providerUserId: widget.user.userId),
          TextButton(
            onPressed: isLoading ? null : _saveProfile,
            child: Text(
              NurseUi.label('Save', '\u062d\u0641\u0638'),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.24),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            child: Text(
                              (widget.user.fullName.isNotEmpty
                                      ? widget.user.fullName[0]
                                      : 'N')
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.user.fullName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.user.email,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isAvailable ? Colors.green : Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isAvailable
                                        ? NurseUi.label('Available', '\u0645\u062a\u0627\u062d\u0629')
                                        : NurseUi.label('Unavailable', '\u063a\u064a\u0631 \u0645\u062a\u0627\u062d\u0629'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Basic Information
                    Text(
                      NurseUi.label(
                        'Basic Information',
                        '\u0627\u0644\u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0627\u0644\u0623\u0633\u0627\u0633\u064a\u0629',
                      ),
                      style: TextStyle(
                        color: NurseUi.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: fullNameController,
                      label: NurseUi.label('Full Name', '\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0643\u0627\u0645\u0644'),
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: emailController,
                      label: NurseUi.label('Email', '\u0627\u0644\u0625\u064a\u0645\u064a\u0644'),
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: phoneController,
                      label: NurseUi.label('Phone Number', '\u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062a\u0641'),
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: specializationController,
                      label: NurseUi.label('Specialization', '\u0627\u0644\u062a\u062e\u0635\u0635'),
                      icon: Icons.medical_services,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: experienceController,
                      label: NurseUi.label('Years of Experience', '\u0633\u0646\u0648\u0627\u062a \u0627\u0644\u062e\u0628\u0631\u0629'),
                      icon: Icons.work,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: hourlyRateController,
                      label: NurseUi.label('Hourly Rate (\$)', '\u0623\u062c\u0631 \u0627\u0644\u0633\u0627\u0639\u0629 (\$)'),
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),

                    // Professional Bio
                    Text(
                      NurseUi.label('Professional Bio', '\u0646\u0628\u0630\u0629 \u0645\u0647\u0646\u064a\u0629'),
                      style: TextStyle(
                        color: NurseUi.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bioController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: NurseUi.label(
                          'Tell patients about your experience and approach to care...',
                          '\u0627\u0643\u062a\u0628\u064a \u0644\u0644\u0645\u0631\u0636\u0649 \u0639\u0646 \u062e\u0628\u0631\u062a\u0643 \u0648\u0637\u0631\u064a\u0642\u0629 \u0631\u0639\u0627\u064a\u062a\u0643...',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Availability Toggle
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NurseUi.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            NurseUi.label(
                              'Accept New Requests',
                              '\u0627\u0633\u062a\u0642\u0628\u0627\u0644 \u0637\u0644\u0628\u0627\u062a \u062c\u062f\u064a\u062f\u0629',
                            ),
                            style: TextStyle(color: NurseUi.text, fontSize: 16),
                          ),
                          Switch(
                            value: isAvailable,
                            onChanged: (value) {
                              setState(() => isAvailable = value);
                            },
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Certifications
                    Text(
                      NurseUi.label('Certifications', '\u0627\u0644\u0634\u0647\u0627\u062f\u0627\u062a'),
                      style: TextStyle(
                        color: NurseUi.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: certifications.map((cert) {
                        final isSelected = selectedCertifications.contains(cert);
                        return FilterChip(
                          label: Text(cert),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedCertifications.add(cert);
                              } else {
                                selectedCertifications.remove(cert);
                              }
                            });
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primaryDark,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Upload Certification Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28a745),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _uploadCertification,
                        icon: const Icon(Icons.upload_file, color: Colors.white),
                        label: Text(
                          NurseUi.label(
                            'Upload Certification Document',
                            '\u0631\u0641\u0639 \u0648\u062b\u064a\u0642\u0629 \u0627\u0644\u0634\u0647\u0627\u062f\u0629',
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Settings Section
                    Text(
                      NurseUi.label('Settings', '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a'),
                      style: TextStyle(
                        color: NurseUi.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSettingsCard(
                      'Notification Preferences',
                      'Manage when you receive notifications',
                      Icons.notifications,
                      () => _showNotificationSettings(),
                    ),
                    const SizedBox(height: 10),
                    _buildSettingsCard(
                      'Payment Methods',
                      'Manage your payment options',
                      Icons.payment,
                      () => _showPaymentMethods(),
                    ),
                    const SizedBox(height: 10),
                    _buildSettingsCard(
                      'Schedule Management',
                      'Set your availability schedule',
                      Icons.schedule,
                      () => _showScheduleManagement(),
                    ),
                  ],
                ),
              ),
            ),
    ));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildSettingsCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NurseUi.surface,
          borderRadius: BorderRadius.circular(12),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NurseUi.text,
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

  Future<void> _loadProviderProfile() async {
    setState(() => isLoading = true);
    try {
      final profile = await ProviderProfileService.getProfile(widget.user.userId);
      if (profile != null) {
        provider = profile;
        fullNameController.text = profile.fullName.isNotEmpty
            ? profile.fullName
            : widget.user.fullName;
        emailController.text =
            profile.email.isNotEmpty ? profile.email : widget.user.email;
        bioController.text = profile.bio;
        specializationController.text = profile.specialization;
        experienceController.text = profile.experienceYears.toString();
        hourlyRateController.text = profile.hourlyRate.toStringAsFixed(0);
        phoneController.text = profile.phone;
        isAvailable = profile.isAvailable;
        selectedCertifications = List<String>.from(profile.certifications);
        availabilitySlots =
            await ProviderProfileService.getAvailability(widget.user.userId);
      } else {
        fullNameController.text = widget.user.fullName;
        emailController.text = widget.user.email;
        phoneController.text = widget.user.phone;
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => isLoading = true);
    try {
      final profile = ProviderProfile(
        providerId: widget.user.userId,
        fullName: fullNameController.text.trim(),
        email: emailController.text.trim(),
        bio: bioController.text.trim(),
        specialization: specializationController.text.trim(),
        experienceYears: int.tryParse(experienceController.text.trim()) ?? 0,
        hourlyRate: double.tryParse(hourlyRateController.text.trim()) ?? 0,
        phone: phoneController.text.trim(),
        isAvailable: isAvailable,
        certifications: selectedCertifications,
        availabilitySchedule: const {},
      );
      final success = await ProviderProfileService.updateProfile(profile);
      if (!success) {
        throw Exception('Failed to update profile');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _uploadCertification() async {
    try {
      final name = selectedCertifications.isNotEmpty
          ? selectedCertifications.last
          : 'Uploaded Certification';
      final success = await ProviderProfileService.uploadCertification(
        widget.user.userId,
        name,
      );
      if (!success) {
        throw Exception('Failed to upload certification');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certification saved successfully')),
      );
      await _loadProviderProfile();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Preferences',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildNotificationToggle('New Service Requests', true),
            _buildNotificationToggle('Schedule Reminders', true),
            _buildNotificationToggle('Payment Notifications', true),
            _buildNotificationToggle('Messages from Patients', false),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(String title, bool initialValue) {
    return StatefulBuilder(
      builder: (context, setState) => SwitchListTile(
        title: Text(title),
        value: initialValue,
        onChanged: (value) {
          setState(() => initialValue = value);
        },
        activeColor: AppColors.primary,
      ),
    );
  }

  void _showPaymentMethods() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Methods',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildPaymentMethod('Bank Transfer', '****1234', true),
            _buildPaymentMethod('PayPal', 'nurse@example.com', false),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // TODO: Add new payment method
                },
                child: const Text(
                  'Add Payment Method',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethod(String type, String details, bool isDefault) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                details,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF28a745),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Default',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  void _showScheduleManagement() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        final days = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
        final selectedDays = availabilitySlots
            .map((slot) => slot['day']?.toString() ?? '')
            .where((day) => day.isNotEmpty)
            .toSet();
        String startTime = availabilitySlots.isNotEmpty
            ? availabilitySlots.first['startTime'].toString().substring(0, 5)
            : '09:00';
        String endTime = availabilitySlots.isNotEmpty
            ? availabilitySlots.first['endTime'].toString().substring(0, 5)
            : '17:00';

        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Availability Schedule',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: startTime),
                          decoration: const InputDecoration(labelText: 'Start'),
                          onChanged: (value) => startTime = value,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: endTime),
                          decoration: const InputDecoration(labelText: 'End'),
                          onChanged: (value) => endTime = value,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...days.map(
                    (day) => CheckboxListTile(
                      value: selectedDays.contains(day),
                      title: Text(day),
                      activeColor: AppColors.primary,
                      onChanged: (value) {
                        setSheetState(() {
                          if (value == true) {
                            selectedDays.add(day);
                          } else {
                            selectedDays.remove(day);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final normalizedSlots = selectedDays
                      .map(
                        (day) => {
                          'day': day,
                          'startTime': startTime,
                          'endTime': endTime,
                        },
                      )
                      .toList();
                  final success = await ProviderProfileService.saveAvailability(
                    widget.user.userId,
                    normalizedSlots,
                  );
                  if (success) {
                    setState(() => availabilitySlots = normalizedSlots);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Availability saved successfully'
                            : 'Failed to save availability',
                      ),
                    ),
                  );
                  if (success) Navigator.pop(context);
                },
                child: const Text(
                  'Save Schedule',
                  style: TextStyle(color: Colors.white),
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

  Widget _buildDaySchedule(String day, bool available, String hours) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Text(
                hours,
                style: TextStyle(
                  color: available ? Colors.black : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: available,
                onChanged: (value) {
                  // TODO: Update availability
                },
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/app_localizations.dart';
import '../../../core/doctor_session.dart';
import '../../../core/locale_controller.dart';
import '../../../services/doctor_service.dart';
import '../../../core/app_colors.dart';
import 'doctor_ui_constants.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  Map<String, dynamic> _profile = {};
  Map<String, bool> _notificationPrefs = {};
  String _doctorId = '';
  String _doctorName = '';
  String _doctorEmail = '';
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _doctorId = prefs.getString('doctor_userId') ?? '';
      _doctorName = prefs.getString('doctor_fullName') ?? '';
      _doctorEmail = prefs.getString('doctor_email') ?? '';

      final profile = await _doctorService.getProfile(_doctorId);
      Map<String, dynamic> availability = const {};
      try {
        availability = await _doctorService.getAvailabilityStatus(_doctorId);
      } catch (e) {
        debugPrint('Doctor availability unavailable: $e');
      }
      Map<String, dynamic> notificationPrefs = const {};
      try {
        notificationPrefs = await _doctorService.getNotificationPreferences(
          _doctorId,
        );
      } catch (e) {
        debugPrint('Doctor notification preferences unavailable: $e');
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        if (availability.containsKey('isAvailable')) {
          _isAvailable = availability['isAvailable'] == true;
        }
        _notificationPrefs = {
          'medicalCases': notificationPrefs['medicalCases'] != false,
          'patientUpdates': notificationPrefs['patientUpdates'] != false,
          'newAppointments': notificationPrefs['newAppointments'] != false,
          'assignmentUpdates': notificationPrefs['assignmentUpdates'] != false,
          'cancellations': notificationPrefs['cancellations'] != false,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _updateProfile() async {
    final fullNameController = TextEditingController(
      text: _profile['user']?['fullName'] ?? _doctorName,
    );
    final phoneController = TextEditingController(
      text: _profile['user']?['phone'] ?? '',
    );
    final specializationController = TextEditingController(
      text: _profile['profile']?['specialization'] ?? '',
    );
    final bioController = TextEditingController(
      text: _profile['profile']?['shortBio'] ?? '',
    );
    final experienceController = TextEditingController(
      text: (_profile['profile']?['experienceYears'] ?? 0).toString(),
    );
    final feeController = TextEditingController(
      text: (_profile['profile']?['consultationFee'] ?? 0).toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: specializationController,
                  decoration: const InputDecoration(
                    labelText: 'Specialization',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bioController,
                  decoration: const InputDecoration(
                    labelText: 'Short Bio',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: experienceController,
                  decoration: const InputDecoration(
                    labelText: 'Experience (Years)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _saveProfile(
                      fullName: fullNameController.text,
                      phone: phoneController.text,
                      specialization: specializationController.text,
                      shortBio: bioController.text,
                      experienceYears: int.tryParse(experienceController.text),
                      consultationFee: double.tryParse(feeController.text),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.dx('Save Changes')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile({
    String? fullName,
    String? phone,
    String? specialization,
    String? shortBio,
    int? experienceYears,
    double? consultationFee,
  }) async {
    try {
      await _doctorService.updateProfile(
        _doctorId,
        fullName: fullName,
        phone: phone,
        specialization: specialization,
        shortBio: shortBio,
        experienceYears: experienceYears,
        consultationFee: consultationFee,
      );

      // Update local storage
      final prefs = await SharedPreferences.getInstance();
      if (fullName != null) await prefs.setString('doctor_fullName', fullName);

      _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.dx('Profile updated successfully')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _setAvailability(bool value) async {
    setState(() => _isAvailable = value);
    try {
      await _doctorService.setAvailability(_doctorId, value);
      await _loadProfile();
    } catch (e) {
      setState(() => _isAvailable = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating availability: $e')),
        );
      }
    }
  }

  Future<void> _setNotificationPref(String key, bool value) async {
    final next = Map<String, bool>.from(_notificationPrefs)..[key] = value;
    setState(() => _notificationPrefs = next);
    try {
      final response = await _doctorService.updateNotificationPreferences(
        _doctorId,
        {key: value},
      );
      final prefs = response['preferences'];
      if (prefs is Map && mounted) {
        setState(() {
          _notificationPrefs = {
            'medicalCases': prefs['medicalCases'] != false,
            'patientUpdates': prefs['patientUpdates'] != false,
            'newAppointments': prefs['newAppointments'] != false,
            'assignmentUpdates': prefs['assignmentUpdates'] != false,
            'cancellations': prefs['cancellations'] != false,
          };
        });
      }
    } catch (e) {
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notification preferences are not available on this backend yet.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.dtr('doctor.profile.logout')),
        content: Text(context.dtr('doctor.profile.logoutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.dtr('doctor.common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.dtr('doctor.profile.logout')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      await logoutDoctorToLogin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _profile['user'] ?? {};
    final profile = _profile['profile'] ?? {};

    return DoctorTypographyScope(
      child: ListenableBuilder(
        listenable: localeController,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: DoctorUiConstants.pageColor(context),
            appBar: AppBar(
              title: Text(
                context.dtr('doctor.nav.profile'),
                style: const TextStyle(color: Colors.black),
              ),
              backgroundColor: DoctorUiConstants.pageColor(context),
              foregroundColor: Colors.black,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _updateProfile,
                ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Profile Header
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    _doctorName.isNotEmpty
                                        ? _doctorName[0].toUpperCase()
                                        : 'D',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Dr. ${user['fullName'] ?? _doctorName}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user['email'] ?? _doctorEmail,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'DOCTOR',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Profile Details
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.dtr(
                                    'doctor.profile.professionalInfo',
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Divider(),
                                _buildDetailRow(
                                  context.dtr('doctor.profile.specialization'),
                                  profile['specialization'] ??
                                      context.dtr('doctor.common.notSet'),
                                ),
                                _buildDetailRow(
                                  context.dtr('doctor.profile.experience'),
                                  context.dtr(
                                    'doctor.profile.years',
                                    args: {
                                      'count': (profile['experienceYears'] ?? 0)
                                          .toString(),
                                    },
                                  ),
                                ),
                                _buildDetailRow(
                                  context.dtr('doctor.profile.rating'),
                                  '${profile['overallRating'] ?? 0}',
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    context.dtr(
                                      'doctor.profile.availableRequests',
                                    ),
                                  ),
                                  subtitle: Text(
                                    _isAvailable
                                        ? context.dtr('doctor.profile.visible')
                                        : context.dtr('doctor.profile.hidden'),
                                  ),
                                  value: _isAvailable,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: _setAvailability,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.dtr(
                                    'doctor.profile.notificationSettings',
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Divider(),
                                _notificationSwitch(
                                  'medicalCases',
                                  'Medical cases',
                                ),
                                _notificationSwitch(
                                  'patientUpdates',
                                  'Patient updates',
                                ),
                                _notificationSwitch(
                                  'newAppointments',
                                  'New appointments',
                                ),
                                _notificationSwitch(
                                  'assignmentUpdates',
                                  'Assignment updates',
                                ),
                                _notificationSwitch(
                                  'cancellations',
                                  'Cancellations',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Contact Info
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.dtr('doctor.profile.contactInfo'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Divider(),
                                _buildDetailRow(
                                  context.dtr('doctor.profile.phone'),
                                  user['phone'] ??
                                      context.dtr('doctor.common.notSet'),
                                ),
                                _buildDetailRow(
                                  context.dtr('doctor.profile.email'),
                                  user['email'] ?? _doctorEmail,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Logout Button
                        ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: Text(context.dtr('doctor.profile.logout')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _notificationSwitch(String key, String label) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: _notificationPrefs[key] ?? true,
      activeThumbColor: AppColors.primary,
      onChanged: (value) => _setNotificationPref(key, value),
    );
  }
}

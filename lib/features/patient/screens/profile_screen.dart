import 'package:flutter/material.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder, profileImageUrlFromMap;
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/features/patient/widgets/carelink_patient_app_bar.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'edit_profile_screen.dart';
import 'medical_records_screen.dart';
import 'patient_payment_history_screen.dart';
import 'package:carelink/features/notifications/notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? errorMessage;

  static const List<String> _itemIds = [
    'edit',
    'records',
    'payments',
    'notifications',
    'logout',
  ];

  IconData _itemIcon(String id) {
    switch (id) {
      case 'edit':
        return Icons.person_outline;
      case 'records':
        return Icons.folder_open_outlined;
      case 'payments':
        return Icons.receipt_long_outlined;
      case 'notifications':
        return Icons.notifications_none;
      case 'logout':
        return Icons.logout;
      default:
        return Icons.circle_outlined;
    }
  }

  String _itemTitle(BuildContext context, String id) {
    switch (id) {
      case 'edit':
        return context.tr('patient.menu.editProfile');
      case 'records':
        return context.tr('patient.menu.medicalRecords');
      case 'payments':
        return context.tr('patient.menu.paymentHistoryMenu');
      case 'notifications':
        return context.tr('patient.menu.notifications');
      case 'logout':
        return context.tr('patient.menu.logout');
      default:
        return id;
    }
  }

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final response = await ApiService().getPatientProfile(widget.userId);

      setState(() {
        userData = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> handleItemTap(String id) async {
    if (id == 'edit') {
      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => EditProfileScreen(
            userId: widget.userId,
            userData: userData ?? {},
          ),
        ),
      );
      if (updated == true) {
        await loadProfile();
      }
    } else if (id == 'records') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MedicalRecordsScreen(userId: widget.userId),
        ),
      );
    } else if (id == 'payments') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PatientPaymentHistoryScreen(patientUserId: widget.userId),
        ),
      );
    } else if (id == 'notifications') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationsScreen(userId: widget.userId),
        ),
      );
    } else if (id == 'logout') {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileImageUrl = profileImageUrlFromMap(userData) ?? '';
    final role = (userData?['role'] ?? 'patient').toString();
    final contactEmail = (userData?['email'] ?? '').toString();
    final contactPhone = (userData?['phone'] ?? '').toString();
    final address = (userData?['addressText'] ?? '').toString();
    final dob = (userData?['dateOfBirth'] ?? '').toString();
    final gender = (userData?['gender'] ?? '').toString();

    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: carelinkPatientAppBar(
        context,
        title: CarelinkAppBarTitle.forPatient(
          context,
          context.tr('patient.title.profile'),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Text(
                    errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: p.stroke),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                              child: ClipOval(
                                child: profileAvatarOrPlaceholder(
                                  imageUrl: profileImageUrl.isEmpty
                                      ? null
                                      : profileImageUrl,
                                  size: 88,
                                  placeholderColor: AppColors.primaryDark,
                                  placeholderIcon: Icons.person,
                                  iconSize: 42,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              userData?['fullName'] ??
                                  context.tr('patient.profile.noName'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: p.inkDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              userData?['email'] ??
                                  context.tr('patient.profile.noEmail'),
                              style: TextStyle(
                                color: p.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _profileChip(
                              '${context.tr('patient.profile.accountType')}: ${role.toUpperCase()}',
                            ),
                            const SizedBox(height: 14),
                            _infoRow(Icons.email_outlined,
                                context.tr('patient.field.email'), contactEmail),
                            const SizedBox(height: 8),
                            _infoRow(Icons.phone_outlined,
                                context.tr('patient.field.phone'), contactPhone),
                            if (address.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _infoRow(Icons.location_on_outlined,
                                  context.tr('patient.field.address'), address),
                            ],
                            if (dob.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _infoRow(Icons.cake_outlined,
                                  context.tr('patient.field.dob'), dob),
                            ],
                            if (gender.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _infoRow(Icons.wc_outlined,
                                  context.tr('patient.field.gender'), gender),
                            ],
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: p.isDark
                                    ? const Color(0xFF2A1C1C)
                                    : const Color(0xFFF9F3F3),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: p.isDark
                                      ? const Color(0xFF5C2A2A)
                                      : const Color(0xFFFFD9D9),
                                ),
                              ),
                              child: Text(
                                context.tr('patient.profile.deleteNote'),
                                style: TextStyle(
                                  color: p.isDark
                                      ? const Color(0xFFFFB4B4)
                                      : const Color(0xFF8F4E4E),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _itemIds.length,
                          itemBuilder: (context, index) {
                            final id = _itemIds[index];
                            return GestureDetector(
                              onTap: () => handleItemTap(id),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: p.surface,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: p.stroke),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _itemIcon(id),
                                      color: id == 'logout'
                                          ? Colors.red.shade400
                                          : AppColors.primaryDark,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        _itemTitle(context, id),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: p.inkDark,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                      color: id == 'logout'
                                          ? Colors.red.shade300
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
    );
  }

  Widget _profileChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final p = CarelinkPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: p.inkDark,
                fontSize: 13.5,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
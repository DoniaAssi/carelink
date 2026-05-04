import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'edit_profile_screen.dart';
import 'patient_medical_records_screen.dart';
import 'patient_visit_reports_panel.dart';

/// Health hub: official visit records (read-only), baseline profile link, visit timeline.
class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({
    super.key,
    required this.userId,
    /// Legacy: `0` = first tab, `1` = old “reports only” → now visit timeline (index 2).
    this.initialTab = 0,
  });

  final String userId;
  final int initialTab;

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _profileSnapshot = {};
  bool _profileLoading = true;

  late final TabController _tabController;

  int _mapInitialTab(int raw) {
    if (raw == 1) return 2;
    if (raw < 0) return 0;
    if (raw > 2) return 2;
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _mapInitialTab(widget.initialTab),
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _profileLoading = true;
    });
    try {
      final p = await ApiService().getPatientProfile(widget.userId);
      if (!mounted) return;
      setState(() => _profileSnapshot = p);
    } catch (_) {
      if (!mounted) return;
      setState(() => _profileSnapshot = {});
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _openEditProfile() async {
    final data = Map<String, dynamic>.from(_profileSnapshot);
    if (data.isEmpty) {
      try {
        final p = await ApiService().getPatientProfile(widget.userId);
        if (!mounted) return;
        setState(() => _profileSnapshot = p);
      } catch (_) {}
    }
    if (!mounted) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          userId: widget.userId,
          userData: Map<String, dynamic>.from(_profileSnapshot),
        ),
      ),
    );
    if (updated == true) await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final profileTab = _tabController.index == 1;

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: AppBar(
        centerTitle: true,
        title: const CarelinkAppBarTitle('Health record'),
        actions: carelinkAppBarActions(),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: p.inkMuted,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Records', icon: Icon(Icons.history_edu_outlined, size: 18)),
            Tab(text: 'Profile', icon: Icon(Icons.person_outline, size: 18)),
            Tab(
              text: 'Timeline',
              icon: Icon(Icons.receipt_long_outlined, size: 18),
            ),
          ],
        ),
      ),
      floatingActionButton: profileTab
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryDark,
              onPressed: _profileLoading ? null : _openEditProfile,
              child: const Icon(Icons.edit_outlined, color: Colors.white),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          PatientMedicalRecordsScreen(
            userId: widget.userId,
            requesterRole: 'patient',
          ),
          _buildProfileTab(p),
          PatientVisitReportsPanel(patientUserId: widget.userId),
        ],
      ),
    );
  }

  Widget _buildProfileTab(CarelinkPalette p) {
    if (_profileLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final chronic =
        (_profileSnapshot['chronicDiseases'] ?? '').toString().trim();
    final allergies = (_profileSnapshot['allergies'] ?? '').toString().trim();
    final meds =
        (_profileSnapshot['currentMedications'] ?? '').toString().trim();
    final dob = (_profileSnapshot['dateOfBirth'] ?? '').toString();
    final gender = (_profileSnapshot['gender'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Baseline medical profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: p.inkDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep chronic conditions, allergies, and medications up to date. '
          'These support safer care and better recommendations. '
          'Official diagnoses after visits appear in the Records tab.',
          style: TextStyle(color: p.inkMuted, height: 1.4),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _openEditProfile,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit profile & health baseline'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 24),
        _profileCard(
          p,
          'Age / DOB',
          dob.isEmpty ? '—' : dob,
        ),
        _profileCard(p, 'Gender', gender.isEmpty ? '—' : gender,
        ),
        _profileCard(
          p,
          'Chronic conditions',
          chronic.isEmpty ? '—' : chronic,
        ),
        _profileCard(
          p,
          'Allergies',
          allergies.isEmpty ? '—' : allergies,
        ),
        _profileCard(
          p,
          'Current medications',
          meds.isEmpty ? '—' : meds,
        ),
      ],
    );
  }

  Widget _profileCard(CarelinkPalette p, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: p.inkDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: TextStyle(color: p.inkMuted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

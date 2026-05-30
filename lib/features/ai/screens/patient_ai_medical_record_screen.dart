import 'package:flutter/material.dart';

import 'package:carelink/features/ai/recommendation/ai_recommendation_repository.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';
import 'package:carelink/features/ai/widgets/medical_record_card.dart';
import 'package:carelink/features/ai/widgets/upload_medical_report_button.dart';
import 'package:carelink/shared/services/api_service.dart';

/// Structured longitudinal record hub used by the AI recommender.
class PatientAiMedicalRecordScreen extends StatefulWidget {
  const PatientAiMedicalRecordScreen({super.key, required this.userId});

  final String userId;

  @override
  State<PatientAiMedicalRecordScreen> createState() =>
      _PatientAiMedicalRecordScreenState();
}

class _PatientAiMedicalRecordScreenState
    extends State<PatientAiMedicalRecordScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic> _profile = {};
  List<MedicalRecordEntry> _local = [];
  bool _loading = true;
  final _api = ApiService();
  final _store = AiMedicalRecordLocalStore();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _profile = await _api.getPatientProfile(widget.userId);
    } catch (_) {
      _profile = {};
    }
    _local = await _store.load(widget.userId);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiFlowTheme.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AiFlowTheme.ink,
        title: const Text(
          'Medical record',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AiFlowTheme.primaryBlue,
          indicatorColor: AiFlowTheme.primaryBlue,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Reports'),
            Tab(text: 'Prescriptions'),
            Tab(text: 'Appointments'),
            Tab(text: 'Uploads'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AiFlowTheme.primaryBlue),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _overview(),
                _filter(MedicalRecordEntryType.visitReport, isReport: true),
                _filter(MedicalRecordEntryType.prescription, isRx: true),
                _appointmentsPlaceholder(),
                _uploads(),
              ],
            ),
    );
  }

  Widget _overview() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _cardTitle('Personal information'),
        _kv('Full name', _profile['fullName']?.toString() ?? '—'),
        _kv('Gender', _profile['gender']?.toString() ?? '—'),
        _kv('Blood type', _profile['bloodType']?.toString() ?? '—'),
        const SizedBox(height: 12),
        _cardTitle('Chronic diseases'),
        Text(
          _profile['chronicConditions']?.toString().isNotEmpty == true
              ? _profile['chronicConditions'].toString()
              : 'None recorded',
        ),
        const SizedBox(height: 12),
        _cardTitle('Allergies'),
        Text(_profile['allergies']?.toString() ?? '—'),
        const SizedBox(height: 12),
        _cardTitle('Previous surgeries'),
        Text(_profile['pastSurgeries']?.toString() ?? '—'),
        const SizedBox(height: 12),
        _cardTitle('Current medications'),
        Text(_profile['currentMedications']?.toString() ?? '—'),
        const SizedBox(height: 12),
        _cardTitle('Doctor / nurse notes (profile)'),
        Text(_profile['additionalNotes']?.toString() ?? '—'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Documents you upload here carry the “Used by AI recommendations” label when enabled, so viva panels can see how longitudinal data feeds the hybrid scorer.',
            style: TextStyle(fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _cardTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(
          t,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AiFlowTheme.primaryBlue,
          ),
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                k,
                style: const TextStyle(
                  color: AiFlowTheme.inkMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(child: Text(v)),
          ],
        ),
      );

  Widget _filter(
    MedicalRecordEntryType primary, {
    bool isReport = false,
    bool isRx = false,
  }) {
    final items = _local.where((e) {
      if (isReport) {
        return e.type == MedicalRecordEntryType.visitReport ||
            e.type == MedicalRecordEntryType.oldReport ||
            e.type == MedicalRecordEntryType.diagnosis;
      }
      if (isRx) {
        return e.type == MedicalRecordEntryType.prescription ||
            e.prescription.isNotEmpty;
      }
      return e.type == primary;
    }).toList();

    if (items.isEmpty && isRx) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _profile['currentMedications']?.toString() ?? 'No prescriptions captured.',
            style: const TextStyle(height: 1.4),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) => MedicalRecordCard(entry: items[i]),
    );
  }

  Widget _appointmentsPlaceholder() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text(
          'Appointment history syncs from the bookings API in production. '
          'The AI flow already logs demo encounters via the confirmation screen.',
          style: TextStyle(height: 1.4),
        ),
      ],
    );
  }

  Widget _uploads() {
    final ups = _local
        .where(
          (e) =>
              e.type == MedicalRecordEntryType.oldReport ||
              e.attachments.isNotEmpty,
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        UploadMedicalReportButton(
          patientId: widget.userId,
          onUploaded: _refresh,
        ),
        const SizedBox(height: 14),
        ...ups.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MedicalRecordCard(entry: e),
          ),
        ),
      ],
    );
  }
}

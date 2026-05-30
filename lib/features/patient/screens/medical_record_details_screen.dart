import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/features/patient/widgets/carelink_patient_app_bar.dart';

/// Read-only visit report detail.
class MedicalRecordDetailsScreen extends StatefulWidget {
  const MedicalRecordDetailsScreen({
    super.key,
    required this.recordId,
    required this.patientUserId,
    this.requesterRole = 'patient',
  });

  final String recordId;
  final String patientUserId;
  final String requesterRole;

  @override
  State<MedicalRecordDetailsScreen> createState() =>
      _MedicalRecordDetailsScreenState();
}

class _MedicalRecordDetailsScreenState
    extends State<MedicalRecordDetailsScreen> {
  final _service = MedicalRecordService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await _service.getVisitReportById(
        widget.recordId,
        requesterUserId: widget.patientUserId,
        requesterRole: widget.requesterRole,
      );
      if (!mounted) return;
      setState(() {
        _data = m;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: carelinkPatientAppBar(
        context,
        title: CarelinkAppBarTitle.forPatient(
          context,
          context.tr('patient.title.visitReport'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(p, _data ?? {}),
    );
  }

  Widget _buildBody(CarelinkPalette p, Map<String, dynamic> m) {
    final provider = (m['providerName'] ?? '—').toString();
    final visitDate = (m['visit_date'] ?? m['created_at'] ?? '—').toString();
    final dx = (m['diagnosis'] ?? '').toString();
    final plan = (m['treatment_plan'] ?? '').toString();
    final rec = (m['recommendations'] ?? '').toString();
    final meds = (m['medications'] ?? '').toString();
    final allergies = (m['allergies'] ?? '').toString();
    final notes = (m['notes'] ?? '').toString();
    final vitals = m['vital_signs'];
    final fu = m['follow_up_required'] == true ||
        m['follow_up_required'] == 1 ||
        m['follow_up_required'] == '1';
    final fuDate = (m['follow_up_date'] ?? '').toString();

    Widget block(String title, String body) {
      if (body.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: p.inkDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(body, style: TextStyle(color: p.inkMuted, height: 1.35)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(provider, style: TextStyle(fontSize: 18, color: p.inkDark)),
        Text(visitDate, style: TextStyle(color: AppColors.primary)),
        const SizedBox(height: 16),
        if (vitals != null && vitals.toString().trim().isNotEmpty)
          block(context.tr('patient.record.block.vitals'), vitals.toString()),
        block(context.tr('patient.record.block.diagnosis'), dx),
        block(context.tr('patient.record.block.treatmentPlan'), plan),
        block(context.tr('patient.record.block.recommendations'), rec),
        block(context.tr('patient.record.block.meds'), meds),
        block(context.tr('patient.record.block.allergiesVisit'), allergies),
        block(context.tr('patient.record.block.notes'), notes),
        if (fu)
          block(
            context.tr('patient.record.block.followUp'),
            fuDate.isNotEmpty
                ? context.tr(
                    'patient.health.followUpRequiredBy',
                    args: {'date': fuDate},
                  )
                : context.tr('patient.health.followUpRequired'),
          ),
      ],
    );
  }
}

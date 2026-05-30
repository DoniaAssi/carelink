import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/widgets/carelink_patient_app_bar.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/services/medical_record_service.dart';

/// After a visit: provider submits structured report (linked to booking when possible).
class AddVisitReportScreen extends StatefulWidget {
  const AddVisitReportScreen({
    super.key,
    required this.patientUserId,
    required this.providerUserId,
    this.appointmentId,
    this.requesterRole = 'nurse',
  });

  final String patientUserId;
  final String providerUserId;
  final String? appointmentId;
  final String requesterRole;

  @override
  State<AddVisitReportScreen> createState() => _AddVisitReportScreenState();
}

class _AddVisitReportScreenState extends State<AddVisitReportScreen> {
  final _service = MedicalRecordService();
  final _formKey = GlobalKey<FormState>();
  final _diagnosis = TextEditingController();
  final _treatment = TextEditingController();
  final _recommendations = TextEditingController();
  final _vitalsJson = TextEditingController(
    text: '{"bp":"120/80","hr":72,"tempC":36.6}',
  );
  final _followUp = TextEditingController();
  final _visitDate = TextEditingController();
  final _medicationsPrescribed = TextEditingController();
  final _allergiesNoted = TextEditingController();
  bool _followRequired = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visitDate.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _diagnosis.dispose();
    _treatment.dispose();
    _recommendations.dispose();
    _vitalsJson.dispose();
    _followUp.dispose();
    _visitDate.dispose();
    _medicationsPrescribed.dispose();
    _allergiesNoted.dispose();
    super.dispose();
  }

  Future<void> _pickVisitDate() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_visitDate.text.trim()) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (d != null) {
      _visitDate.text =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) {
      _followUp.text =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final dx = _diagnosis.text.trim();
    final tx = _treatment.text.trim();
    if (dx.isEmpty && tx.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('patient.visitReport.needDiagnosis'))),
      );
      return;
    }

    dynamic vitals;
    try {
      vitals = jsonDecode(_vitalsJson.text.trim());
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('patient.visitReport.vitalsInvalidJson')),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.submitVisitReport(
        {
          'patient_id': widget.patientUserId,
          'provider_id': widget.providerUserId,
          if (widget.appointmentId != null &&
              widget.appointmentId!.trim().isNotEmpty)
            'appointment_id': widget.appointmentId!.trim(),
          'vital_signs': vitals,
          'diagnosis': dx,
          'treatment_plan': tx,
          'recommendations': _recommendations.text.trim(),
          'follow_up_required': _followRequired,
          if (_followUp.text.trim().isNotEmpty)
            'follow_up_date': _followUp.text.trim(),
          if (_visitDate.text.trim().isNotEmpty)
            'visit_date': _visitDate.text.trim(),
          if (_medicationsPrescribed.text.trim().isNotEmpty)
            'medications_prescribed': _medicationsPrescribed.text.trim(),
          if (_allergiesNoted.text.trim().isNotEmpty)
            'allergies_noted': _allergiesNoted.text.trim(),
        },
        requesterUserId: widget.providerUserId,
        requesterRole: widget.requesterRole,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Patient: ${widget.patientUserId}',
              style: TextStyle(color: p.inkMuted),
            ),
            if (widget.appointmentId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Appointment: ${widget.appointmentId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: p.inkMuted,
                  ),
                ),
              ),
            TextFormField(
              controller: _visitDate,
              readOnly: true,
              style: TextStyle(color: p.inkDark),
              decoration:
                  _dec(context, context.tr('patient.visitReport.visitDate'))
                      .copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _pickVisitDate,
                ),
              ),
            ),
            TextFormField(
              controller: _medicationsPrescribed,
              style: TextStyle(color: p.inkDark),
              decoration: _dec(
                context,
                context.tr('patient.visitReport.medsPrescribed'),
              ),
              maxLines: 3,
            ),
            TextFormField(
              controller: _allergiesNoted,
              style: TextStyle(color: p.inkDark),
              decoration: _dec(context, 'Allergies noted this visit (optional)'),
              maxLines: 2,
            ),
            TextFormField(
              controller: _vitalsJson,
              decoration: _dec(
                context,
                context.tr('patient.visitReport.vitalsJsonLabel'),
              ),
              maxLines: 4,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: p.inkDark,
              ),
            ),
            TextFormField(
              controller: _diagnosis,
              style: TextStyle(color: p.inkDark),
              decoration: _dec(
                context,
                context.tr('patient.visitReport.diagnosis'),
              ),
              maxLines: 3,
            ),
            TextFormField(
              controller: _treatment,
              style: TextStyle(color: p.inkDark),
              decoration: _dec(
                context,
                context.tr('patient.visitReport.treatmentPlan'),
              ),
              maxLines: 4,
            ),
            TextFormField(
              controller: _recommendations,
              style: TextStyle(color: p.inkDark),
              decoration: _dec(
                context,
                context.tr('patient.visitReport.recommendations'),
              ),
              maxLines: 3,
            ),
            SwitchListTile(
              value: _followRequired,
              onChanged: (v) => setState(() => _followRequired = v),
              title: Text(
                'Follow-up required',
                style: TextStyle(color: p.inkDark),
              ),
              activeThumbColor: AppColors.primary,
            ),
            TextFormField(
              controller: _followUp,
              readOnly: true,
              style: TextStyle(color: p.inkDark),
              decoration:
                  _dec(context, context.tr('patient.visitReport.followUpDate'))
                      .copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _pickFollowUp,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(context.tr('patient.visitReport.submit')),
            ),
          ]
              .map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: w,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  InputDecoration _dec(BuildContext context, String l) {
    final p = CarelinkPalette.of(context);
    return InputDecoration(
      labelText: l,
      labelStyle: TextStyle(color: p.inkMuted),
      filled: true,
      fillColor: p.surfaceSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';

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

  Color get _primary => const Color(MedicalRecordsBrand.primary);
  Color get _bg => const Color(MedicalRecordsBrand.background);
  Color get _ink => const Color(MedicalRecordsBrand.textDark);

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
        const SnackBar(content: Text('Add diagnosis or treatment plan.')),
      );
      return;
    }

    dynamic vitals;
    try {
      vitals = jsonDecode(_vitalsJson.text.trim());
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vital signs must be valid JSON.')),
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
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text('Visit report'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Patient: ${widget.patientUserId}',
              style: TextStyle(color: _ink.withValues(alpha: 0.7)),
            ),
            if (widget.appointmentId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Appointment: ${widget.appointmentId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _ink.withValues(alpha: 0.6),
                  ),
                ),
              ),
            TextFormField(
              controller: _visitDate,
              readOnly: true,
              decoration: _dec('Visit date').copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _pickVisitDate,
                ),
              ),
            ),
            TextFormField(
              controller: _medicationsPrescribed,
              decoration: _dec('Medications prescribed (optional)'),
              maxLines: 3,
            ),
            TextFormField(
              controller: _allergiesNoted,
              decoration: _dec('Allergies noted this visit (optional)'),
              maxLines: 2,
            ),
            TextFormField(
              controller: _vitalsJson,
              decoration: _dec('Vital signs (JSON)'),
              maxLines: 4,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            TextFormField(
              controller: _diagnosis,
              decoration: _dec('Diagnosis'),
              maxLines: 3,
            ),
            TextFormField(
              controller: _treatment,
              decoration: _dec('Treatment plan'),
              maxLines: 4,
            ),
            TextFormField(
              controller: _recommendations,
              decoration: _dec('Recommendations'),
              maxLines: 3,
            ),
            SwitchListTile(
              value: _followRequired,
              onChanged: (v) => setState(() => _followRequired = v),
              title: const Text('Follow-up required'),
              activeThumbColor: _primary,
            ),
            TextFormField(
              controller: _followUp,
              readOnly: true,
              decoration: _dec('Follow-up date').copyWith(
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
                backgroundColor: _primary,
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
                  : const Text('Submit report'),
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

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );
}

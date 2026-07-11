import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/services/api_service.dart';

import 'nurse_ui.dart';

class NursePatientMedicalRecordsScreen extends StatefulWidget {
  const NursePatientMedicalRecordsScreen({
    super.key,
    required this.request,
    required this.providerUserId,
  });

  final ServiceRequest request;
  final String providerUserId;

  @override
  State<NursePatientMedicalRecordsScreen> createState() =>
      _NursePatientMedicalRecordsScreenState();
}

class _NursePatientMedicalRecordsScreenState
    extends State<NursePatientMedicalRecordsScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> summary = const {};
  List<Map<String, dynamic>> records = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/nurse/patients/${Uri.encodeComponent(widget.request.patientId)}/medical-records',
      ).replace(queryParameters: {'providerId': widget.providerUserId});
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response.body));
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(decoded['summary'] ?? const {});
        records = (decoded['records'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _message(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'Failed to load medical records';
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('Medical Records')),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
          actions: NurseUi.headerActions(),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? _errorState()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  children: [
                    _patientHeader(),
                    const SizedBox(height: 14),
                    _summaryCard(),
                    const SizedBox(height: 18),
                    Text(
                      'Reports & Diagnoses',
                      style: TextStyle(
                        color: NurseUi.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (records.isEmpty)
                      _emptyRecords()
                    else
                      ...records.map(_recordCard),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientHeader() {
    final name = _patientName;
    return _card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: NurseUi.softSurface,
            child: Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: NurseUi.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.request.serviceType.trim().isEmpty
                      ? 'Care visit'
                      : widget.request.serviceType,
                  style: TextStyle(
                    color: NurseUi.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final diseases = _joinList(summary['diseases']);
    final allergies = _joinList(summary['allergies']);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Medical Summary',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _summaryRow('Blood Type', _text(summary['bloodType'], 'Not set')),
          _summaryRow('Chronic Diseases', diseases),
          _summaryRow('Allergies', allergies),
          _summaryRow(
            'Previous Diagnoses',
            _text(summary['previousDiagnoses'], 'No diagnosis recorded'),
          ),
          _summaryRow(
            'Past Surgeries',
            _text(summary['pastSurgeries'], 'No surgeries recorded'),
          ),
          _summaryRow(
            'Doctor Notes',
            _text(summary['doctorNotes'], 'No doctor notes'),
          ),
          _summaryRow(
            'Nurse Notes',
            _text(summary['nurseNotes'], 'No nurse notes'),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(
                color: NurseUi.muted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: NurseUi.text,
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> record) {
    final type = _recordType(record);
    final isInitial = type.toLowerCase().contains('initial');
    final diagnosis = _text(record['diagnosis'], '');
    final description = _text(
      record['description'] ?? record['aiSummary'],
      'No details available',
    );
    return _card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isInitial
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFE6F7F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isInitial
                      ? Icons.fact_check_outlined
                      : Icons.description_outlined,
                  color: isInitial
                      ? const Color(0xFF0369A1)
                      : AppColors.primaryDark,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(
                        record['title'],
                        isInitial ? 'Initial Diagnosis' : 'Medical Record',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_prettyType(type)} - ${_date(record['createdAt'])}',
                      style: TextStyle(
                        color: NurseUi.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (diagnosis.isNotEmpty) _detail('Diagnosis', diagnosis),
          _detail('Details', description),
          if (_text(record['treatmentPlan'], '').isNotEmpty)
            _detail('Treatment Plan', _text(record['treatmentPlan'], '')),
          if (_text(record['nursingInstructions'], '').isNotEmpty)
            _detail(
              'Nursing Instructions',
              _text(record['nursingInstructions'], ''),
            ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: NurseUi.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: NurseUi.text,
              fontSize: 12.5,
              height: 1.32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyRecords() {
    return _card(
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: Text(
            'No medical records are available for this patient yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NurseUi.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  String get _patientName {
    final fromSummary = _text(summary['patientName'], '');
    if (fromSummary.isNotEmpty) return fromSummary;
    return widget.request.patientName.trim().isEmpty
        ? 'Patient'
        : widget.request.patientName.trim();
  }

  String _joinList(dynamic value) {
    if (value is List) {
      final items = value.map((e) => e.toString()).where((e) => e.isNotEmpty);
      return items.isEmpty ? 'None recorded' : items.join(', ');
    }
    return 'None recorded';
  }

  String _text(dynamic value, String fallback) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String _recordType(Map<String, dynamic> record) {
    return _text(record['recordType'] ?? record['type'], 'medical_record');
  }

  String _prettyType(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse((value ?? '').toString());
    if (parsed == null) return 'Date not set';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }
}

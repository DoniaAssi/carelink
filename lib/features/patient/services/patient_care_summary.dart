import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class PatientCareSummary {
  const PatientCareSummary({
    required this.normalizedBlob,
    required this.hasStructuredData,
  });

  final String normalizedBlob;
  final bool hasStructuredData;

  static const empty = PatientCareSummary(
    normalizedBlob: '',
    hasStructuredData: false,
  );

  static PatientCareSummary fromText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return PatientCareSummary.empty;
    return PatientCareSummary(
      normalizedBlob: normalized,
      hasStructuredData: true,
    );
  }

  static PatientCareSummary mergeText(
    PatientCareSummary base,
    String text, {
    String label = '',
  }) {
    final cleaned = text.trim().toLowerCase();
    if (cleaned.isEmpty) return base;
    final prefix = label.trim().isEmpty ? '' : '${label.trim()}: ';
    final blob = StringBuffer(base.normalizedBlob)..writeln('$prefix$cleaned');
    return PatientCareSummary(
      normalizedBlob: blob.toString(),
      hasStructuredData: true,
    );
  }

  static PatientCareSummary mergeBaseline(
    PatientCareSummary base,
    Map<String, dynamic> profile,
  ) {
    final buf = StringBuffer(base.normalizedBlob);

    void add(Object? value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        buf.writeln(text.toLowerCase());
      }
    }

    add(profile['dateOfBirth']);
    add(profile['gender']);
    add(profile['bloodType']);
    add(profile['previousConditions']);
    add(profile['chronicConditions']);
    add(profile['allergies']);
    add(profile['currentMedications']);
    add(profile['pastSurgeries']);
    add(profile['previousDiagnoses']);
    add(profile['additionalNotes']);
    add(profile['chronicDiseases']);

    final medicalRecord = profile['medicalRecord'];
    if (medicalRecord is Map) {
      mergeBaseline(
        base,
        Map<String, dynamic>.from(medicalRecord),
      ).normalizedBlob.split('\n').forEach(add);
    }

    final out = buf.toString();
    return PatientCareSummary(
      normalizedBlob: out,
      hasStructuredData: out.trim().isNotEmpty,
    );
  }

  static PatientCareSummary mergeClinical(
    PatientCareSummary base,
    List<Map<String, dynamic>> clinical,
  ) {
    if (clinical.isEmpty) return base;
    final buf = StringBuffer(base.normalizedBlob);

    void add(Object? value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        buf.writeln(text.toLowerCase());
      }
    }

    for (final item in clinical) {
      final isPatientUpload = item['uploaded_by'] == 'patient' ||
          item['uploadedBy'] == 'patient' ||
          item['source'] == 'patient_upload';
      if (isPatientUpload) {
        final aiReady = item['ai_ready'] == true ||
            item['ai_ready'] == 1 ||
            item['aiReady'] == true;
        final status =
            (item['aiStatus'] ??
                    item['ai_status'] ??
                    item['extracted_text_status'] ??
                    item['extractedTextStatus'] ??
                    '')
                .toString()
                .toLowerCase()
                .trim();
        if (!aiReady || status != 'processed') {
          continue;
        }
      }

      add(item['title']);
      add(item['diagnosis']);
      add(item['symptoms']);
      add(item['notes']);
      add(item['medications']);
      add(item['medications_prescribed']);
      add(item['allergies']);
      add(item['allergies_noted']);
      add(item['treatmentPlan']);
      add(item['treatment_plan']);
      add(item['recommendations']);
      add(item['providerNotes']);
      add(item['vital_signs']);
      add(item['ai_summary']);
      add(item['aiSummary']);
      add(item['medical_summary']);
      add(item['medicalSummary']);
      add(item['ocr_text']);
      add(item['ocrText']);
      add(item['extracted_text']);
      add(item['extractedText']);
      for (final tag in _tagList(item['analysis_tags'] ?? item['analysisTags'] ?? item['tags'])) {
        add(tag);
      }
    }

    final out = buf.toString();
    return PatientCareSummary(
      normalizedBlob: out,
      hasStructuredData: out.trim().isNotEmpty,
    );
  }

  static List<String> _tagList(Object? raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    final text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return const [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return text
        .split(RegExp(r'[,;\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

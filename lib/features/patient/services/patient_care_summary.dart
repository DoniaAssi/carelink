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
    }

    final out = buf.toString();
    return PatientCareSummary(
      normalizedBlob: out,
      hasStructuredData: out.trim().isNotEmpty,
    );
  }
}

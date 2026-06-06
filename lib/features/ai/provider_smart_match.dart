import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/shared/models/provider_model.dart';

class ProviderSmartMatch {
  static List<T> sortCopy<T>(
    List<T> items, {
    String? selectedSpecialty,
    Object? locationService,
    double? patientLat,
    double? patientLng,
    Object? careSummary,
  }) {
    final sorted = List<T>.from(items);
    sorted.sort((a, b) {
      final bs = score(
        b,
        selectedSpecialty: selectedSpecialty ?? 'All',
        locationService: locationService,
        patientLat: patientLat,
        patientLng: patientLng,
        careSummary: careSummary,
      );
      final as = score(
        a,
        selectedSpecialty: selectedSpecialty ?? 'All',
        locationService: locationService,
        patientLat: patientLat,
        patientLng: patientLng,
        careSummary: careSummary,
      );
      return bs.compareTo(as);
    });
    return sorted;
  }

  static double medicalFitRatio(dynamic provider, Object? summary) {
    final backendScore = _backendMedicalScore(provider);
    if (backendScore != null) return backendScore.clamp(0.0, 1.0);

    final blob = _summaryBlob(summary);
    if (blob.trim().isEmpty) return 0.45;

    final spec = _providerText(provider);
    var score = 0.45;
    if (_any(blob, const ['heart', 'cardiac', 'angina', 'hypertens', 'chest pain']) &&
        _any(spec, const ['cardio', 'heart'])) {
      score = 0.95;
    } else if (_any(blob, const ['diabet', 'insulin', 'glucose', 'hba1c']) &&
        _any(spec, const ['internal', 'general', 'endocrin', 'family'])) {
      score = 0.9;
    } else if (_any(blob, const ['post surgery', 'surgery', 'wound', 'stitch']) &&
        (_any(spec, const ['nurs', 'wound', 'surgery', 'home']) || spec.contains('nurse'))) {
      score = 0.92;
    } else if (_any(blob, const ['asthma', 'copd', 'lung', 'respir']) &&
        _any(spec, const ['pulmon', 'lung', 'chest', 'respir'])) {
      score = 0.9;
    } else if (_any(blob, const ['dental', 'tooth', 'teeth']) && spec.contains('dent')) {
      score = 0.93;
    } else if (_any(blob, const ['anxiety', 'depression', 'psych']) &&
        _any(spec, const ['psych', 'mental'])) {
      score = 0.9;
    }
    return score.clamp(0.0, 1.0);
  }

  static double score(
    dynamic provider, {
    String selectedSpecialty = 'All',
    Object? locationService,
    double? patientLat,
    double? patientLng,
    Object? careSummary,
  }) {
    final backendFinalScore = _backendFinalScore(provider);
    if (backendFinalScore != null) return (backendFinalScore * 100).clamp(0.0, 100.0);

    final p = provider is ProviderModel ? provider : null;
    if (p == null) return 45.0;

    final location = _locationScore(p, locationService, patientLat, patientLng);
    final specialization = _specializationScore(selectedSpecialty, p, _summaryBlob(careSummary));
    final availability = p.isAvailable ? 0.55 : 0.0;
    final rating = _ratingScore(p.overallRating);
    final experience = _experienceScore(p.experienceYears);
    final medical = medicalFitRatio(p, careSummary);

    final finalScore =
        location * 0.20 +
        specialization * 0.25 +
        availability * 0.20 +
        rating * 0.15 +
        experience * 0.10 +
        medical * 0.10;
    return (finalScore * 100).clamp(0.0, 100.0);
  }

  static String recommendationReason(dynamic provider, Object? summary) {
    final backendReason = _backendReason(provider);
    if (backendReason != null && backendReason.trim().isNotEmpty) {
      return backendReason.trim();
    }

    final details = <String>[];
    final blob = _summaryBlob(summary);
    if (_any(blob, const ['diabetes', 'hba1c', 'glucose', 'blood sugar'])) {
      details.add('Diabetes follow-up');
    }
    if (_any(blob, const ['hypertension', 'blood pressure', 'cardiology', 'cardiologist'])) {
      details.add('Hypertension / cardiology follow-up');
    }
    if (_any(blob, const ['metformin', 'amlodipine', 'atorvastatin', 'medications'])) {
      details.add('Medication monitoring');
    }
    if (details.isEmpty) {
      return 'Recommended based on your medical records and care needs.';
    }
    return 'Recommended based on your medical records and care needs. ${details.join('. ')}.';
  }

  static double? _backendFinalScore(dynamic value) {
    if (value is AIRecommendationResult) return value.finalScore;
    if (value is Map) {
      return _num(value['finalScore'] ?? value['score']);
    }
    return null;
  }

  static double? _backendMedicalScore(dynamic value) {
    if (value is AIRecommendationResult) return value.breakdown.medicalCompatibility;
    if (value is Map) {
      final breakdown = value['scoreBreakdown'] ?? value['breakdown'];
      if (breakdown is Map) {
        return _num(
          breakdown['medicalCompatibility'] ??
              breakdown['medical_record_score'] ??
              breakdown['medicalRecordScore'],
        );
      }
      return _num(value['medicalRecordScore'] ?? value['medicalCompatibility']);
    }
    return null;
  }

  static String? _backendReason(dynamic value) {
    if (value is AIRecommendationResult) {
      return value.aiMatchReason ?? value.primaryReason;
    }
    if (value is Map) {
      final reason = value['aiMatchReason'] ?? value['recommendationReason'] ?? value['primaryReason'];
      if (reason != null) return reason.toString();
      final reasons = value['recommendationReasons'];
      if (reasons is List && reasons.isNotEmpty) return reasons.first.toString();
    }
    return null;
  }

  static String _summaryBlob(Object? summary) {
    if (summary is PatientCareSummary) return summary.normalizedBlob.toLowerCase();
    if (summary is PatientRecommendationProfile) {
      return [
        ...summary.chronicDiseases,
        ...summary.allergies,
        ...summary.medications,
        ...summary.previousSurgeries,
        summary.careSummary.normalizedBlob,
        ...summary.visitReportTexts,
        ...summary.aiSummaries,
        ...summary.ocrTexts,
        ...summary.analysisTags,
      ].join(' ').toLowerCase();
    }
    return (summary ?? '').toString().toLowerCase();
  }

  static String _providerText(dynamic provider) {
    if (provider is ProviderModel) {
      return '${provider.specialization} ${provider.serviceType} ${provider.role}'.toLowerCase();
    }
    if (provider is Map) {
      final p = provider['provider'];
      if (p != null) return _providerText(p);
      return '${provider['specialization']} ${provider['serviceType']} ${provider['role']}'.toLowerCase();
    }
    return provider.toString().toLowerCase();
  }

  static double _locationScore(
    ProviderModel provider,
    Object? locationService,
    double? patientLat,
    double? patientLng,
  ) {
    double? meters;
    if (locationService != null) {
      try {
        meters = (locationService as dynamic).distanceInMeters(
          fromLat: patientLat,
          fromLng: patientLng,
          toLat: provider.gpsLat,
          toLng: provider.gpsLng,
        ) as double?;
      } catch (_) {}
    }
    if (meters == null) return 0.2;
    final km = meters / 1000.0;
    if (km <= 1) return 1.0;
    if (km <= 3) return 0.8;
    if (km <= 5) return 0.6;
    if (km <= 10) return 0.4;
    return 0.2;
  }

  static double _specializationScore(String selectedSpecialty, ProviderModel p, String blob) {
    final selected = selectedSpecialty.trim().toLowerCase();
    final spec = p.specialization.trim().toLowerCase();
    if (selected.isEmpty || selected == 'all') return spec.isEmpty ? 0.35 : 0.55;
    if (spec == selected || spec.contains(selected) || selected.contains(spec)) return 1.0;
    if (selected.contains('cardio') && blob.contains('hypertens') && spec.contains('cardio')) return 0.7;
    if (selected.contains('diabet') && _any(spec, const ['internal', 'general', 'endocrin', 'family'])) return 0.7;
    return 0.35;
  }

  static double _ratingScore(double rating) {
    final raw = rating > 0 ? rating : 3.0;
    return (raw.clamp(0.0, 5.0)) / 5.0;
  }

  static double _experienceScore(int? years) {
    final y = years ?? 0;
    if (y >= 10) return 1.0;
    if (y >= 5) return 0.8;
    if (y >= 2) return 0.6;
    return 0.4;
  }

  static bool _any(String blob, List<String> terms) => terms.any(blob.contains);

  static double? _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

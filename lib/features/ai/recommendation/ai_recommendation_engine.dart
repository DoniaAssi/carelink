import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/shared/models/provider_model.dart';

/// On-device ranking engine that mirrors the backend JS engine logic.
class AiRecommendationEngine {
  static List<AIRecommendationResult> recommendProviders({
    required dynamic patient,
    required dynamic request,
    required List<dynamic> providers,
    int top = 10,
  }) {
    if (patient is! PatientRecommendationProfile) return const [];
    if (providers.isEmpty) return const [];

    final req = request is RecommendationRequest ? request : const RecommendationRequest();

    // Build patient medical text blob (mirrors JS patientCareBlob)
    final blobParts = <String>[
      ...patient.chronicDiseases,
      ...patient.allergies,
      ...patient.medications,
      ...patient.previousSurgeries,
      patient.careSummary.normalizedBlob,
      ...patient.visitReportTexts,
      ...patient.aiSummaries,
      ...patient.ocrTexts,
      ...patient.analysisTags,
    ];
    final blob = blobParts.join(' ').toLowerCase();
    final keyword = (req.requestedServiceKeyword.isNotEmpty
            ? req.requestedServiceKeyword
            : _inferKeyword(req.rawQuery))
        .toLowerCase();

    // Build AI blob for record-based reasoning
    final aiBlob = [
      ...patient.aiSummaries,
      ...patient.analysisTags,
      ...patient.ocrTexts,
    ].join(' ').toLowerCase();

    final out = <AIRecommendationResult>[];

    for (final p in providers) {
      if (p is! ProviderModel) continue;

      final spec = p.specialization.toLowerCase();
      final ss = _specializationScore(keyword, spec, blob);
      final rs = _ratingScore(p.overallRating);
      final es = _experienceScore(p.experienceYears);
      final ms = _medicalCompatibilityScore(blob, p);

      final finalScore = ss * 0.30 + rs * 0.20 + es * 0.15 + ms * 0.35;
      final matchPct = (finalScore * 100).clamp(0, 99).round();

      final reasons = <String>[];
      if (spec.isNotEmpty) reasons.add('Matches specialty "${p.specialization}".');
      if (p.overallRating >= 4.2) reasons.add('Highly rated (${p.overallRating.toStringAsFixed(1)}/5).');
      if ((p.experienceYears ?? 0) >= 8) reasons.add('Experienced (~${p.experienceYears} yrs).');
      if (ms >= 0.85) reasons.add('Strong medical-profile compatibility.');
      if (reasons.isNotEmpty) {
        reasons.insert(0, '${p.fullName} is recommended because they are a ${p.specialization}.');
      }

      // AI record-based reason
      String? aiMatchReason;
      if (aiBlob.isNotEmpty && spec.isNotEmpty) {
        final matched = aiBlob.contains(spec) ||
            (spec.contains('cardio') &&
                (aiBlob.contains('heart') ||
                    aiBlob.contains('blood pressure') ||
                    aiBlob.contains('hypertension'))) ||
            (spec.contains('endo') &&
                (aiBlob.contains('diabetes') ||
                    aiBlob.contains('sugar') ||
                    aiBlob.contains('thyroid'))) ||
            (spec.contains('ortho') &&
                (aiBlob.contains('bone') ||
                    aiBlob.contains('fracture') ||
                    aiBlob.contains('joint')));
        if (matched) {
          aiMatchReason =
              'Your uploaded records contain findings related to ${p.specialization}.';
        }
      }

      out.add(AIRecommendationResult(
        provider: p,
        finalScore: finalScore,
        matchPercentage: matchPct,
        breakdown: ScoreBreakdown(
          location: 0.5,
          specialization: ss,
          availability: 0.5,
          rating: rs,
          experience: es,
          medicalCompatibility: ms,
          history: 0.0,
        ),
        weights: RecommendationWeights.coldStart,
        recommendationReasons: reasons,
        aiMatchReason: aiMatchReason,
      ));
    }

    out.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    return out.take(top).toList();
  }

  static double _specializationScore(String keyword, String spec, String blob) {
    if (keyword.isNotEmpty && spec.contains(keyword)) return 1.0;
    if (keyword.isNotEmpty && blob.contains(keyword)) return 0.6;
    if (spec.isNotEmpty && blob.contains(spec.substring(0, spec.length.clamp(1, 4)))) return 0.5;
    return 0.2;
  }

  static double _ratingScore(double rating) {
    if (rating <= 0) return 0.5;
    return (rating / 5.0).clamp(0.0, 1.0);
  }

  static double _experienceScore(int? years) {
    if (years == null || years <= 0) return 0.4;
    return (years / 20.0).clamp(0.0, 1.0);
  }

  static double _medicalCompatibilityScore(String blob, ProviderModel p) {
    if (blob.isEmpty) return 0.5;
    var score = 0.0;
    final spec = p.specialization.toLowerCase();
    if (spec.isNotEmpty && blob.contains(spec)) score += 0.5;
    for (final tag in p.serviceType.split(',')) {
      if (tag.trim().isNotEmpty && blob.contains(tag.trim().toLowerCase())) score += 0.2;
    }
    return score.clamp(0.0, 1.0);
  }

  static String _inferKeyword(String rawQuery) {
    final q = rawQuery.toLowerCase();
    const keys = {
      'cardio': 'cardiology',
      'heart': 'cardiology',
      'dentist': 'dental',
      'dental': 'dental',
      'psych': 'psychiatry',
      'lung': 'pulmonology',
      'ortho': 'orthopedics',
      'bone': 'orthopedics',
      'diabetes': 'endocrinology',
      'thyroid': 'endocrinology',
      'general': 'general',
    };
    for (final entry in keys.entries) {
      if (q.contains(entry.key)) return entry.value;
    }
    return '';
  }
}

// ignore_for_file: public_member_api_docs

import 'dart:math' as math;

import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/location_service.dart';

/// **Why this is “AI” (for viva / thesis):** CareLink uses *automated intelligent
/// decision support* — a transparent scoring pipeline that fuses multiple patient
/// signals (location, clinical text, time preferences, ratings, experience, and
/// longitudinal history) to rank providers. It is *explainable by design*: every
/// output can be traced to named sub-scores and current weights.
///
/// **Why weighted scoring instead of machine learning:** Training a model would
/// require large labelled datasets, regulatory review, and yields opaque
/// “black-box” rankings hard to defend in healthcare UX. Weighted rules are
/// interpretable, tunable by clinicians/product, and sufficient for a
/// graduation prototype that demonstrates AI *reasoning structure* without
/// claiming learned optimality.
///
/// **Cold start (new patients):** With no history, `historyWeight` is zero and
/// recommendations rely on profile + free-text medical fields + request intent.
/// This mirrors classic recommendation *cold-start*: we fall back to
/// content-based features until interactions exist.
///
/// **Improvement over time:** Each completed visit can add ratings, visit
/// reports, and follow-up hints — increasing `historyWeight` eligibility and
/// boosting providers/specialties that demonstrably worked for the patient.
class AiRecommendationEngine {
  AiRecommendationEngine._();

  static final _loc = LocationService();

  // --- Geo ---------------------------------------------------------------

  static double calculateDistance(
    ({double lat, double lng}) patient,
    ({double lat, double lng}) provider,
  ) {
    final meters = _loc.distanceInMeters(
      fromLat: patient.lat,
      fromLng: patient.lng,
      toLat: provider.lat,
      toLng: provider.lng,
    );
    if (meters == null) return 25.0; // conservative default when GPS incomplete
    return meters / 1000.0;
  }

  /// Maps distance (km) to [0,1] — closer is better.
  static double calculateLocationScore(double distanceKm) {
    if (distanceKm <= 1) return 1.0;
    if (distanceKm <= 3) return 0.8;
    if (distanceKm <= 5) return 0.6;
    if (distanceKm <= 10) return 0.4;
    return 0.2;
  }

  // --- Specialization ----------------------------------------------------

  static double calculateSpecializationScore(
    String requestedService,
    String providerSpecialty,
    PatientCareSummary patientMedicalRecord,
  ) {
    final req = requestedService.trim().toLowerCase();
    final spec = providerSpecialty.trim().toLowerCase();
    final blob = patientMedicalRecord.normalizedBlob;

    if (req.isEmpty) {
      return spec.isNotEmpty ? 0.55 : 0.35;
    }
    if (spec.isEmpty) return 0.25;

    if (spec == req || spec.contains(req) || req.contains(spec)) {
      return 1.0;
    }

    if (_relatedSpecialtyMatch(req, spec, blob)) return 0.7;
    if (_weakSpecialtyMatch(req, spec)) return 0.3;

    final tok = req.split(RegExp(r'\s+'));
    for (final t in tok) {
      if (t.length < 3) continue;
      if (spec.contains(t)) return 0.7;
    }
    return 0.0;
  }

  static bool _relatedSpecialtyMatch(
    String req,
    String spec,
    String patientBlob,
  ) {
    const related = <String, List<String>>{
      'cardio': ['internal', 'general', 'heart', 'blood', 'vascular'],
      'heart': ['cardio', 'internal', 'general'],
      'lung': ['pulmon', 'chest', 'respir', 'general', 'internal'],
      'respir': ['pulmon', 'lung', 'chest'],
      'diabet': ['endocrin', 'internal', 'general', 'family'],
      'dental': ['dent', 'orthodont'],
      'psych': ['mental', 'behavior', 'psycholog'],
      'covid': ['pulmon', 'general', 'internal', 'lung'],
      'surgery': ['surgeon', 'ortho', 'general'],
      'general': ['family', 'gp', 'internal'],
    };

    for (final e in related.entries) {
      if (req.contains(e.key)) {
        for (final hint in e.value) {
          if (spec.contains(hint)) return true;
        }
      }
    }

    if (patientBlob.contains('heart') && spec.contains('cardio')) return true;
    if (patientBlob.contains('diabet') &&
        (spec.contains('internal') || spec.contains('general'))) {
      return true;
    }
    return false;
  }

  static bool _weakSpecialtyMatch(String req, String spec) {
    return spec.split(RegExp(r'[^a-z]+')).any(
          (w) => w.length > 3 && req.contains(w),
        );
  }

  // --- Availability ------------------------------------------------------

  static double calculateAvailabilityScore(
    DateTime? requestedDateTime,
    List<AvailabilitySlot> providerAvailableSlots,
  ) {
    if (providerAvailableSlots.isEmpty) return 0.0;
    if (requestedDateTime == null) {
      // No explicit preference: neutral-positive if any mid-week slot exists.
      return providerAvailableSlots.length >= 2 ? 0.55 : 0.4;
    }

    final weekdayName = _weekdayName(requestedDateTime.weekday);
    final wantMinutes = requestedDateTime.hour * 60 + requestedDateTime.minute;

    AvailabilitySlot? exact;
    AvailabilitySlot? sameDay;
    AvailabilitySlot? near;

    for (final slot in providerAvailableSlots) {
      final slotDay = slot.day.trim().toLowerCase();
      if (slotDay != weekdayName) continue;
      sameDay ??= slot;

      final start = _parseMinutes(slot.startTime) ?? 0;
      final end = _parseMinutes(slot.endTime) ?? (start + 240);
      if (wantMinutes >= start && wantMinutes <= end) {
        exact = slot;
        break;
      }
    }

    if (exact != null) return 1.0;
    if (sameDay != null) return 0.7;

    // Nearby weekday: ±1 day
    for (final slot in providerAvailableSlots) {
      if (_dayDelta(slot.day, weekdayName) <= 1) {
        near = slot;
        break;
      }
    }
    if (near != null) return 0.4;
    return 0.0;
  }

  static int _dayDelta(String slotDayRaw, String target) {
    const order = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final a = order.indexOf(slotDayRaw.trim().toLowerCase());
    final b = order.indexOf(target);
    if (a < 0 || b < 0) return 99;
    return (a - b).abs();
  }

  static String _weekdayName(int weekday) {
    const names = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }

  static int? _parseMinutes(String raw) {
    final p = raw.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  // --- Rating / experience -----------------------------------------------

  /// Cold start: unrated providers use neutral **3/5** for the weighted rating term only.
  static double calculateRatingScore(double overallRating) {
    final effective =
        overallRating <= 0 ? 3.0 : overallRating.clamp(0.0, 5.0);
    return effective / 5.0;
  }

  static double calculateExperienceScore(int? experienceYears) {
    final y = experienceYears ?? 0;
    if (y >= 10) return 1.0;
    if (y >= 5) return 0.8;
    if (y >= 2) return 0.6;
    return 0.4;
  }

  // --- Medical compatibility ---------------------------------------------

  static double calculateMedicalCompatibilityScore(
    PatientCareSummary patientMedicalRecord,
    ProviderModel provider,
  ) {
    if (!patientMedicalRecord.hasStructuredData) return 0.45;

    final p = patientMedicalRecord.normalizedBlob;
    final spec = [
      provider.specialization,
      provider.serviceType,
      provider.role,
    ].join(' ').toLowerCase();

    var score = 0.45;

    if (_any(p, ['heart', 'cardiac', 'angina', 'hypertens', 'chest pain']) &&
        _any(spec, ['cardio', 'heart'])) {
      score = 0.95;
    } else if (_any(p, ['diabet', 'insulin', 'glucose']) &&
        _any(spec, ['internal', 'general', 'endocrin', 'family'])) {
      score = math.max(score, 0.9);
    } else if (_any(p, ['post surgery', 'surgery', 'wound', 'stitch']) &&
        (_any(spec, ['nurs', 'wound', 'surgery', 'home']) ||
            provider.role.toLowerCase() == 'nurse')) {
      score = math.max(score, 0.92);
    } else if (_any(p, ['asthma', 'copd', 'lung', 'respir']) &&
        _any(spec, ['pulmon', 'lung', 'chest', 'respir'])) {
      score = math.max(score, 0.9);
    } else if (_any(p, ['dental', 'tooth', 'teeth']) &&
        _any(spec, ['dent'])) {
      score = math.max(score, 0.93);
    } else if (_any(p, ['anxiety', 'depression', 'psych']) &&
        _any(spec, ['psych', 'mental'])) {
      score = math.max(score, 0.9);
    }

    if (score < 0.65 &&
        ProviderSmartMatchLite.tokenOverlap(p, spec) >= 2) {
      score = 0.72;
    }
    return score.clamp(0.0, 1.0);
  }

  static bool _any(String blob, List<String> terms) {
    for (final t in terms) {
      if (blob.contains(t)) return true;
    }
    return false;
  }

  // --- History -----------------------------------------------------------

  static double calculateHistoryScore(
    PatientRecommendationProfile patient,
    ProviderModel provider,
  ) {
    if (!patient.hasHistoryForWeighting) return 0.0;

    var s = 0.0;
    final id = provider.userId;
    final rating = patient.previousProviderRatings[id];
    if (rating != null && rating >= 4.5) s += 0.55;
    if (rating != null && rating >= 4.0) s += 0.15;

    if (patient.successfulVisitProviderIds.contains(id)) s += 0.25;

    for (final report in patient.visitReportTexts) {
      final r = report.toLowerCase();
      if (r.contains('improve')) s += 0.12;
      if (r.contains('follow') &&
          (r.contains(provider.specialization.toLowerCase()) ||
              r.contains('cardio'))) {
        s += 0.35;
      }
    }

    for (final hint in patient.followUpHints) {
      if (provider.specialization.toLowerCase().contains(
            hint.toLowerCase(),
          )) {
        s += 0.3;
      }
    }

    final specBlob = provider.specialization.toLowerCase();
    var affinityBoost = 0.0;
    for (final e in patient.specializationRatingAffinity.entries) {
      if (e.value < 4.0) continue;
      final tag = e.key.toLowerCase().trim();
      if (tag.isEmpty) continue;
      if (specBlob.contains(tag) ||
          tag.contains(specBlob) ||
          _ratingSpecTokens(specBlob).any((t) => tag.contains(t))) {
        affinityBoost += 0.1;
        break;
      }
    }
    s += affinityBoost;

    return s.clamp(0.0, 1.0);
  }

  static List<String> _ratingSpecTokens(String specializationLower) {
    return specializationLower
        .split(RegExp(r'[,/&]'))
        .map((t) => t.trim())
        .where((t) => t.length > 2)
        .toList();
  }

  // --- Dynamic weights ----------------------------------------------------

  static RecommendationWeights getDynamicWeights(
    RecommendationRequest request,
    PatientRecommendationProfile patient,
  ) {
    var w = patient.hasHistoryForWeighting
        ? _withHistory(RecommendationWeights.coldStart)
        : RecommendationWeights.coldStart;

    if (request.isUrgent) {
      w = RecommendationWeights(
        locationWeight: w.locationWeight * 1.55,
        specializationWeight: w.specializationWeight * 0.95,
        availabilityWeight: w.availabilityWeight * 1.55,
        ratingWeight: w.ratingWeight * 0.90,
        experienceWeight: w.experienceWeight * 0.90,
        medicalCompatibilityWeight: w.medicalCompatibilityWeight * 1.05,
        historyWeight: w.historyWeight * 0.85,
      );
    } else if (request.isComplexCase) {
      w = RecommendationWeights(
        locationWeight: w.locationWeight * 0.90,
        specializationWeight: w.specializationWeight * 1.35,
        availabilityWeight: w.availabilityWeight * 0.90,
        ratingWeight: w.ratingWeight * 0.92,
        experienceWeight: w.experienceWeight * 1.35,
        medicalCompatibilityWeight: w.medicalCompatibilityWeight * 1.40,
        historyWeight: w.historyWeight * 1.05,
      );
    } else {
      // Normal / simple — slightly elevate rating influence.
      w = RecommendationWeights(
        locationWeight: w.locationWeight,
        specializationWeight: w.specializationWeight,
        availabilityWeight: w.availabilityWeight,
        ratingWeight: w.ratingWeight * 1.18,
        experienceWeight: w.experienceWeight,
        medicalCompatibilityWeight: w.medicalCompatibilityWeight,
        historyWeight: w.historyWeight,
      );
    }

    return w.normalized();
  }

  static RecommendationWeights _withHistory(RecommendationWeights base) {
    const h = 0.15;
    const scale = 1.0 - h;
    return RecommendationWeights(
      locationWeight: base.locationWeight * scale,
      specializationWeight: base.specializationWeight * scale,
      availabilityWeight: base.availabilityWeight * scale,
      ratingWeight: base.ratingWeight * scale,
      experienceWeight: base.experienceWeight * scale,
      medicalCompatibilityWeight: base.medicalCompatibilityWeight * scale,
      historyWeight: h,
    ).normalized();
  }

  // --- Orchestration ------------------------------------------------------

  static List<AIRecommendationResult> recommendProviders({
    required PatientRecommendationProfile patient,
    required RecommendationRequest request,
    required List<ProviderModel> providers,
    int top = 12,
  }) {
    if (providers.isEmpty) return [];

    final weights = getDynamicWeights(request, patient);
    final patientPoint = (
      lat: patient.locationLatitude ?? 31.95,
      lng: patient.locationLongitude ?? 35.91,
    );

    final keyword = request.requestedServiceKeyword.trim().isNotEmpty
        ? request.requestedServiceKeyword
        : _inferKeyword(request);

    final results = <AIRecommendationResult>[];

    for (final provider in providers) {
      final plat = provider.gpsLat ?? patientPoint.lat;
      final plng = provider.gpsLng ?? patientPoint.lng;

      final dist = calculateDistance(
        patientPoint,
        (lat: plat, lng: plng),
      );
      final ls = calculateLocationScore(dist);
      final ss = calculateSpecializationScore(
        keyword,
        provider.specialization,
        patient.careSummary,
      );
      final as = calculateAvailabilityScore(
        request.requestedDateTime,
        provider.availableSlots,
      );
      final rs = calculateRatingScore(provider.overallRating);
      final es = calculateExperienceScore(provider.experienceYears);
      final ms = calculateMedicalCompatibilityScore(
        patient.careSummary,
        provider,
      );
      final hs = calculateHistoryScore(patient, provider);

      final breakdown = ScoreBreakdown(
        location: ls,
        specialization: ss,
        availability: as,
        rating: rs,
        experience: es,
        medicalCompatibility: ms,
        history: hs,
      );

      final finalScore = (ls * weights.locationWeight) +
          (ss * weights.specializationWeight) +
          (as * weights.availabilityWeight) +
          (rs * weights.ratingWeight) +
          (es * weights.experienceWeight) +
          (ms * weights.medicalCompatibilityWeight) +
          (hs * weights.historyWeight);

      final pct = (finalScore * 100).round().clamp(0, 99);
      final reasons = buildReasonLines(
        provider: provider,
        request: request,
        distanceKm: dist,
        breakdown: breakdown,
      );

      results.add(
        AIRecommendationResult(
          provider: provider,
          finalScore: finalScore,
          matchPercentage: pct,
          breakdown: breakdown,
          weights: weights,
          recommendationReasons: reasons,
        ),
      );
    }

    results.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    if (results.length <= top) return results;
    return results.sublist(0, top);
  }

  static String _inferKeyword(RecommendationRequest r) {
    final q = r.rawQuery.toLowerCase();
    if (r.categoryKey != null) return r.categoryKey!;
    const keys = [
      'cardiology',
      'cardio',
      'dentist',
      'dental',
      'psych',
      'psychiatrist',
      'lung',
      'pulmon',
      'covid',
      'surgeon',
      'surgery',
      'general',
    ];
    for (final k in keys) {
      if (q.contains(k)) return k;
    }
    return '';
  }

  static List<String> buildReasonLines({
    required ProviderModel provider,
    required RecommendationRequest request,
    required double distanceKm,
    required ScoreBreakdown breakdown,
  }) {
    final lines = <String>[];
    if (provider.specialization.trim().isNotEmpty) {
      lines.add('Matches specialty "${provider.specialization}".');
    }
    if (distanceKm <= 10) {
      lines.add(
        'Within ${(distanceKm * 1000).round()} m — strong proximity score.',
      );
    }
    if (breakdown.availability >= 0.85) {
      lines.add('Available around your requested time window.');
    } else if (breakdown.availability >= 0.55) {
      lines.add('Partial availability alignment.');
    }
    if (provider.overallRating >= 4.2) {
      lines.add('Highly rated (${provider.overallRating.toStringAsFixed(1)}/5).');
    }
    if ((provider.experienceYears ?? 0) >= 8) {
      lines.add('Experienced clinician (~${provider.experienceYears} yrs).');
    }
    if (breakdown.medicalCompatibility >= 0.85) {
      lines.add('Strong medical-profile compatibility.');
    }
    if (breakdown.history >= 0.55) {
      lines.add('Boosted by your previous successful visits / follow-up plan.');
    }

    final head = '${provider.fullName} is recommended because ';
    final body = <String>[
      if (provider.specialization.isNotEmpty)
        'they are a ${provider.specialization}',
      if (breakdown.availability >= 0.69) 'fit your requested schedule',
      if (distanceKm < 1) 'are only ${(distanceKm * 1000).round()} m away',
      if (provider.overallRating > 0)
        'have a ${provider.overallRating.toStringAsFixed(1)} patient rating',
    ];
    if (body.isNotEmpty) {
      lines.insert(
        0,
        '$head${body.join(', ')}.',
      );
    }
    return lines;
  }
}

/// Minimal overlap helper (keeps engine self-contained for the thesis chapter).
class ProviderSmartMatchLite {
  static int tokenOverlap(String patient, String provider) {
    const stop = {'the', 'and', 'for', 'with', 'patient', 'mg'};
    final pt = patient
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((s) => s.length > 2 && !stop.contains(s))
        .toSet();
    var hit = 0;
    for (final t in pt) {
      if (provider.contains(t)) hit++;
    }
    return hit;
  }
}

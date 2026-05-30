import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/shared/models/provider_model.dart';

/// Search / booking context passed into the explainable recommender.
class RecommendationRequest {
  const RecommendationRequest({
    this.rawQuery = '',
    this.categoryKey,
    this.requestedDateTime,
    this.isUrgent = false,
    this.isComplexCase = false,
    this.requestedServiceKeyword = '',
  });

  final String rawQuery;
  /// One of [AiCategoryRegistry] keys, e.g. `cardiology`.
  final String? categoryKey;
  final DateTime? requestedDateTime;
  final bool isUrgent;
  final bool isComplexCase;
  /// Normalised token for specialization matching (filled by parser).
  final String requestedServiceKeyword;
}

/// Score components are in the 0–1 range before weighting.
class ScoreBreakdown {
  const ScoreBreakdown({
    required this.location,
    required this.specialization,
    required this.availability,
    required this.rating,
    required this.experience,
    required this.medicalCompatibility,
    required this.history,
  });

  final double location;
  final double specialization;
  final double availability;
  final double rating;
  final double experience;
  final double medicalCompatibility;
  final double history;
}

/// Mutable weight set; always [normalized] to sum ≈ 1 before scoring.
class RecommendationWeights {
  const RecommendationWeights({
    required this.locationWeight,
    required this.specializationWeight,
    required this.availabilityWeight,
    required this.ratingWeight,
    required this.experienceWeight,
    required this.medicalCompatibilityWeight,
    required this.historyWeight,
  });

  final double locationWeight;
  final double specializationWeight;
  final double availabilityWeight;
  final double ratingWeight;
  final double experienceWeight;
  final double medicalCompatibilityWeight;
  final double historyWeight;

  /// Default profile for **new** users (no meaningful history signals).
  static const RecommendationWeights coldStart = RecommendationWeights(
    locationWeight: 0.20,
    specializationWeight: 0.25,
    availabilityWeight: 0.20,
    ratingWeight: 0.15,
    experienceWeight: 0.10,
    medicalCompatibilityWeight: 0.10,
    historyWeight: 0.00,
  );

  RecommendationWeights normalized() {
    final sum = locationWeight +
        specializationWeight +
        availabilityWeight +
        ratingWeight +
        experienceWeight +
        medicalCompatibilityWeight +
        historyWeight;
    if (sum <= 0) return RecommendationWeights.coldStart;
    return RecommendationWeights(
      locationWeight: locationWeight / sum,
      specializationWeight: specializationWeight / sum,
      availabilityWeight: availabilityWeight / sum,
      ratingWeight: ratingWeight / sum,
      experienceWeight: experienceWeight / sum,
      medicalCompatibilityWeight: medicalCompatibilityWeight / sum,
      historyWeight: historyWeight / sum,
    );
  }
}

/// Rich patient view used only by the on-device recommender (API + local/mock).
class PatientRecommendationProfile {
  const PatientRecommendationProfile({
    required this.id,
    required this.fullName,
    this.age,
    this.gender,
    this.locationLatitude,
    this.locationLongitude,
    this.chronicDiseases = const [],
    this.allergies = const [],
    this.medications = const [],
    this.previousSurgeries = const [],
    this.careSummary = PatientCareSummary.empty,
    this.previousProviderRatings = const {},
    this.specializationRatingAffinity = const {},
    this.successfulVisitProviderIds = const [],
    this.visitReportTexts = const [],
    this.followUpHints = const [],
    this.hasHistoryForWeighting = false,
  });

  final String id;
  final String fullName;
  final int? age;
  final String? gender;
  final double? locationLatitude;
  final double? locationLongitude;
  final List<String> chronicDiseases;
  final List<String> allergies;
  final List<String> medications;
  final List<String> previousSurgeries;
  final PatientCareSummary careSummary;
  /// `providerId` → 1–5 stars (drives personalization for returning users).
  final Map<String, double> previousProviderRatings;
  /// Specialties where this patient’s past ratings averaged ≥ 4/5 (rule-based boost).
  final Map<String, double> specializationRatingAffinity;
  final List<String> successfulVisitProviderIds;
  final List<String> visitReportTexts;
  final List<String> followUpHints;
  /// When true, [RecommendationWeights] allocates 15% to history and scales others.
  final bool hasHistoryForWeighting;
}

/// One ranked explainable result for UI + graduation demo.
class AIRecommendationResult {
  const AIRecommendationResult({
    required this.provider,
    required this.finalScore,
    required this.matchPercentage,
    required this.breakdown,
    required this.weights,
    required this.recommendationReasons,
  });

  final ProviderModel provider;
  final double finalScore;
  final int matchPercentage;
  final ScoreBreakdown breakdown;
  final RecommendationWeights weights;
  final List<String> recommendationReasons;

  String get primaryReason => recommendationReasons.isEmpty
      ? 'High composite match under transparent weighted criteria.'
      : recommendationReasons.first;
}

/// Extended medical row for the structured record hub (local + synced).
enum MedicalRecordEntryType {
  oldReport,
  visitReport,
  labResult,
  prescription,
  diagnosis,
  note,
  attachment,
}

class MedicalRecordEntry {
  const MedicalRecordEntry({
    required this.id,
    required this.patientId,
    this.appointmentId,
    required this.uploadedBy,
    required this.type,
    required this.title,
    this.description = '',
    this.diagnosis = '',
    this.notes = '',
    this.prescription = '',
    this.attachments = const [],
    required this.createdAt,
    this.usedByAi = false,
    this.privateLabel = true,
    this.uploadedAfterVisit = false,
  });

  final String id;
  final String patientId;
  final String? appointmentId;
  final String uploadedBy; // patient | doctor | nurse | admin
  final MedicalRecordEntryType type;
  final String title;
  final String description;
  final String diagnosis;
  final String notes;
  final String prescription;
  final List<String> attachments;
  final DateTime createdAt;
  final bool usedByAi;
  final bool privateLabel;
  final bool uploadedAfterVisit;
}

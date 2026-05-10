import 'dart:convert';

import 'package:carelink/features/ai/recommendation/mock_ai_data.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads provider lists and fuses API data with deterministic mock rows.
class AiProviderRepository {
  AiProviderRepository(this._api);

  final ApiService _api;

  Future<List<ProviderModel>> loadMergedProviders() async {
    final mock = MockAiData.demoProviders();
    try {
      final raw = await _api.getProviders();
      final fromApi = raw.map((e) => ProviderModel.fromJson(e)).toList();
      final seen = fromApi.map((p) => p.userId).toSet();
      final merged = [...fromApi];
      for (final m in mock) {
        if (!seen.contains(m.userId)) {
          merged.add(m);
        }
      }
      return merged;
    } catch (_) {
      return mock;
    }
  }
}

/// Builds [PatientRecommendationProfile] from backend + local structured fields.
class PatientRecommendationProfileRepository {
  PatientRecommendationProfileRepository(this._api);

  final ApiService _api;

  Future<PatientRecommendationProfile> load({
    required String? userId,
    required bool returningDemo,
  }) async {
    if (userId == null || userId.trim().isEmpty) {
      return returningDemo
          ? MockAiData.returningPatient('guest_returning')
          : MockAiData.newPatient('guest');
    }

    if (returningDemo) {
      final base = MockAiData.returningPatient(userId.trim());
      return _mergeWithApi(userId.trim(), base);
    }

    final fresh = MockAiData.newPatient(userId.trim());
    return _mergeWithApi(userId.trim(), fresh);
  }

  Future<PatientRecommendationProfile> _mergeWithApi(
    String uid,
    PatientRecommendationProfile seed,
  ) async {
    Map<String, dynamic> profile = {};
    try {
      profile = await _api.getPatientProfile(uid);
    } catch (_) {}

    var clinical = <Map<String, dynamic>>[];
    try {
      clinical = await MedicalRecordService().listForPatient(
        uid,
        requesterUserId: uid,
        requesterRole: 'patient',
      );
    } catch (_) {}

    final baseSummary = PatientCareSummary.mergeBaseline(
      seed.careSummary,
      profile,
    );
    final mergedSummary = PatientCareSummary.mergeClinical(
      baseSummary,
      clinical,
    );

    final prefs = await SharedPreferences.getInstance();
    final extra = prefs.getString('ai_patient_profile_boost_$uid');
    var visitTexts = List<String>.from(seed.visitReportTexts);
    if (extra != null && extra.trim().isNotEmpty) {
      visitTexts = [...visitTexts, extra.trim().toLowerCase()];
    }

    var mergedPrevRatings =
        Map<String, double>.from(seed.previousProviderRatings);
    var specializationAffinity =
        Map<String, double>.from(seed.specializationRatingAffinity);
    try {
      final insights = await _api.getPatientRatingInsights(uid);
      final byProv = insights['averageStarsByProvider'];
      if (byProv is Map) {
        byProv.forEach((key, value) {
          final stars = value is num
              ? value.toDouble()
              : double.tryParse('$value') ?? 0;
          mergedPrevRatings[key.toString()] = stars;
        });
      }
      final aff = insights['specializationAffinity'];
      if (aff is Map) {
        aff.forEach((key, value) {
          final v = value is num
              ? value.toDouble()
              : double.tryParse('$value') ?? 0;
          specializationAffinity[key.toString()] = v;
        });
      }
    } catch (_) {}

    final historyWeighting = seed.hasHistoryForWeighting ||
        _hasHistorySignals(clinical) ||
        mergedPrevRatings.isNotEmpty ||
        specializationAffinity.isNotEmpty;

    return PatientRecommendationProfile(
      id: uid,
      fullName: profile['fullName']?.toString() ?? seed.fullName,
      age: int.tryParse(profile['age']?.toString() ?? '') ?? seed.age,
      gender: profile['gender']?.toString() ?? seed.gender,
      locationLatitude:
          double.tryParse(profile['gpsLat']?.toString() ?? '') ??
          seed.locationLatitude,
      locationLongitude:
          double.tryParse(profile['gpsLng']?.toString() ?? '') ??
          seed.locationLongitude,
      chronicDiseases: _splitField(
            profile['chronicDiseases'] ?? profile['chronicConditions'],
          ) ??
          seed.chronicDiseases,
      allergies: _splitField(profile['allergies']) ?? seed.allergies,
      medications: _splitField(profile['currentMedications']) ?? seed.medications,
      previousSurgeries:
          _splitField(profile['pastSurgeries']) ?? seed.previousSurgeries,
      careSummary: mergedSummary.normalizedBlob.trim().isEmpty
          ? seed.careSummary
          : mergedSummary,
      previousProviderRatings: mergedPrevRatings,
      specializationRatingAffinity: specializationAffinity,
      successfulVisitProviderIds: seed.successfulVisitProviderIds,
      visitReportTexts: visitTexts,
      followUpHints: seed.followUpHints,
      hasHistoryForWeighting: historyWeighting,
    );
  }

  bool _hasHistorySignals(List<Map<String, dynamic>> clinical) =>
      clinical.isNotEmpty;

  List<String>? _splitField(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return s
        .split(RegExp(r'[,;\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

/// Local persistence for AI-linked uploads and synthetic visit reports.
class AiMedicalRecordLocalStore {
  static const _recordsPrefix = 'ai_medical_entries_';

  Future<List<MedicalRecordEntry>> load(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_recordsPrefix$patientId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map(
            (e) => _entryFromMap(e, patientId),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  MedicalRecordEntry _entryFromMap(Map<dynamic, dynamic> e, String patientId) {
    return MedicalRecordEntry(
      id: e['id']?.toString() ?? '',
      patientId: patientId,
      appointmentId: e['appointmentId']?.toString(),
      uploadedBy: e['uploadedBy']?.toString() ?? 'patient',
      type: _typeFrom(e['type']?.toString() ?? 'note'),
      title: e['title']?.toString() ?? 'Record',
      description: e['description']?.toString() ?? '',
      diagnosis: e['diagnosis']?.toString() ?? '',
      notes: e['notes']?.toString() ?? '',
      prescription: e['prescription']?.toString() ?? '',
      attachments: (e['attachments'] as List<dynamic>?)
              ?.map((x) => x.toString())
              .toList() ??
          const [],
      createdAt: DateTime.tryParse(e['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      usedByAi: e['usedByAi'] == true,
      privateLabel: e['privateLabel'] != false,
      uploadedAfterVisit: e['uploadedAfterVisit'] == true,
    );
  }

  MedicalRecordEntryType _typeFrom(String raw) {
    switch (raw) {
      case 'visit_report':
        return MedicalRecordEntryType.visitReport;
      case 'lab_result':
        return MedicalRecordEntryType.labResult;
      case 'prescription':
        return MedicalRecordEntryType.prescription;
      case 'diagnosis':
        return MedicalRecordEntryType.diagnosis;
      case 'old_report':
        return MedicalRecordEntryType.oldReport;
      default:
        return MedicalRecordEntryType.note;
    }
  }

  Future<void> add(String patientId, MedicalRecordEntry entry) async {
    final existing = await load(patientId);
    final next = [...existing, entry];
    await _save(patientId, next);
  }

  Future<void> _save(String patientId, List<MedicalRecordEntry> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      list
          .map(
            (e) => {
              'id': e.id,
              'appointmentId': e.appointmentId,
              'uploadedBy': e.uploadedBy,
              'type': e.type.name,
              'title': e.title,
              'description': e.description,
              'diagnosis': e.diagnosis,
              'notes': e.notes,
              'prescription': e.prescription,
              'attachments': e.attachments,
              'createdAt': e.createdAt.toIso8601String(),
              'usedByAi': e.usedByAi,
              'privateLabel': e.privateLabel,
              'uploadedAfterVisit': e.uploadedAfterVisit,
            },
          )
          .toList(),
    );
    await prefs.setString('$_recordsPrefix$patientId', encoded);
  }

  /// Append text into the recommender’s longitudinal blob (demo / bridge).
  Future<void> appendProfileBoost(String patientId, String snippet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_patient_profile_boost_$patientId', snippet);
  }
}

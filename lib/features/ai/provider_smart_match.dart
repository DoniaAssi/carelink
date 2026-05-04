import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/location_service.dart';

/// Smart ordering: specialty, distance, availability, ratings, experience, and
/// optional fit with the patient's medical file (on-device rules — not a cloud LLM).
class ProviderSmartMatch {
  ProviderSmartMatch._();

  static const _maxSpecialty = 22.0;
  static const _maxDistance = 22.0;
  static const _maxAvailability = 18.0;
  static const _maxRating = 14.0;
  static const _maxExperience = 14.0;
  static const _maxMedical = 10.0;

  /// Total score 0–100.
  static double score(
    ProviderModel p, {
    required String selectedSpecialty,
    required LocationService locationService,
    required double? patientLat,
    required double? patientLng,
    PatientCareSummary careSummary = PatientCareSummary.empty,
  }) {
    return _specialtyPart(p, selectedSpecialty) +
        _distancePart(p, locationService, patientLat, patientLng) +
        _availabilityPart(p) +
        _ratingPart(p) +
        _experiencePart(p) +
        _medicalFitPart(p, careSummary);
  }

  /// 0–1 how much the provider aligns with the medical file (for UI copy).
  static double medicalFitRatio(
    ProviderModel p,
    PatientCareSummary careSummary,
  ) {
    if (!careSummary.hasStructuredData) return 0;
    return (_medicalFitPart(p, careSummary) / _maxMedical).clamp(0.0, 1.0);
  }

  static double _specialtyPart(ProviderModel p, String selectedSpecialty) {
    if (selectedSpecialty == 'All') return _maxSpecialty;
    final sel = selectedSpecialty.trim().toLowerCase();
    if (sel.isEmpty) return _maxSpecialty;
    final spec = p.specialization.trim().toLowerCase();
    if (spec.isNotEmpty && spec == sel) return _maxSpecialty;
    if (spec.isNotEmpty && (spec.contains(sel) || sel.contains(spec))) {
      return 16;
    }
    for (final part in p.serviceType.split(',')) {
      if (part.trim().toLowerCase().contains(sel)) return 10;
    }
    return 3;
  }

  static double _distancePart(
    ProviderModel p,
    LocationService loc,
    double? patientLat,
    double? patientLng,
  ) {
    final m = loc.distanceInMeters(
      fromLat: patientLat,
      fromLng: patientLng,
      toLat: p.gpsLat,
      toLng: p.gpsLng,
    );
    if (m == null) return _maxDistance * 0.5;
    final km = m / 1000.0;
    final t = (km / 90.0).clamp(0.0, 1.0);
    return _maxDistance * (1.0 - t);
  }

  static double _availabilityPart(ProviderModel p) {
    var s = 0.0;
    if (p.isAvailable) s += 11;
    s += p.availableSlots.length.clamp(0, 8).toDouble() * 0.875;
    if (s > _maxAvailability) return _maxAvailability;
    return s;
  }

  static double _ratingPart(ProviderModel p) {
    return _maxRating * (p.overallRating.clamp(0, 5) / 5.0);
  }

  static double _experiencePart(ProviderModel p) {
    final y = p.experienceYears;
    if (y != null && y > 0) {
      return _maxExperience * (y.clamp(0, 25) / 25.0);
    }
    return _maxExperience * 0.4 * (p.overallRating.clamp(0, 5) / 5.0);
  }

  static double _medicalFitPart(
    ProviderModel p,
    PatientCareSummary careSummary,
  ) {
    if (!careSummary.hasStructuredData) return _maxMedical;

    final patient = careSummary.normalizedBlob;
    final provider = _providerBlob(p);

    double fromHints = 0;
    for (final h in _conditionHints) {
      if (_anyToken(patient, h.patientTerms) &&
          _anyToken(provider, h.providerTerms)) {
        fromHints += 3.2;
      }
    }
    if (fromHints > 6.5) fromHints = 6.5;

    var allergyBoost = 0.0;
    if (_anyToken(patient, _allergyPatientTerms) &&
        _substringAny(provider, _allergyProviderHints)) {
      allergyBoost = 2.0;
    }

    final overlap = _significantTokenOverlap(patient, provider);
    final overlapPoints = (overlap * 1.2).clamp(0.0, 3.2);

    var total = fromHints + allergyBoost + overlapPoints;
    if (total > _maxMedical) return _maxMedical;
    if (total < 1.5) return 1.5;
    return total;
  }

  static String _providerBlob(ProviderModel p) {
    return [
      p.specialization,
      p.serviceType,
      p.role,
      p.fullName,
    ].join(' ').toLowerCase();
  }

  static bool _anyToken(String blob, List<String> terms) {
    for (final t in terms) {
      if (t.isEmpty) continue;
      if (blob.contains(t.toLowerCase())) return true;
    }
    return false;
  }

  static bool _substringAny(String blob, List<String> parts) {
    for (final part in parts) {
      if (part.isNotEmpty && blob.contains(part)) return true;
    }
    return false;
  }

  static int _significantTokenOverlap(String patient, String provider) {
    const stop = {
      'the',
      'and',
      'for',
      'with',
      'that',
      'from',
      'not',
      'has',
      'any',
      'none',
      'patient',
      'mg',
      'ml',
    };
    final normalized = patient.replaceAll(
      RegExp(r'[^a-zA-Z0-9\u0600-\u06FF\s]'),
      ' ',
    );
    final patTokens = normalized
        .split(RegExp(r'\s+'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.length > 2 && !stop.contains(s))
        .toSet();
    if (patTokens.isEmpty) return 0;
    var hit = 0;
    for (final t in patTokens) {
      if (provider.contains(t)) hit++;
    }
    return hit.clamp(0, 8);
  }

  static List<ProviderModel> sortCopy(
    List<ProviderModel> list, {
    required String selectedSpecialty,
    required LocationService locationService,
    required double? patientLat,
    required double? patientLng,
    PatientCareSummary careSummary = PatientCareSummary.empty,
  }) {
    if (list.isEmpty) return list;
    final copy = List<ProviderModel>.from(list);
    copy.sort((a, b) {
      final sa = score(
        a,
        selectedSpecialty: selectedSpecialty,
        locationService: locationService,
        patientLat: patientLat,
        patientLng: patientLng,
        careSummary: careSummary,
      );
      final sb = score(
        b,
        selectedSpecialty: selectedSpecialty,
        locationService: locationService,
        patientLat: patientLat,
        patientLng: patientLng,
        careSummary: careSummary,
      );
      if (sb != sa) return sb.compareTo(sa);
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
    return copy;
  }
}

class _ConditionHint {
  const _ConditionHint(this.patientTerms, this.providerTerms);
  final List<String> patientTerms;
  final List<String> providerTerms;
}

const _allergyPatientTerms = [
  'allergy',
  'allergic',
  'allergies',
  'penicillin',
  'latex',
  'حساسية',
  'حساس',
];

const _allergyProviderHints = [
  'allerg',
  'immunolog',
  'immun',
  'dermat',
  'skin',
  'otorhin',
  'أذن',
];

const _conditionHints = <_ConditionHint>[
  _ConditionHint(
    [
      'post surgery',
      'post-surgery',
      'after surgery',
      'surgery recovery',
      'operation recovery',
      'wound',
      'dressing',
      'stitches',
      'جرح',
      'غيار',
      'عملية',
    ],
    [
      'wound',
      'dressing',
      'nurs',
      'home care',
      'follow',
      'surgery',
      'جرح',
      'تمريض',
    ],
  ),
  _ConditionHint(
    [
      'injection',
      'shot',
      'vaccine',
      'iv',
      'medication administration',
      'حقنة',
      'ابرة',
      'إبرة',
    ],
    ['injection', 'nurs', 'medication', 'home care', 'تمريض', 'حقن'],
  ),
  _ConditionHint(
    [
      'elderly',
      'senior',
      'mobility',
      'daily care',
      'home nursing',
      'كبار السن',
      'مسن',
      'رعاية منزلية',
    ],
    [
      'elderly',
      'senior',
      'nurs',
      'home care',
      'caregiver',
      'تمريض',
      'رعاية منزلية',
    ],
  ),
  _ConditionHint(
    [
      'diabetes',
      'diabetic',
      'insulin',
      't1dm',
      't2dm',
      'hba1c',
      'glucose',
      'سكري',
      'سكر',
      'السكري',
    ],
    [
      'endocrin',
      'internal',
      'diabet',
      'general',
      'gp',
      'family',
      'طبيب عام',
      'باطنية',
      'سكري',
    ],
  ),
  _ConditionHint(
    [
      'asthma',
      'copd',
      'respiratory',
      'lung',
      'wheez',
      'oxygen',
      'ربو',
      'جهاز تنفس',
    ],
    [
      'pulmon',
      'chest',
      'respir',
      'lung',
      'thorac',
      'general',
      'gp',
      'طبيب عام',
      'صدر',
    ],
  ),
  _ConditionHint(
    [
      'heart',
      'cardiac',
      'hypertension',
      'blood pressure',
      'angina',
      'cholesterol',
      'قلب',
      'ضغط',
      'صمام',
    ],
    [
      'cardio',
      'cardiac',
      'heart',
      'internal',
      'general',
      'hypertens',
      'قلب',
      'أمراض قلب',
    ],
  ),
  _ConditionHint(
    [
      'epilepsy',
      'seizure',
      'migraine',
      'stroke',
      'neuropathy',
      'صرع',
      'نوبة',
      'سكتة',
      'أعصاب',
    ],
    ['neuro', 'brain', 'stroke', 'headache', 'عصب', 'دماغ'],
  ),
  _ConditionHint(
    ['kidney', 'renal', 'dialysis', 'creatinine', 'كلى', 'فشل كلوي'],
    ['nephro', 'renal', 'urolog', 'internal', 'كلى'],
  ),
  _ConditionHint(
    [
      'arthritis',
      'joint',
      'knee pain',
      'back pain',
      'osteoporosis',
      'fracture',
      'عظام',
      'ركبة',
      'مفصل',
    ],
    ['ortho', 'orthoped', 'bone', 'joint', 'spine', 'روماتيزم', 'عظام'],
  ),
  _ConditionHint(
    [
      'depression',
      'anxiety',
      'mental health',
      'psychiat',
      'اكتئاب',
      'قلق',
      'نفسي',
    ],
    ['psychiat', 'psycholog', 'mental', 'behavior', 'نفس', 'عام'],
  ),
  _ConditionHint(
    [
      'pregnancy',
      'pregnant',
      'obstetric',
      'gynec',
      'fertility',
      'حمل',
      'نساء',
      'ولادة',
    ],
    ['gynec', 'obstetr', 'women', 'maternity', 'نساء', 'توليد'],
  ),
  _ConditionHint(
    ['child', 'infant', 'pediatric', 'newborn', 'طفل', 'أطفال', 'رضيع'],
    ['pediat', 'child', 'infant', 'neonat', 'أطفال'],
  ),
  _ConditionHint(
    ['dental', 'tooth', 'teeth', 'gum', 'أسنان', 'سن'],
    ['dental', 'dentist', 'orthodont', 'أسنان'],
  ),
];

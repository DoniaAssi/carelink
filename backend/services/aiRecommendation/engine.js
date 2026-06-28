/**
 * CareLink — local explainable AI recommendation (hybrid content-based scoring).
 *
 * Why this is "AI": automated ranking from multiple patient/provider signals with
 * explicit sub-scores and tunable weights (transparent decision support).
 *
 * Why weighted rules vs ML: interpretable for healthcare demos/regulators; no
 * training data requirement; cold-start friendly via profile + request text.
 *
 * Cold start: historyWeight = 0 until visit/rating/report signals exist.
 * Over time: uploaded reports and visit outcomes increase history + medical blob.
 */

/** @param {number} rating aggregated provider rating (0 = no ratings yet → neutral 3/5). */
function calculateRatingScore(rating) {
  const raw = rating > 0 ? rating : 3;
  return Math.max(0, Math.min(5, raw)) / 5;
}

/** @param {number | null | undefined} experienceYears */
function calculateExperienceScore(experienceYears) {
  const y = experienceYears == null ? 0 : experienceYears;
  if (y >= 10) return 1;
  if (y >= 5) return 0.8;
  if (y >= 2) return 0.6;
  return 0.4;
}

/** @param {number} distanceKm */
function calculateLocationScore(distanceKm) {
  if (distanceKm <= 1) return 1;
  if (distanceKm <= 3) return 0.8;
  if (distanceKm <= 5) return 0.6;
  if (distanceKm <= 10) return 0.4;
  return 0.2;
}

function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}

/**
 * @param {{ lat: number, lng: number }} patient
 * @param {{ lat: number, lng: number }} provider
 */
function calculateDistance(patient, provider) {
  return haversineKm(patient.lat, patient.lng, provider.lat, provider.lng);
}

function calculateSpecializationScore(requestedService, provider, patientBlob, hasRawQuery = false) {
  const req = (requestedService || '').trim().toLowerCase();
  const spec = (provider.specialization || '').trim().toLowerCase();
  const role = String(provider.role || '').trim().toLowerCase();

  if (role === 'nurse') {
    const combinedText = `${role} ${provider.serviceType || ''} ${provider.specialization || ''}`.toLowerCase();
    if (!req && !hasRawQuery) return combinedText.length > 0 ? 0.55 : 0.35;
    if (!req && hasRawQuery) return 0;
    
    // Explicit nurse matching
    if (req.includes('nurse') || req.includes('home nursing')) return 1;
    if (combinedText.includes(req) || req.split(/\\s+/).some(w => w.length >= 4 && combinedText.includes(w))) return 0.9;
    if (weakSpecialtyMatch(req, combinedText)) return 0.5;
    if (patientBlob.includes('wound') || patientBlob.includes('post surgery')) return 0.8;
    return 0.3; // Base score for nurses when not explicitly matched but requested something
  }

  // Doctor logic
  if (!req && !hasRawQuery) return spec ? 0.55 : 0.35;
  if (!req && hasRawQuery) return 0;
  if (!spec) return 0;
  if (spec === req || spec.includes(req) || req.includes(spec)) return 1;
  if (relatedSpecialtyMatch(req, spec, patientBlob)) return 0.7;
  if (weakSpecialtyMatch(req, spec)) return 0.3;
  for (const t of req.split(/\s+/)) {
    if (t.length >= 3 && spec.includes(t)) return 0.7;
  }
  return 0;
}

function relatedSpecialtyMatch(req, spec, patientBlob) {
  const related = {
    cardio: ['internal', 'general', 'heart', 'blood', 'vascular'],
    heart: ['cardio', 'internal', 'general'],
    lung: ['pulmon', 'chest', 'respir', 'general', 'internal'],
    respir: ['pulmon', 'lung', 'chest'],
    diabet: ['endocrin', 'internal', 'general', 'family'],
    dental: ['dent', 'orthodont'],
    psych: ['mental', 'behavior', 'psycholog'],
    covid: ['pulmon', 'general', 'internal', 'lung'],
    surgery: ['surgeon', 'ortho', 'general'],
    general: ['family', 'gp', 'internal'],
  };
  for (const [key, hints] of Object.entries(related)) {
    if (req.includes(key)) {
      for (const h of hints) {
        if (spec.includes(h)) return true;
      }
    }
  }
  if (patientBlob.includes('heart') && spec.includes('cardio')) return true;
  if (patientBlob.includes('diabet') && (spec.includes('internal') || spec.includes('general')))
    return true;
  return false;
}

function weakSpecialtyMatch(req, spec) {
  return spec.split(/[^a-z]+/).some((w) => w.length > 3 && req.includes(w));
}

const WEEKDAYS = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
];

function parseMinutes(timeStr) {
  const p = (timeStr || '').split(':');
  if (p.length < 2) return null;
  const h = parseInt(p[0], 10);
  const m = parseInt(p[1], 10);
  if (Number.isNaN(h) || Number.isNaN(m)) return null;
  return h * 60 + m;
}

/**
 * @param {Date | null | undefined} requestedDateTime
 * @param {Array<{ day: string, startTime: string, endTime: string }>} slots
 */
function calculateAvailabilityScore(requestedDateTime, slots) {
  if (!slots || slots.length === 0) return 0;
  if (!requestedDateTime) return slots.length >= 2 ? 0.55 : 0.4;

  const weekdayName = WEEKDAYS[requestedDateTime.getDay()];
  const wantMinutes = requestedDateTime.getHours() * 60 + requestedDateTime.getMinutes();

  let sameDay = null;
  let exact = null;
  for (const slot of slots) {
    const slotDay = (slot.day || '').trim().toLowerCase();
    if (slotDay !== weekdayName) continue;
    sameDay = sameDay || slot;
    const start = parseMinutes(slot.startTime) ?? 0;
    const end = parseMinutes(slot.endTime) ?? start + 240;
    if (wantMinutes >= start && wantMinutes <= end) {
      exact = slot;
      break;
    }
  }
  if (exact) return 1;
  if (sameDay) return 0.7;

  let near = null;
  const targetIdx = WEEKDAYS.indexOf(weekdayName);
  for (const slot of slots) {
    const idx = WEEKDAYS.indexOf((slot.day || '').trim().toLowerCase());
    if (idx >= 0 && Math.abs(idx - targetIdx) <= 1) {
      near = slot;
      break;
    }
  }
  if (near) return 0.4;
  return 0;
}

/**
 * @param {string} blob  lowercased clinical text + tags
 * @param {import('./types').Provider} provider
 */
function calculateMedicalCompatibilityScore(blob, provider, isEmergency, rawQueryStr) {
  const p = ((blob || '') + ' ' + (rawQueryStr || '')).toLowerCase();
  const spec = `${provider.specialization || ''} ${provider.serviceType || ''} ${provider.role || ''}`.toLowerCase();
  let score = 0.25;

  function any(blobText, terms) {
    return terms.some((t) => blobText.includes(t));
  }

  if (isEmergency) {
    if (String(provider.role || '').toLowerCase() === 'doctor') {
      if (any(p, ['heart', 'cardiac', 'chest pain', 'breathe', 'stroke'])) {
        if (any(spec, ['cardio', 'pulmon', 'emergency'])) score = Math.max(score, 1.0);
        else if (any(spec, ['internal', 'general', 'family'])) score = Math.max(score, 0.85);
        else score = Math.max(score, 0.6);
      } else {
        if (any(spec, ['general', 'family', 'internal', 'emergency'])) score = Math.max(score, 0.9);
        else score = Math.max(score, 0.7);
      }
    } else {
      score = Math.max(score, 0.2); // Nurses are low priority for emergency unless specifically requested
    }
  } else {
    if (any(p, ['diabet', 'hba1c', 'insulin', 'glucose', 'blood sugar', 'endocrin'])) {
      if (any(spec, ['endocrin'])) score = Math.max(score, 1.0);
      else if (any(spec, ['internal', 'general', 'family'])) score = Math.max(score, 0.8);
    }
    if (any(p, ['heart', 'cardiac', 'angina', 'chest pain', 'hypertens', 'cholesterol', 'ldl', 'cardiovascular', 'blood pressure'])) {
      if (any(spec, ['cardio', 'heart', 'internal', 'cardiovascular'])) score = Math.max(score, 1.0);
    }
    if (any(p, ['fever', 'sick', 'temperature'])) {
      if (any(spec, ['general', 'family', 'gp', 'internal'])) score = Math.max(score, 0.95);
    }
    if (any(p, ['blood pressure monitoring', 'glucose monitoring', 'medication adherence', 'home nursing', 'wound', 'elderly', 'post surgery', 'post-operative', 'home_nursing', 'wound_care', 'post_surgery_care', 'elderly_care', 'stitch', 'cut', 'dressing', 'injection'])) {
      if (any(spec, ['nurs', 'home', 'wound', 'home care', 'home nursing', 'injection']) || String(provider.role || '').toLowerCase() === 'nurse') {
        score = Math.max(score, 1.0);
      }
    }
    if (any(p, ['asthma', 'copd', 'lung', 'respir', 'cough'])) {
      if (any(spec, ['pulmon', 'lung', 'chest', 'respir'])) score = Math.max(score, 1.0);
      else if (any(spec, ['internal', 'general', 'family'])) score = Math.max(score, 0.8);
    }
    if (any(p, ['dental', 'tooth', 'teeth']) && any(spec, ['dent'])) score = Math.max(score, 1.0);
    if (any(p, ['anxiety', 'depression', 'psych']) && any(spec, ['psych', 'mental'])) score = Math.max(score, 1.0);
    if (any(p, ['diabet', 'hypertens', 'cholesterol']) && any(spec, ['family', 'general', 'gp'])) score = Math.max(score, 0.8);
  }

  return Math.min(1, Math.max(0, score));
}

/**
 * @param {import('./types').PatientProfile} patient
 * @param {import('./types').Provider} provider
 */
function calculateHistoryScore(patient, provider) {
  if (!patient.hasHistoryForWeighting) return 0;

  let s = 0;
  const id = provider.id;
  const rating = patient.previousProviderRatings && patient.previousProviderRatings[id];
  if (rating != null && rating >= 4.5) s += 0.55;
  if (rating != null && rating >= 4) s += 0.15;

  const success = patient.successfulVisitProviderIds || [];
  if (success.includes(id)) s += 0.25;

  for (const report of patient.visitReportTexts || []) {
    const r = report.toLowerCase();
    if (r.includes('improve')) s += 0.12;
    if (r.includes('follow') && (r.includes(provider.specialization.toLowerCase()) || r.includes('cardio')))
      s += 0.35;
  }

  for (const hint of patient.followUpHints || []) {
    if (provider.specialization.toLowerCase().includes(String(hint).toLowerCase())) s += 0.3;
  }

  return Math.min(1, Math.max(0, s));
}

/** @typedef {ReturnType<typeof normalizeWeights>} Weights */

/** @type {Weights} */
const COLD_START_WEIGHTS = normalizeWeights({
  locationWeight: 0.1,
  specializationWeight: 0.2,
  availabilityWeight: 0.1,
  ratingWeight: 0.1,
  experienceWeight: 0,
  medicalCompatibilityWeight: 0.5,
  historyWeight: 0,
});

function withHistoryWeights(base) {
  return normalizeWeights(base);
}

function normalizeWeights(w) {
  const sum =
    w.locationWeight +
    w.specializationWeight +
    w.availabilityWeight +
    w.ratingWeight +
    w.experienceWeight +
    w.medicalCompatibilityWeight +
    w.historyWeight;
  if (sum <= 0) return { ...COLD_START_WEIGHTS };
  return {
    locationWeight: w.locationWeight / sum,
    specializationWeight: w.specializationWeight / sum,
    availabilityWeight: w.availabilityWeight / sum,
    ratingWeight: w.ratingWeight / sum,
    experienceWeight: w.experienceWeight / sum,
    medicalCompatibilityWeight: w.medicalCompatibilityWeight / sum,
    historyWeight: w.historyWeight / sum,
  };
}

function getDynamicWeights(request, patient) {
  return { ...COLD_START_WEIGHTS };
}

/**
 * Map analysis tags to patient-friendly care need labels.
 */
const TAG_LABELS = {
  diabetes: 'Diabetes follow-up',
  hypertension: 'Hypertension management',
  cholesterol: 'Cholesterol management',
  cardiovascular_risk: 'Cardiovascular risk monitoring',
  cardiology: 'Cardiology evaluation',
  endocrinology: 'Endocrinology follow-up',
  blood_pressure_monitoring: 'Blood pressure monitoring',
  home_nursing: 'Home nursing support',
  wound_care: 'Wound care',
  post_surgery_care: 'Post-surgery care',
  elderly_care: 'Elderly care',
  medication_followup: 'Medication monitoring',
};

/**
 * Map provider specialty keywords to the tags they address.
 */
const SPECIALTY_TAG_MAP = {
  endocrin: ['diabetes', 'endocrinology', 'medication_followup'],
  cardio: ['hypertension', 'cholesterol', 'cardiovascular_risk', 'cardiology', 'blood_pressure_monitoring'],
  internal: ['hypertension', 'cholesterol', 'diabetes', 'cardiovascular_risk'],
  nurs: ['blood_pressure_monitoring', 'home_nursing', 'wound_care', 'medication_followup', 'elderly_care'],
  home: ['blood_pressure_monitoring', 'home_nursing', 'wound_care', 'medication_followup', 'elderly_care'],
  wound: ['wound_care', 'post_surgery_care'],
  family: ['diabetes', 'hypertension', 'medication_followup'],
  general: ['diabetes', 'hypertension', 'medication_followup'],
};

function buildTagMatchedReasonLines(provider, patientTags) {
  if (!patientTags || patientTags.length === 0) return [];
  const spec = `${provider.specialization || ''} ${provider.serviceType || ''} ${provider.role || ''}`.toLowerCase();

  // Find which tags this provider's specialty covers
  const matchedTags = [];
  for (const [keyword, tags] of Object.entries(SPECIALTY_TAG_MAP)) {
    if (spec.includes(keyword)) {
      for (const tag of tags) {
        if (patientTags.includes(tag) && !matchedTags.includes(tag)) {
          matchedTags.push(tag);
        }
      }
    }
  }

  if (matchedTags.length === 0) return [];

  const labels = matchedTags.map((t) => TAG_LABELS[t] || t).filter(Boolean);
  return labels;
}

function buildReasonLines(provider, breakdown, distanceKm, patientTags, isEmergency) {
  const lines = [];
  if (isEmergency) {
    if (String(provider.role || '').toLowerCase() === 'doctor') lines.push('Emergency-capable physician.');
  }

  if (breakdown.medicalCompatibility >= 0.8) lines.push('Best medical match.');
  else if (breakdown.medicalCompatibility >= 0.5) lines.push('Strong medical match.');
  
  if (breakdown.specialization >= 0.8) lines.push('Service matches your request.');
  if (breakdown.availability >= 0.85) lines.push('Available for booking.');
  if (provider.rating >= 4.2) lines.push('Highly rated.');
  if (distanceKm <= 5) lines.push('Nearby location.');
  
  // Dedup and limit to top 4
  return [...new Set(lines)].slice(0, 4);
}

/**
 * @param {import('./types').PatientProfile} patient
 * @param {import('./types').RecommendationRequest} request
 * @param {import('./types').Provider[]} providers
 * @param {number} [top]
 */
function recommendProviders(patient, request, providers, top = 12) {
  if (!providers || providers.length === 0) return [];

  const weights = getDynamicWeights(request, patient);
  const plat = patient.locationLatitude ?? 31.9539;
  const plng = patient.locationLongitude ?? 35.9106;
  const patientPoint = { lat: plat, lng: plng };

  const rawQueryStr = (request.rawQuery || '').trim();
  const hasRawQuery = rawQueryStr.length > 0;
  const blob = patientCareBlob(patient);
  const keyword = (request.requestedServiceKeyword || '').trim();

  /** @type {import('./types').AIRecommendationResult[]} */
  const out = [];

  for (const provider of providers) {
    // Note: Availability and booking eligibility (isActive, price, slots, etc.)
    // MUST be strictly enforced by the caller (e.g., using providerCanBeBooked).
    // The engine solely ranks the provided list and does not invent availability rules.
    const pLat = provider.locationLatitude ?? plat;
    const pLng = provider.locationLongitude ?? plng;
    const dist = calculateDistance(patientPoint, { lat: pLat, lng: pLng });
    const ls = calculateLocationScore(dist);

    const ss = calculateSpecializationScore(keyword, provider, blob, hasRawQuery);

    // STRICT REJECTION: Do not return generic providers for unsupported/random queries
    if (hasRawQuery && ss === 0) {
      continue;
    }
    const as = calculateAvailabilityScore(request.requestedDateTime ?? null, provider.availableSlots || []);
    const rs = calculateRatingScore(provider.rating);
    const es = calculateExperienceScore(provider.experienceYears);
    const ms = calculateMedicalCompatibilityScore(blob, provider, request.isEmergency, rawQueryStr);
    const hs = 0; // History score unused based on new weights

    // ENFORCE MEDICAL MINIMUM THRESHOLD (Medical logic)
    if (ms < 0.3) {
      continue;
    }

    const finalScoreVal =
      ls * weights.locationWeight +
      ss * weights.specializationWeight +
      as * weights.availabilityWeight +
      rs * weights.ratingWeight +
      es * weights.experienceWeight +
      ms * weights.medicalCompatibilityWeight +
      hs * weights.historyWeight;

    const matchPercentage = Math.round(finalScoreVal * 100);

    const reasons = buildReasonLines(
      provider,
      {
        location: ls,
        specialization: ss,
        availability: as,
        rating: rs,
        experience: es,
        medicalCompatibility: ms,
        history: hs,
      },
      dist,
      patient.analysisTags,
      request.isEmergency
    );

    const aiMatchReason = reasons[0] || '';

    out.push({
      providerId: provider.id,
      provider,
      finalScore: Number(finalScoreVal.toFixed(3)),
      matchPercentage,
      scoreBreakdown: {
        location: ls,
        specialization: ss,
        availability: as,
        rating: rs,
        experience: es,
        medicalCompatibility: ms,
        history: hs,
      },
      weights,
      recommendationReasons: reasons,
      matchedTags: buildTagMatchedReasonLines(provider, patient.analysisTags || []),
      aiMatchReason,
      confidenceScore: matchPercentage,
    });
  }

  out.sort((a, b) => b.finalScore - a.finalScore);
  return out.slice(0, top);
}

function patientCareBlob(patient) {
  const parts = [
    ...(patient.chronicDiseases || []),
    ...(patient.allergies || []),
    ...(patient.medications || []),
    ...(patient.previousSurgeries || []),
    patient.careSummaryText || '',
    ...(patient.visitReportTexts || []),
    // AI Integration Fields (Optional / Backward Compatible)
    ...(patient.aiSummaries || []),
    ...(patient.ocrTexts || []),
    ...(patient.analysisTags || []),
  ];
  return parts.join(' ').toLowerCase();
}

function inferKeyword(request, providers = []) {
  const q = (request.rawQuery || '').toLowerCase();
  if (!q.trim()) return '';

  const map = {
    'cardiology': 'cardiology',
    'cardio': 'cardiology',
    'dentist': 'dental',
    'dental': 'dental',
    'psych': 'psych',
    'lung': 'lung',
    'covid': 'covid',
    'surgeon': 'surgery',
    'surgery': 'surgery',
    'general': 'general',
    'home nursing': 'home nursing',
    'home nurse': 'home nursing',
    'elderly': 'elderly',
    'post-surgery': 'post-surgery',
    'post surgery': 'post-surgery',
    'physio': 'physio',
    'mental': 'mental',
    'nurse': 'nurse',
    'wound': 'wound',
    'doctor': 'doctor'
  };

  for (const [k, v] of Object.entries(map)) {
    if (q.includes(k)) return v;
  }

  for (const p of providers) {
    if (p.specialization && q.includes(p.specialization.toLowerCase())) return p.specialization.toLowerCase();
    if (p.serviceType && q.includes(p.serviceType.toLowerCase())) return p.serviceType.toLowerCase();
    if (p.role && q.includes(p.role.toLowerCase())) return p.role.toLowerCase();
  }

  return q.trim();
}

module.exports = {
  calculateDistance,
  calculateLocationScore,
  calculateSpecializationScore,
  calculateAvailabilityScore,
  calculateRatingScore,
  calculateExperienceScore,
  calculateMedicalCompatibilityScore,
  calculateHistoryScore,
  getDynamicWeights,
  recommendProviders,
  normalizeWeights,
  COLD_START_WEIGHTS,
  TAG_LABELS,
  buildTagMatchedReasonLines,
};

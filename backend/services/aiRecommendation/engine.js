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

/**
 * @param {string} requestedService
 * @param {string} providerSpecialty
 * @param {string} patientBlob lowercased clinical text
 */
function calculateSpecializationScore(requestedService, providerSpecialty, patientBlob) {
  const req = (requestedService || '').trim().toLowerCase();
  const spec = (providerSpecialty || '').trim().toLowerCase();
  if (!req) return spec ? 0.55 : 0.35;
  if (!spec) return 0.25;
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
 * @param {string} blob
 * @param {import('./types').Provider} provider
 */
function calculateMedicalCompatibilityScore(blob, provider) {
  const p = blob || '';
  if (!p.trim()) return 0.45;
  const spec = `${provider.specialization} ${provider.serviceType} ${provider.role}`.toLowerCase();
  let score = 0.45;

  function any(blobText, terms) {
    return terms.some((t) => blobText.includes(t));
  }

  if (any(p, ['heart', 'cardiac', 'angina', 'hypertens', 'chest pain']) && any(spec, ['cardio', 'heart']))
    score = 0.95;
  else if (any(p, ['diabet', 'insulin', 'glucose']) && any(spec, ['internal', 'general', 'endocrin', 'family']))
    score = Math.max(score, 0.9);
  else if (
    any(p, ['post surgery', 'surgery', 'wound', 'stitch']) &&
    (any(spec, ['nurs', 'wound', 'surgery', 'home']) || String(provider.role).toLowerCase() === 'nurse')
  )
    score = Math.max(score, 0.92);
  else if (any(p, ['asthma', 'copd', 'lung', 'respir']) && any(spec, ['pulmon', 'lung', 'chest', 'respir']))
    score = Math.max(score, 0.9);
  else if (any(p, ['dental', 'tooth', 'teeth']) && any(spec, ['dent']))
    score = Math.max(score, 0.93);
  else if (any(p, ['anxiety', 'depression', 'psych']) && any(spec, ['psych', 'mental']))
    score = Math.max(score, 0.9);

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
  locationWeight: 0.2,
  specializationWeight: 0.25,
  availabilityWeight: 0.2,
  ratingWeight: 0.15,
  experienceWeight: 0.1,
  medicalCompatibilityWeight: 0.1,
  historyWeight: 0,
});

function withHistoryWeights(base) {
  const h = 0.15;
  const scale = 1 - h;
  return normalizeWeights({
    locationWeight: base.locationWeight * scale,
    specializationWeight: base.specializationWeight * scale,
    availabilityWeight: base.availabilityWeight * scale,
    ratingWeight: base.ratingWeight * scale,
    experienceWeight: base.experienceWeight * scale,
    medicalCompatibilityWeight: base.medicalCompatibilityWeight * scale,
    historyWeight: h,
  });
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

/**
 * @param {import('./types').RecommendationRequest} request
 * @param {import('./types').PatientProfile} patient
 */
function getDynamicWeights(request, patient) {
  let w = patient.hasHistoryForWeighting ? withHistoryWeights(COLD_START_WEIGHTS) : { ...COLD_START_WEIGHTS };

  if (request.isUrgent) {
    w = normalizeWeights({
      locationWeight: w.locationWeight * 1.55,
      specializationWeight: w.specializationWeight * 0.95,
      availabilityWeight: w.availabilityWeight * 1.55,
      ratingWeight: w.ratingWeight * 0.9,
      experienceWeight: w.experienceWeight * 0.9,
      medicalCompatibilityWeight: w.medicalCompatibilityWeight * 1.05,
      historyWeight: w.historyWeight * 0.85,
    });
  } else if (request.isComplexCase) {
    w = normalizeWeights({
      locationWeight: w.locationWeight * 0.9,
      specializationWeight: w.specializationWeight * 1.35,
      availabilityWeight: w.availabilityWeight * 0.9,
      ratingWeight: w.ratingWeight * 0.92,
      experienceWeight: w.experienceWeight * 1.35,
      medicalCompatibilityWeight: w.medicalCompatibilityWeight * 1.4,
      historyWeight: w.historyWeight * 1.05,
    });
  } else {
    w = normalizeWeights({
      ...w,
      ratingWeight: w.ratingWeight * 1.18,
    });
  }
  return w;
}

function buildReasonLines(provider, breakdown, distanceKm) {
  const lines = [];
  if (provider.specialization && provider.specialization.trim()) {
    lines.push(`Matches specialty "${provider.specialization}".`);
  }
  if (distanceKm <= 10) {
    lines.push(`Within ${Math.round(distanceKm * 1000)} m — strong proximity score.`);
  }
  if (breakdown.availability >= 0.85) lines.push('Available around your requested time window.');
  else if (breakdown.availability >= 0.55) lines.push('Partial availability alignment.');
  if (provider.rating >= 4.2) lines.push(`Highly rated (${provider.rating.toFixed(1)}/5).`);
  if ((provider.experienceYears ?? 0) >= 8) lines.push(`Experienced clinician (~${provider.experienceYears} yrs).`);
  if (breakdown.medicalCompatibility >= 0.85) lines.push('Strong medical-profile compatibility.');
  if (breakdown.history >= 0.55) lines.push('Boosted by prior visits / follow-up plan.');
  const body = [];
  if (provider.specialization) body.push(`they are a ${provider.specialization}`);
  if (breakdown.availability >= 0.69) body.push('fit your requested schedule');
  if (distanceKm < 1) body.push(`are only ${Math.round(distanceKm * 1000)} m away`);
  if (provider.rating > 0) body.push(`have a ${provider.rating.toFixed(1)} patient rating`);
  if (body.length)
    lines.unshift(`${provider.fullName} is recommended because ${body.join(', ')}.`);
  return lines;
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

  const blob = patientCareBlob(patient);
  const keyword = (request.requestedServiceKeyword || inferKeyword(request)).trim();

  /** @type {import('./types').AIRecommendationResult[]} */
  const out = [];

  for (const provider of providers) {
    const pLat = provider.locationLatitude ?? plat;
    const pLng = provider.locationLongitude ?? plng;
    const dist = calculateDistance(patientPoint, { lat: pLat, lng: pLng });
    const ls = calculateLocationScore(dist);
    const ss = calculateSpecializationScore(keyword, provider.specialization, blob);
    const as = calculateAvailabilityScore(request.requestedDateTime ?? null, provider.availableSlots || []);
    const rs = calculateRatingScore(provider.rating);
    const es = calculateExperienceScore(provider.experienceYears);
    const ms = calculateMedicalCompatibilityScore(blob, provider);
    const hs = calculateHistoryScore(patient, provider);

    const breakdown = {
      location: ls,
      specialization: ss,
      availability: as,
      rating: rs,
      experience: es,
      medicalCompatibility: ms,
      history: hs,
    };

    const finalScore =
      ls * weights.locationWeight +
      ss * weights.specializationWeight +
      as * weights.availabilityWeight +
      rs * weights.ratingWeight +
      es * weights.experienceWeight +
      ms * weights.medicalCompatibilityWeight +
      hs * weights.historyWeight;

    const matchPct = Math.min(99, Math.max(0, Math.round(finalScore * 100)));
    const reasons = buildReasonLines(provider, breakdown, dist);

    out.push({
      providerId: provider.id,
      provider,
      finalScore,
      matchPercentage: matchPct,
      scoreBreakdown: breakdown,
      weights,
      recommendationReasons: reasons,
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
  ];
  return parts.join(' ').toLowerCase();
}

function inferKeyword(request) {
  const q = (request.rawQuery || '').toLowerCase();
  const keys = [
    'cardiology',
    'cardio',
    'dentist',
    'dental',
    'psych',
    'lung',
    'covid',
    'surgeon',
    'surgery',
    'general',
  ];
  for (const k of keys) {
    if (q.includes(k)) return k === 'cardio' ? 'cardiology' : k;
  }
  return '';
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
};

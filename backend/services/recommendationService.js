'use strict';

const db = require('../db');
const { recommendProviders, TAG_LABELS, buildTagMatchedReasonLines } = require('./aiRecommendation/engine');

// ---------- helpers ----------

async function hasColumn(table, col) {
  try {
    const [rows] = await db.query(`SHOW COLUMNS FROM ${table} LIKE ?`, [col]);
    return rows.length > 0;
  } catch (_) {
    return false;
  }
}

async function tableExists(name) {
  const [rows] = await db.query('SHOW TABLES LIKE ?', [name]);
  return rows.length > 0;
}

function safeJson(value, fallback = []) {
  if (!value) return fallback;
  if (Array.isArray(value)) return value;
  try { return JSON.parse(value); } catch (_) { return fallback; }
}

// ---------- fetch patient ----------

async function fetchPatientProfile(patientUserId) {
  const hasChronic = await hasColumn('patient', 'chronicDiseases');
  const hasAllergies = await hasColumn('patient', 'allergies');
  const hasMeds = await hasColumn('patient', 'currentMedications');
  const hasLat = await hasColumn('patient', 'locationLatitude');
  const hasLng = await hasColumn('patient', 'locationLongitude');

  const [rows] = await db.query(
    `SELECT
       u.userId,
       u.fullName,
       u.email,
       ${hasChronic    ? 'p.chronicDiseases'   : 'NULL AS chronicDiseases'},
       ${hasAllergies  ? 'p.allergies'          : 'NULL AS allergies'},
       ${hasMeds       ? 'p.currentMedications' : 'NULL AS currentMedications'},
       ${hasLat        ? 'p.locationLatitude'   : 'NULL AS locationLatitude'},
       ${hasLng        ? 'p.locationLongitude'  : 'NULL AS locationLongitude'}
     FROM user u
     LEFT JOIN patient p ON BINARY p.userId = BINARY u.userId
     WHERE BINARY u.userId = BINARY ?
     LIMIT 1`,
    [patientUserId]
  );
  return rows[0] ?? null;
}

// ---------- fetch patient's processed medical records ----------

async function fetchPatientMedicalContext(patientUserId) {
  if (!(await tableExists('patientmedicalfile'))) return { aiSummaries: [], ocrTexts: [], analysisTags: [] };

  const [rows] = await db.query(
    `SELECT aiSummary, ocrText, analysisTags
     FROM patientmedicalfile
     WHERE BINARY patientUserId = BINARY ?
       AND aiStatus = 'processed'
       AND aiProcessed = 1
     ORDER BY uploadDate DESC
     LIMIT 20`,
    [patientUserId]
  );

  const aiSummaries = [];
  const ocrTexts = [];
  const allTags = [];

  for (const row of rows) {
    if (row.aiSummary) aiSummaries.push(row.aiSummary);
    if (row.ocrText && row.ocrText.length < 4000) ocrTexts.push(row.ocrText);
    const tags = safeJson(row.analysisTags, []);
    for (const t of tags) {
      if (!allTags.includes(t)) allTags.push(t);
    }
  }

  return { aiSummaries, ocrTexts, analysisTags: allTags };
}

// ---------- fetch providers ----------

async function fetchProviders() {
  const hasServiceType    = await hasColumn('careprovider', 'serviceType');
  const hasExperience     = await hasColumn('careprovider', 'experienceYears');
  const hasRating         = await hasColumn('careprovider', 'overallRating');
  const hasRatingsCount   = await hasColumn('careprovider', 'ratingsCount');
  const hasFee            = await hasColumn('careprovider', 'consultationFee');
  const hasAvailable      = await hasColumn('careprovider', 'isAvailable');
  const hasLat            = await hasColumn('careprovider', 'gpsLat');
  const hasLng            = await hasColumn('careprovider', 'gpsLng');
  const hasAddress        = await hasColumn('careprovider', 'providerAddress');
  const hasBio            = await hasColumn('careprovider', 'shortBio');

  const [rows] = await db.query(
    `SELECT
       u.userId AS id,
       u.fullName,
       u.email,
       u.role,
       u.profileImageUrl,
       c.specialization,
       ${hasServiceType  ? 'c.serviceType'          : "'' AS serviceType"},
       ${hasExperience   ? 'c.experienceYears'       : '0 AS experienceYears'},
       ${hasRating       ? 'c.overallRating'         : '0 AS overallRating'},
       ${hasRatingsCount ? 'c.ratingsCount'          : '0 AS ratingsCount'},
       ${hasFee          ? 'c.consultationFee'       : 'NULL AS consultationFee'},
       ${hasAvailable    ? 'c.isAvailable'           : '1 AS isAvailable'},
       ${hasLat          ? 'c.gpsLat'                : 'NULL AS gpsLat'},
       ${hasLng          ? 'c.gpsLng'                : 'NULL AS gpsLng'},
       ${hasAddress      ? 'c.providerAddress'       : 'NULL AS providerAddress'},
       ${hasBio          ? 'c.shortBio'              : 'NULL AS shortBio'}
     FROM user u
     INNER JOIN careprovider c ON BINARY c.userId = BINARY u.userId
     WHERE u.role IN ('doctor', 'nurse')
       ${hasAvailable ? "AND c.isAvailable = 1" : ''}
     ORDER BY ${hasRating ? 'c.overallRating DESC' : 'u.fullName ASC'}`,
    []
  );

  return rows.map((r) => ({
    id: r.id,
    fullName: r.fullName,
    email: r.email,
    role: r.role,
    profileImageUrl: r.profileImageUrl || null,
    specialization: r.specialization || '',
    serviceType: r.serviceType || '',
    experienceYears: Number(r.experienceYears) || 0,
    rating: Number(r.overallRating) || 0,
    ratingsCount: Number(r.ratingsCount) || 0,
    consultationFee: r.consultationFee ?? null,
    isAvailable: !!r.isAvailable,
    locationLatitude: r.gpsLat ? Number(r.gpsLat) : null,
    locationLongitude: r.gpsLng ? Number(r.gpsLng) : null,
    providerAddress: r.providerAddress || null,
    shortBio: r.shortBio || '',
    availableSlots: [],
  }));
}

// ---------- build recommendation reason text ----------

function buildRecommendationReason(result) {
  const { provider, matchedTags, scoreBreakdown } = result;

  if (matchedTags && matchedTags.length > 0) {
    return `Recommended for ${matchedTags.slice(0, 3).join(', ')}, detected in your medical records.`;
  }

  const spec = provider.specialization;
  if (scoreBreakdown.medicalCompatibility >= 0.85 && spec) {
    return `Recommended based on your medical records and care needs (${spec}).`;
  }
  if (spec) {
    return `Recommended based on your care profile (${spec}).`;
  }
  return 'Recommended based on your health profile.';
}

// ---------- main entry point ----------

/**
 * Get ranked provider recommendations for a patient, using DB data.
 *
 * @param {string} patientUserId
 * @param {{ searchText?: string, top?: number }} opts
 */
async function getRecommendationsForPatient(patientUserId, opts = {}) {
  const { searchText = '', top = 12 } = opts;

  const [patientRow, medicalCtx, providers] = await Promise.all([
    fetchPatientProfile(patientUserId),
    fetchPatientMedicalContext(patientUserId),
    fetchProviders(),
  ]);

  if (!patientRow) return { error: 'Patient not found', results: [] };
  if (providers.length === 0) return { patientId: patientUserId, results: [] };

  const chronicList = patientRow.chronicDiseases
    ? [patientRow.chronicDiseases]
    : [];
  const allergiesList = patientRow.allergies
    ? [patientRow.allergies]
    : [];
  const medsList = patientRow.currentMedications
    ? [patientRow.currentMedications]
    : [];

  const patient = {
    id: patientUserId,
    fullName: patientRow.fullName,
    locationLatitude: patientRow.locationLatitude ? Number(patientRow.locationLatitude) : null,
    locationLongitude: patientRow.locationLongitude ? Number(patientRow.locationLongitude) : null,
    chronicDiseases: chronicList,
    allergies: allergiesList,
    medications: medsList,
    previousSurgeries: [],
    careSummaryText: '',
    hasHistoryForWeighting: medicalCtx.aiSummaries.length > 0 || medicalCtx.analysisTags.length > 0,
    visitReportTexts: [],
    followUpHints: [],
    successfulVisitProviderIds: [],
    previousProviderRatings: {},
    // AI-enriched fields from uploaded medical records
    aiSummaries: medicalCtx.aiSummaries,
    ocrTexts: medicalCtx.ocrTexts,
    analysisTags: medicalCtx.analysisTags,
  };

  const request = {
    rawQuery: searchText,
    requestedServiceKeyword: searchText,
    requestedDateTime: null,
    isUrgent: false,
    isComplexCase: medicalCtx.analysisTags.length >= 3,
  };

  const results = recommendProviders(patient, request, providers, top);

  return {
    patientId: patientUserId,
    medicalContext: {
      hasMedicalRecords: medicalCtx.aiSummaries.length > 0,
      detectedTags: medicalCtx.analysisTags,
      tagLabels: medicalCtx.analysisTags.map((t) => TAG_LABELS[t] || t),
    },
    results: results.map((r) => ({
      providerId: r.providerId,
      name: r.provider.fullName,
      specialization: r.provider.specialization,
      serviceType: r.provider.serviceType,
      rating: r.provider.rating,
      ratingsCount: r.provider.ratingsCount,
      experienceYears: r.provider.experienceYears,
      isAvailable: r.provider.isAvailable,
      consultationFee: r.provider.consultationFee,
      profileImageUrl: r.provider.profileImageUrl,
      providerAddress: r.provider.providerAddress,
      finalScore: r.finalScore,
      matchPercentage: r.matchPercentage,
      medicalMatchScore: r.scoreBreakdown.medicalCompatibility,
      recommendationReason: buildRecommendationReason(r),
      matchedTags: r.matchedTags || [],
      matchedTagLabels: (r.matchedTags || []).map((t) => TAG_LABELS[t] || t),
      recommendationReasons: r.recommendationReasons,
      aiMatchReason: r.aiMatchReason,
      scoreBreakdown: r.scoreBreakdown,
    })),
  };
}

module.exports = { getRecommendationsForPatient };

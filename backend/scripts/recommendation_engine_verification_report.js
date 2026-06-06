const db = require('../db');
const {
  calculateDistance,
  calculateLocationScore,
  calculateSpecializationScore,
  calculateAvailabilityScore,
  calculateRatingScore,
  calculateExperienceScore,
  calculateMedicalCompatibilityScore,
  calculateHistoryScore,
  getDynamicWeights,
} = require('../services/aiRecommendation/engine');

const TARGET_TITLE = process.argv.slice(2).join(' ').trim() || 'MEDICAL REPORT';

function asNumber(value, fallback = null) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function lower(value) {
  return (value || '').toString().toLowerCase();
}

function useful(value) {
  const text = (value || '').toString().trim();
  return text && text.toLowerCase() !== 'null';
}

function parseTags(raw) {
  if (Array.isArray(raw)) return raw;
  if (!useful(raw)) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

function patientCareBlob(patient) {
  return [
    ...(patient.chronicDiseases || []),
    ...(patient.allergies || []),
    ...(patient.medications || []),
    ...(patient.previousSurgeries || []),
    patient.careSummaryText || '',
    ...(patient.visitReportTexts || []),
    ...(patient.aiSummaries || []),
    ...(patient.ocrTexts || []),
    ...(patient.analysisTags || []),
  ]
    .join(' ')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

async function hasColumn(table, column) {
  try {
    const [rows] = await db.query(`SHOW COLUMNS FROM ${table} LIKE ?`, [column]);
    return rows.length > 0;
  } catch (_) {
    return false;
  }
}

async function loadTargetRecord() {
  const [rows] = await db.query(
    `SELECT
       id,
       patientUserId,
       title,
       mimeType,
       aiStatus,
       aiProcessed,
       ocrText,
       aiSummary,
       analysisTags,
       originalName,
       uploadDate
     FROM patientmedicalfile
     WHERE UPPER(TRIM(title)) = UPPER(TRIM(?))
        OR UPPER(title) LIKE UPPER(?)
        OR UPPER(originalName) LIKE UPPER(?)
     ORDER BY uploadDate DESC
     LIMIT 1`,
    [TARGET_TITLE, `%${TARGET_TITLE}%`, `%${TARGET_TITLE.replace(/\s+/g, '%')}%`]
  );
  return rows[0] || null;
}

async function loadPatient(patientId) {
  const hasPastSurgeries = await hasColumn('patient', 'pastSurgeries');
  const hasPreviousSurgeries = await hasColumn('patient', 'previousSurgeries');
  const surgerySelect = hasPastSurgeries
    ? 'pastSurgeries'
    : hasPreviousSurgeries
      ? 'previousSurgeries'
      : "'' AS pastSurgeries";

  const [patients] = await db.query(
    `SELECT gpsLat, gpsLng, chronicDiseases, allergies, currentMedications, ${surgerySelect}
     FROM patient
     WHERE BINARY userId = BINARY ?
     LIMIT 1`,
    [patientId]
  );
  return patients[0] || {};
}

async function loadProviders() {
  const hasExp = await hasColumn('careprovider', 'experienceYears');
  const hasService = await hasColumn('careprovider', 'serviceType');
  const hasRc = await hasColumn('careprovider', 'ratingsCount');
  const hasLat = await hasColumn('careprovider', 'gpsLat');
  const hasLng = await hasColumn('careprovider', 'gpsLng');

  const [rows] = await db.query(
    `SELECT
       u.userId,
       u.fullName,
       u.role,
       c.specialization,
       ${hasService ? 'c.serviceType' : "'' AS serviceType"},
       c.overallRating,
       ${hasRc ? 'COALESCE(c.ratingsCount, 0)' : '0'} AS ratingsCount,
       c.isAvailable,
       ${hasExp ? 'c.experienceYears' : 'NULL'} AS experienceYears,
       ${hasLat ? 'c.gpsLat' : 'NULL'} AS gpsLat,
       ${hasLng ? 'c.gpsLng' : 'NULL'} AS gpsLng
     FROM user u
     JOIN careprovider c ON c.userId = u.userId
     WHERE u.role IN ('doctor', 'nurse')`
  );

  const providers = [];
  for (const row of rows) {
    const [slots] = await db.query(
      `SELECT day, startTime, endTime
       FROM availabilityslot
       WHERE providerUserId = ?
       ORDER BY day, startTime`,
      [row.userId]
    );
    providers.push({
      id: row.userId,
      fullName: row.fullName || '',
      role: row.role || '',
      specialization: row.specialization || '',
      serviceType: row.serviceType || '',
      rating: asNumber(row.overallRating, 0) || 0,
      ratingsCount: asNumber(row.ratingsCount, 0) || 0,
      isAvailable: row.isAvailable === 1 || row.isAvailable === true,
      experienceYears: asNumber(row.experienceYears, 0),
      locationLatitude: asNumber(row.gpsLat),
      locationLongitude: asNumber(row.gpsLng),
      availableSlots: slots,
    });
  }
  return providers;
}

function scoreProviders(patient, providers, request) {
  const weights = getDynamicWeights(request, patient);
  const plat = patient.locationLatitude ?? 31.9539;
  const plng = patient.locationLongitude ?? 35.9106;
  const blob = patientCareBlob(patient);
  const emptyPatient = { ...patient, aiSummaries: [], ocrTexts: [], analysisTags: [] };
  const blobWithoutRecord = patientCareBlob(emptyPatient);
  const keyword = (request.requestedServiceKeyword || '').trim();

  return providers
    .map((provider) => {
      const pLat = provider.locationLatitude ?? plat;
      const pLng = provider.locationLongitude ?? plng;
      const distanceKm = calculateDistance(
        { lat: plat, lng: plng },
        { lat: pLat, lng: pLng }
      );
      const locationScore = calculateLocationScore(distanceKm);
      const specializationScore = calculateSpecializationScore(keyword, provider.specialization, blob);
      const availabilityScore = calculateAvailabilityScore(request.requestedDateTime ?? null, provider.availableSlots || []);
      const ratingScore = calculateRatingScore(provider.rating);
      const experienceScore = calculateExperienceScore(provider.experienceYears);
      const medicalScore = calculateMedicalCompatibilityScore(blob, provider);
      const medicalScoreWithoutRecord = calculateMedicalCompatibilityScore(blobWithoutRecord, provider);
      const historyScore = calculateHistoryScore(patient, provider);
      const baseScore =
        locationScore * weights.locationWeight +
        specializationScore * weights.specializationWeight +
        availabilityScore * weights.availabilityWeight +
        ratingScore * weights.ratingWeight +
        experienceScore * weights.experienceWeight +
        historyScore * weights.historyWeight;
      const medicalContribution = medicalScore * weights.medicalCompatibilityWeight;
      const finalScore = baseScore + medicalContribution;
      return {
        provider,
        distanceKm,
        finalScore,
        baseScore,
        locationScore,
        ratingScore,
        experienceScore,
        medicalScore,
        medicalContribution,
        medicalDeltaFromRecord: medicalScore - medicalScoreWithoutRecord,
        specializationScore,
        availabilityScore,
        historyScore,
        weights,
      };
    })
    .sort((a, b) => b.finalScore - a.finalScore);
}

async function main() {
  const record = await loadTargetRecord();
  if (!record) {
    throw new Error(`No uploaded medical record found with title "${TARGET_TITLE}".`);
  }

  const tags = parseTags(record.analysisTags);
  const patientRow = await loadPatient(record.patientUserId);
  const patient = {
    id: record.patientUserId,
    locationLatitude: asNumber(patientRow.gpsLat, 31.9539),
    locationLongitude: asNumber(patientRow.gpsLng, 35.9106),
    chronicDiseases: useful(patientRow.chronicDiseases) ? [patientRow.chronicDiseases] : [],
    allergies: useful(patientRow.allergies) ? [patientRow.allergies] : [],
    medications: useful(patientRow.currentMedications) ? [patientRow.currentMedications] : [],
    previousSurgeries: useful(patientRow.pastSurgeries) ? [patientRow.pastSurgeries] : [],
    careSummaryText: '',
    visitReportTexts: [],
    aiSummaries:
      lower(record.aiStatus) === 'processed' && useful(record.aiSummary)
        ? [record.aiSummary]
        : [],
    ocrTexts:
      lower(record.aiStatus) === 'processed' && useful(record.ocrText)
        ? [record.ocrText]
        : [],
    analysisTags: lower(record.aiStatus) === 'processed' ? tags.map(String) : [],
    previousProviderRatings: {},
    successfulVisitProviderIds: [],
    followUpHints: [],
    hasHistoryForWeighting: false,
  };

  const providers = await loadProviders();
  const request = { rawQuery: '', requestedServiceKeyword: '', requestedDateTime: null };
  const ranked = scoreProviders(patient, providers, request);
  const blob = patientCareBlob(patient);

  console.log('\n=== Recommendation Engine Verification Report ===');
  console.log(`Uploaded file title: ${record.title}`);
  console.log(`Record id: ${record.id}`);
  console.log(`Patient id: ${record.patientUserId}`);
  console.log(`MIME type: ${record.mimeType}`);
  console.log(`AI status: ${record.aiStatus}`);
  console.log(`AI processed: ${record.aiProcessed}`);

  console.log('\n1. Extracted OCR text');
  console.log(record.ocrText || '(NULL)');

  console.log('\n2. Generated AI Summary');
  console.log(record.aiSummary || '(NULL)');

  console.log('\n3. Generated analysisTags');
  console.log(JSON.stringify(tags));

  console.log('\n4. patientCareBlob before ranking');
  console.log(blob || '(empty)');

  console.log('\n5-6. Final provider ranking and score contribution from medical records');
  const rows = ranked.map((item, index) => ({
    rank: index + 1,
    provider: item.provider.fullName,
    role: item.provider.role,
    specialty: item.provider.specialization,
    finalScore: Number(item.finalScore.toFixed(4)),
    baseScore: Number(item.baseScore.toFixed(4)),
    locationScore: Number(item.locationScore.toFixed(4)),
    ratingScore: Number(item.ratingScore.toFixed(4)),
    experienceScore: Number(item.experienceScore.toFixed(4)),
    medicalRecordScore: Number(item.medicalScore.toFixed(4)),
    medicalRecordContribution: Number(item.medicalContribution.toFixed(4)),
    medicalDeltaFromRecord: Number(item.medicalDeltaFromRecord.toFixed(4)),
  }));
  console.table(rows);

  const allZero = ranked.every((item) => item.medicalScore === 0 || item.medicalContribution === 0);
  const allDeltaZero = ranked.every((item) => Math.abs(item.medicalDeltaFromRecord) < 0.0001);
  console.log(`\nMedical record score always 0: ${allZero ? 'YES' : 'NO'}`);
  console.log(`Medical record changes compatibility vs no uploaded record: ${allDeltaZero ? 'NO' : 'YES'}`);
  console.log(`Weights: ${JSON.stringify(ranked[0]?.weights || {})}`);
  await db.end();
}

main().catch(async (err) => {
  console.error(err.message || err);
  try {
    await db.end();
  } catch (_) {}
  process.exit(1);
});

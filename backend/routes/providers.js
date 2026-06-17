const express = require('express');
const db = require('../db');
const { insertNotification } = require('../notifications');
const { recommendProviders } = require('../services/aiRecommendation/engine');

const router = express.Router();

let gpsColumnsAvailableCache = null;
const columnCache = new Map();

async function getGpsProjection() {
  if (gpsColumnsAvailableCache !== null) {
    return gpsColumnsAvailableCache
      ? 'c.gpsLat, c.gpsLng'
      : 'NULL AS gpsLat, NULL AS gpsLng';
  }

  try {
    const [latRows] = await db.query("SHOW COLUMNS FROM careprovider LIKE 'gpsLat'");
    const [lngRows] = await db.query("SHOW COLUMNS FROM careprovider LIKE 'gpsLng'");
    gpsColumnsAvailableCache = latRows.length > 0 && lngRows.length > 0;
  } catch (_) {
    gpsColumnsAvailableCache = false;
  }

  return gpsColumnsAvailableCache
    ? 'c.gpsLat, c.gpsLng'
    : 'NULL AS gpsLat, NULL AS gpsLng';
}

async function hasColumn(tableName, columnName) {
  const key = `${tableName}.${columnName}`;
  if (columnCache.has(key)) return columnCache.get(key);

  try {
    const [rows] = await db.query(`SHOW COLUMNS FROM ${tableName} LIKE ?`, [
      columnName,
    ]);
    const exists = rows.length > 0;
    columnCache.set(key, exists);
    return exists;
  } catch (_) {
    columnCache.set(key, false);
    return false;
  }
}

async function ratingsCountProjection() {
  const hasRc = await hasColumn('careprovider', 'ratingsCount');
  return hasRc
    ? 'COALESCE(c.ratingsCount, 0) AS ratingsCount'
    : '0 AS ratingsCount';
}

async function getProviderExtrasProjection() {
  const hasServiceType = await hasColumn('careprovider', 'serviceType');
  const hasConsultationFee = await hasColumn('careprovider', 'consultationFee');
  const hasHourlyRate = await hasColumn('careprovider', 'hourlyRate');

  const serviceTypeProjection = hasServiceType
    ? 'c.serviceType'
    : "'' AS serviceType";

  let feeProjection = 'NULL AS consultationFee';
  if (hasConsultationFee && hasHourlyRate) {
    feeProjection = 'COALESCE(c.consultationFee, c.hourlyRate) AS consultationFee';
  } else if (hasConsultationFee) {
    feeProjection = 'c.consultationFee';
  } else if (hasHourlyRate) {
    feeProjection = 'c.hourlyRate AS consultationFee';
  }

  return `${serviceTypeProjection}, ${feeProjection}`;
}

async function getProviderStatusProjection() {
  const hasIsActive = await hasColumn('user', 'isActive');
  const hasApprovalStatus = await hasColumn('careprovider', 'approvalStatus');
  const activeProjection = hasIsActive
    ? 'COALESCE(u.isActive, 1) AS isActive'
    : '1 AS isActive';
  const approvalProjection = hasApprovalStatus
    ? "COALESCE(c.approvalStatus, 'pending') AS approvalStatus"
    : "'approved' AS approvalStatus";
  return `${activeProjection}, ${approvalProjection}`;
}

function useful(value) {
  const text = (value || '').toString().trim();
  return text && text.toLowerCase() !== 'null';
}

function parseTags(raw) {
  if (Array.isArray(raw)) return raw.map(String);
  if (!useful(raw)) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.map(String) : [];
  } catch (_) {
    return [];
  }
}

function titleTag(tag) {
  return tag
    .toString()
    .split(/[_\s-]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

const TAG_REASON_MAP = {
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

function medicalReasonsFromTags(tags) {
  return tags
    .map((t) => TAG_REASON_MAP[t.toString().toLowerCase()] || titleTag(t))
    .filter(Boolean);
}

function withBookingEligibility(provider) {
  const isActive =
    provider.isActive === true ||
    provider.isActive === 1 ||
    provider.isActive === '1';
  const approvalStatus = (provider.approvalStatus || 'approved')
    .toString()
    .trim()
    .toLowerCase();
  const isProfileComplete =
    approvalStatus === 'approved' &&
    useful(provider.fullName) &&
    useful(provider.specialization) &&
    ['doctor', 'nurse'].includes((provider.role || '').toString().toLowerCase());

  return {
    ...provider,
    isActive,
    approvalStatus,
    isProfileComplete,
  };
}

function providerCanBeBooked(provider) {
  const price = Number(provider.consultationFee);
  const hasValidSlot =
    Array.isArray(provider.availableSlots) &&
    provider.availableSlots.some((slot) => {
      if (
        !useful(slot.day) ||
        !/^\d{1,2}:\d{2}/.test((slot.startTime || '').toString()) ||
        !/^\d{1,2}:\d{2}/.test((slot.endTime || '').toString())
      ) {
        return false;
      }
      const [startHour, startMinute] = slot.startTime
        .toString()
        .split(':')
        .map(Number);
      const [endHour, endMinute] = slot.endTime
        .toString()
        .split(':')
        .map(Number);
      const start = startHour * 60 + startMinute;
      const end = endHour * 60 + endMinute;
      return Number.isFinite(start) && Number.isFinite(end) && end > start;
    });
  return (
    provider.isActive === true &&
    provider.isProfileComplete === true &&
    useful(provider.serviceType) &&
    Number.isFinite(price) &&
    price > 0 &&
    provider.isAvailable === true &&
    hasValidSlot
  );
}

const ACTIVE_BOOKING_STATUSES = [
  'confirmed',
  'accepted',
  'scheduled',
  'approved',
  'in_progress',
];

function dateKey(date) {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function timeKey(value) {
  return (value || '').toString().trim().slice(0, 5);
}

function dayKey(value) {
  return (value || '').toString().trim().toLowerCase();
}

async function attachRealAvailableSlots(providers, horizonDays = 28) {
  if (!providers.length) return [];

  const providerIds = providers.map((provider) => provider.userId);
  const placeholders = providerIds.map(() => '?').join(',');
  const statusPlaceholders = ACTIVE_BOOKING_STATUSES.map(() => '?').join(',');

  const [scheduleRows, bookingRows] = await Promise.all([
    db.query(
      `SELECT providerUserId, day, startTime, endTime
       FROM availabilityslot
       WHERE providerUserId IN (${placeholders})
       ORDER BY providerUserId, day, startTime`,
      providerIds,
    ),
    db.query(
      `SELECT providerUserId,
              DATE_FORMAT(scheduledAt, '%Y-%m-%d') AS bookingDate,
              TIME_FORMAT(scheduledAt, '%H:%i') AS bookingTime
       FROM servicerequest
       WHERE providerUserId IN (${placeholders})
         AND scheduledAt >= NOW()
         AND LOWER(TRIM(CAST(status AS CHAR(64)))) IN (${statusPlaceholders})`,
      [...providerIds, ...ACTIVE_BOOKING_STATUSES],
    ),
  ]);

  const schedulesByProvider = new Map();
  for (const slot of scheduleRows[0]) {
    const slots = schedulesByProvider.get(slot.providerUserId) || [];
    slots.push(slot);
    schedulesByProvider.set(slot.providerUserId, slots);
  }

  const booked = new Set(
    bookingRows[0].map(
      (row) =>
        `${row.providerUserId}|${row.bookingDate}|${timeKey(row.bookingTime)}`,
    ),
  );

  const now = new Date();
  return providers.map((provider) => {
    if (!(provider.isAvailable === 1 || provider.isAvailable === true)) {
      return withBookingEligibility({
        ...provider,
        availableSlots: [],
        availableTimeSlots: [],
      });
    }

    const recurring = schedulesByProvider.get(provider.userId) || [];
    const freeSlots = [];
    for (let offset = 0; offset < horizonDays; offset += 1) {
      const date = new Date(now);
      date.setHours(0, 0, 0, 0);
      date.setDate(date.getDate() + offset);
      const weekday = dayKey(
        date.toLocaleDateString('en-US', { weekday: 'long' }),
      );

      for (const slot of recurring) {
        if (dayKey(slot.day) !== weekday) continue;
        const start = timeKey(slot.startTime);
        const end = timeKey(slot.endTime);
        const slotDateTime = new Date(`${dateKey(date)}T${start}:00`);
        if (slotDateTime <= now) continue;
        if (booked.has(`${provider.userId}|${dateKey(date)}|${start}`)) {
          continue;
        }
        freeSlots.push({
          day: slot.day,
          date: dateKey(date),
          startTime: start,
          endTime: end,
        });
      }
    }

    return withBookingEligibility({
      ...provider,
      isAvailable: true,
      availableSlots: freeSlots,
      availableTimeSlots: freeSlots.map(
        (slot) =>
          `${slot.date} ${slot.day} ${slot.startTime}-${slot.endTime}`,
      ),
    });
  });
}

async function loadRecommendationPatient(patientId) {
  const [patients] = await db.query(
    `SELECT gpsLat, gpsLng, chronicDiseases, allergies, currentMedications
     FROM patient
     WHERE BINARY userId = BINARY ?
     LIMIT 1`,
    [patientId]
  );
  const row = patients[0] || {};
  const [records] = await db.query(
    `SELECT aiSummary, ocrText, analysisTags
     FROM patientmedicalfile
     WHERE BINARY patientUserId = BINARY ?
       AND aiStatus = 'processed'
       AND aiProcessed = 1
       AND (
         NULLIF(TRIM(COALESCE(aiSummary, '')), '') IS NOT NULL
         OR NULLIF(TRIM(COALESCE(ocrText, '')), '') IS NOT NULL
       )
     ORDER BY uploadDate DESC`,
    [patientId]
  );

  return {
    id: patientId,
    locationLatitude: Number(row.gpsLat) || null,
    locationLongitude: Number(row.gpsLng) || null,
    chronicDiseases: useful(row.chronicDiseases) ? [row.chronicDiseases] : [],
    allergies: useful(row.allergies) ? [row.allergies] : [],
    medications: useful(row.currentMedications) ? [row.currentMedications] : [],
    previousSurgeries: [],
    careSummaryText: '',
    visitReportTexts: [],
    aiSummaries: records.map((r) => r.aiSummary).filter(useful),
    ocrTexts: records.map((r) => r.ocrText).filter(useful),
    analysisTags: records.flatMap((r) => parseTags(r.analysisTags)),
    previousProviderRatings: {},
    successfulVisitProviderIds: [],
    followUpHints: [],
    hasHistoryForWeighting: false,
  };
}

async function loadRecommendationProviders() {
  const gpsProjection = await getGpsProjection();
  const providerExtrasProjection = await getProviderExtrasProjection();
  const providerStatusProjection = await getProviderStatusProjection();
  const rcProj = await ratingsCountProjection();
  const hasExperienceYears = await hasColumn('careprovider', 'experienceYears');
  const experienceProjection = hasExperienceYears
    ? 'c.experienceYears'
    : 'NULL AS experienceYears';
  const [rows] = await db.query(`
    SELECT
      u.userId,
      u.fullName,
      u.email,
      u.phone,
      u.role,
      u.profileImageUrl,
      c.specialization,
      c.overallRating,
      ${rcProj},
      c.isAvailable,
      ${providerStatusProjection},
      ${experienceProjection},
      ${providerExtrasProjection},
      ${gpsProjection}
    FROM user u
    JOIN careprovider c ON u.userId = c.userId
    WHERE u.role IN ('doctor', 'nurse')
  `);

  return attachRealAvailableSlots(
    rows.map((row) => ({
      id: row.userId,
      userId: row.userId,
      fullName: row.fullName || '',
      email: row.email,
      phone: row.phone,
      role: row.role || '',
      profileImageUrl: row.profileImageUrl || null,
      specialization: row.specialization || '',
      serviceType: row.serviceType || '',
      rating: Number(row.overallRating) || 0,
      overallRating: Number(row.overallRating) || 0,
      ratingsCount: Number(row.ratingsCount) || 0,
      isAvailable: row.isAvailable === 1 || row.isAvailable === true,
      isActive: row.isActive,
      approvalStatus: row.approvalStatus,
      experienceYears:
        row.experienceYears == null ? null : Number(row.experienceYears),
      consultationFee: row.consultationFee,
      locationLatitude: row.gpsLat == null ? null : Number(row.gpsLat),
      locationLongitude: row.gpsLng == null ? null : Number(row.gpsLng),
      gpsLat: row.gpsLat,
      gpsLng: row.gpsLng,
    })),
  );
}

router.get('/recommendations/:patientId', async (req, res) => {
  try {
    const patient = await loadRecommendationPatient(req.params.patientId);
    const providers = (await loadRecommendationProviders()).filter(
      providerCanBeBooked,
    );
    const request = {
      rawQuery: req.query.q?.toString() || '',
      requestedServiceKeyword: req.query.specialty?.toString() || '',
      requestedDateTime: null,
      isUrgent: req.query.urgent === '1' || req.query.urgent === 'true',
      isComplexCase: req.query.complex === '1' || req.query.complex === 'true',
    };
    const ranked = recommendProviders(patient, request, providers, Number(req.query.top) || 50);
    const medicalTags = [...new Set(patient.analysisTags || [])].map(titleTag);
    const medicalReasons = medicalReasonsFromTags(patient.analysisTags || []);
    res.json(
      ranked.map((r) => ({
        provider: r.provider,
        providerId: r.providerId || r.provider?.userId || r.provider?.id || '',
        finalScore: r.finalScore,
        matchPercentage: r.matchPercentage,
        medicalMatchScore: r.scoreBreakdown?.medicalCompatibility ?? null,
        scoreBreakdown: r.scoreBreakdown,
        weights: r.weights,
        medicalTags,
        medicalReasons,
        matchedTags: r.matchedTags || [],
        matchedTagLabels: r.matchedTags || [],
        recommendationReason: r.aiMatchReason || r.recommendationReasons?.[0] || '',
        displayReason: r.aiMatchReason || r.recommendationReasons?.[0] || '',
        recommendationReasons: r.recommendationReasons,
        aiMatchReason: r.aiMatchReason || null,
      }))
    );
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// جميع مقدمي الخدمة: دكاترة + ممرضين
router.get('/', async (req, res) => {
  try {
    const gpsProjection = await getGpsProjection();
    const providerExtrasProjection = await getProviderExtrasProjection();
    const providerStatusProjection = await getProviderStatusProjection();
    const rcProj = await ratingsCountProjection();
    const hasExperienceYears = await hasColumn('careprovider', 'experienceYears');
    const experienceProjection = hasExperienceYears
      ? 'c.experienceYears'
      : 'NULL AS experienceYears';
    const [rows] = await db.query(`
      SELECT 
        u.userId,
        u.fullName,
        u.email,
        u.phone,
        u.role,
        u.profileImageUrl,
        c.specialization,
        c.overallRating,
        ${rcProj},
        c.isAvailable,
        ${providerStatusProjection},
        ${experienceProjection},
        ${providerExtrasProjection},
        ${gpsProjection}
      FROM user u
      JOIN careprovider c ON u.userId = c.userId
      WHERE u.role IN ('doctor', 'nurse')
      ORDER BY c.overallRating DESC, u.fullName ASC
    `);

    let providersWithSlots;
    if (req.query.realAvailability === '1') {
      providersWithSlots = await attachRealAvailableSlots(rows);
    } else {
      providersWithSlots = await Promise.all(
        rows.map(async (provider) => {
          const [slots] = await db.query(
            `SELECT day, startTime, endTime
             FROM availabilityslot
             WHERE providerUserId = ?
             ORDER BY day, startTime`,
            [provider.userId],
          );
          return withBookingEligibility({
            ...provider,
            isAvailable:
              provider.isAvailable === 1 || provider.isAvailable === true,
            availableSlots: slots,
            availableTimeSlots: slots.map(
              (slot) => `${slot.day} ${slot.startTime}-${slot.endTime}`,
            ),
          });
        }),
      );
    }

    res.json(providersWithSlots);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// الدكاترة فقط
router.get('/doctors', async (req, res) => {
  try {
    const gpsProjection = await getGpsProjection();
    const providerExtrasProjection = await getProviderExtrasProjection();
    const providerStatusProjection = await getProviderStatusProjection();
    const rcProj = await ratingsCountProjection();
    const [rows] = await db.query(`
      SELECT 
        u.userId,
        u.fullName,
        u.email,
        u.phone,
        u.role,
        u.profileImageUrl,
        c.specialization,
        c.overallRating,
        ${rcProj},
        c.isAvailable,
        ${providerStatusProjection},
        ${providerExtrasProjection},
        ${gpsProjection}
      FROM user u
      JOIN careprovider c ON u.userId = c.userId
      WHERE u.role = 'doctor'
      ORDER BY c.overallRating DESC, u.fullName ASC
    `);

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// تفاصيل مزود خدمة واحد
router.get('/provider/:userId', async (req, res) => {
  const { userId } = req.params;

  try {
    const gpsProjection = await getGpsProjection();
    const providerExtrasProjection = await getProviderExtrasProjection();
    const providerStatusProjection = await getProviderStatusProjection();
    const rcProj = await ratingsCountProjection();
    const [rows] = await db.query(
      `
      SELECT 
        u.userId,
        u.fullName,
        u.email,
        u.phone,
        u.role,
        u.profileImageUrl,
        c.specialization,
        c.overallRating,
        ${rcProj},
        c.isAvailable,
        ${providerStatusProjection},
        ${providerExtrasProjection},
        ${gpsProjection}
      FROM user u
      JOIN careprovider c ON u.userId = c.userId
      WHERE u.userId = ? AND u.role IN ('doctor', 'nurse')
      `,
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Provider not found' });
    }

    if (req.query.realAvailability === '1') {
      const [provider] = await attachRealAvailableSlots(rows);
      return res.json(provider);
    }

    const provider = rows[0];
    const [slots] = await db.query(
      `SELECT day, startTime, endTime
       FROM availabilityslot
       WHERE providerUserId = ?
       ORDER BY day, startTime`,
      [userId],
    );
    res.json(
      withBookingEligibility({
        ...provider,
        isAvailable:
          provider.isAvailable === 1 || provider.isAvailable === true,
        availableSlots: slots,
        availableTimeSlots: slots.map(
          (slot) => `${slot.day} ${slot.startTime}-${slot.endTime}`,
        ),
      }),
    );
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// دعم قديم إذا لسا عندك شاشات تستخدم doctor
router.get('/doctor/:userId', async (req, res) => {
  const { userId } = req.params;

  try {
    const gpsProjection = await getGpsProjection();
    const providerExtrasProjection = await getProviderExtrasProjection();
    const rcProj = await ratingsCountProjection();
    const [rows] = await db.query(
      `
      SELECT 
        u.userId,
        u.fullName,
        u.email,
        u.phone,
        u.role,
        u.profileImageUrl,
        c.specialization,
        c.overallRating,
        ${rcProj},
        c.isAvailable,
        ${providerExtrasProjection},
        ${gpsProjection}
      FROM user u
      JOIN careprovider c ON u.userId = c.userId
      WHERE u.userId = ? AND u.role = 'doctor'
      `,
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    const doctor = rows[0];

    const [slots] = await db.query(
      `
      SELECT day, startTime, endTime
      FROM availabilityslot
      WHERE providerUserId = ?
      ORDER BY day, startTime
      `,
      [userId]
    );

    doctor.availableSlots = slots;
    doctor.availableTimeSlots = slots.map(
      (slot) => `${slot.day} ${slot.startTime}-${slot.endTime}`
    );

    res.json(doctor);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Appointments (service requests) for care providers: list, accept/reject, live location ---

router.get('/appointments', async (req, res) => {
  const providerUserId = req.query.providerUserId
    ? req.query.providerUserId.toString().trim()
    : '';

  if (!providerUserId) {
    return res.status(400).json({ error: 'providerUserId is required' });
  }

  try {
    const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');
    const hasProviderLat = await hasColumn('servicerequest', 'providerCurrentLat');
    const hasProviderLng = await hasColumn('servicerequest', 'providerCurrentLng');
    const hasProviderAt = await hasColumn('servicerequest', 'providerLocationUpdatedAt');

    const [rows] = await db.query(
      `SELECT
          sr.requestId,
          sr.patientUserId,
          sr.providerUserId,
          sr.serviceType,
          sr.status,
          sr.notes,
          sr.location,
          sr.scheduledAt,
          ${hasVisitAddress ? 'sr.visitAddress' : "'' AS visitAddress"},
          ${hasProviderLat ? 'sr.providerCurrentLat' : 'NULL AS providerCurrentLat'},
          ${hasProviderLng ? 'sr.providerCurrentLng' : 'NULL AS providerCurrentLng'},
          ${hasProviderAt ? 'sr.providerLocationUpdatedAt' : 'NULL AS providerLocationUpdatedAt'},
          pu.fullName AS patientName
       FROM servicerequest sr
       LEFT JOIN user pu ON sr.patientUserId = pu.userId
       WHERE sr.providerUserId = ?
         AND LOWER(TRIM(CAST(sr.status AS CHAR(64)))) <> 'draft'
       ORDER BY sr.scheduledAt DESC
       LIMIT 500`,
      [providerUserId]
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/appointments/:requestId/status', async (req, res) => {
  const { requestId } = req.params;
  const { providerUserId, status } = req.body || {};

  const pid = providerUserId ? providerUserId.toString().trim() : '';
  const next = status ? status.toString().trim().toLowerCase() : '';

  if (!pid || !next) {
    return res
      .status(400)
      .json({ error: 'providerUserId and status are required' });
  }

  const allowed = new Set(['confirmed', 'cancelled', 'completed']);
  if (!allowed.has(next)) {
    return res.status(400).json({
      error: 'status must be one of: confirmed, cancelled, completed'
    });
  }

  try {
    const [rows] = await db.query(
      `SELECT requestId, patientUserId, providerUserId, status,
              paymentStatus, paymentMethod
       FROM servicerequest
       WHERE requestId = ?`,
      [requestId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    const row = rows[0];
    if (row.providerUserId !== pid) {
      return res.status(403).json({ error: 'Not allowed for this provider' });
    }

    const current = (row.status || '').toString().toLowerCase();

    if (['completed', 'cancelled'].includes(current)) {
      return res
        .status(409)
        .json({ error: 'This appointment is already closed' });
    }

    if (current === 'pending') {
      if (next !== 'confirmed' && next !== 'cancelled') {
        return res
          .status(400)
          .json({ error: 'From pending, only confirmed or cancelled' });
      }
    } else if (current === 'pending_payment' || current === 'payment_pending') {
      if (next !== 'cancelled') {
        return res
          .status(400)
          .json({ error: 'Awaiting payment; only cancellation is allowed' });
      }
    } else if (current === 'confirmed') {
      if (next !== 'completed' && next !== 'cancelled') {
        return res
          .status(400)
          .json({ error: 'From confirmed, only completed or cancelled' });
      }
    } else {
      return res.status(400).json({ error: 'Unexpected current status' });
    }

    const paid = (row.paymentStatus || '').toString().toLowerCase() === 'paid';
    const paymentMethod = (row.paymentMethod || '').toString().toLowerCase();
    const payAtVisit =
      paymentMethod === 'cash' || paymentMethod === 'cash_on_visit';
    const effectiveNext =
      next === 'confirmed' && !paid && !payAtVisit
        ? 'pending_payment'
        : next;

    await db.execute(
      `UPDATE servicerequest SET status = ? WHERE requestId = ? AND providerUserId = ?`,
      [effectiveNext, requestId, pid]
    );

    const titles = {
      confirmed: { title: 'تم قبول الموعد', en: 'Appointment accepted' },
      cancelled: { title: 'تم رفض أو إلغاء الموعد', en: 'Appointment cancelled' },
      completed: { title: 'تم إكمال الخدمة', en: 'Visit completed' }
    };
    const t = titles[next] || { title: 'تحديث الموعد', en: 'Booking update' };

    try {
      await insertNotification({
        userId: row.patientUserId,
        type: 'appointment',
        title: effectiveNext === 'pending_payment' ? 'الدفع مطلوب' : t.title,
        body:
          effectiveNext === 'pending_payment'
            ? 'يرجى إكمال الدفع قبل تأكيد الموعد.'
            : next === 'confirmed'
            ? 'مقدم الخدمة قَبِلَ الطلب. سيظهر الموعد في جدولك. يمكنك متابعة الموقع بعد بدء التوجّه.'
            : next === 'cancelled'
            ? 'تم إلغاء هذا الطلب. يمكنك اختيار مقدم خدمة آخر.'
            : 'سجّلنا إكمال زيارة الخدمة. شكراً لاستخدامك CareLink.',
        relatedRequestId: requestId
      });
    } catch (_) {}

    res.json({
      success: true,
      requestId,
      status: effectiveNext,
      paymentRequired: effectiveNext === 'pending_payment',
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/appointments/:requestId/location', async (req, res) => {
  const { requestId } = req.params;
  const { providerUserId, lat, lng } = req.body || {};

  const pid = providerUserId ? providerUserId.toString().trim() : '';
  const pLat = lat == null || lat === '' ? null : Number(lat);
  const pLng = lng == null || lng === '' ? null : Number(lng);

  if (!pid || pLat == null || pLng == null) {
    return res
      .status(400)
      .json({ error: 'providerUserId, lat and lng are required' });
  }

  if (!Number.isFinite(pLat) || !Number.isFinite(pLng)) {
    return res.status(400).json({ error: 'Invalid coordinates' });
  }

  try {
    const hasLat = await hasColumn('servicerequest', 'providerCurrentLat');
    const hasLng = await hasColumn('servicerequest', 'providerCurrentLng');
    const hasAt = await hasColumn('servicerequest', 'providerLocationUpdatedAt');

    if (!hasLat || !hasLng) {
      return res.status(501).json({
        error: 'Provider location columns are not available; run the latest SQL migration.'
      });
    }

    const [rows] = await db.query(
      `SELECT requestId, patientUserId, providerUserId, status
       FROM servicerequest
       WHERE requestId = ?`,
      [requestId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    const row = rows[0];
    if (row.providerUserId !== pid) {
      return res.status(403).json({ error: 'Not allowed for this provider' });
    }

    if ((row.status || '').toString().toLowerCase() !== 'confirmed') {
      return res
        .status(409)
        .json({ error: 'Location sharing is only for confirmed visits' });
    }

    if (hasAt) {
      await db.execute(
        `UPDATE servicerequest
         SET providerCurrentLat = ?,
             providerCurrentLng = ?,
             providerLocationUpdatedAt = NOW()
         WHERE requestId = ?
           AND providerUserId = ?`,
        [pLat, pLng, requestId, pid]
      );
    } else {
      await db.execute(
        `UPDATE servicerequest
         SET providerCurrentLat = ?,
             providerCurrentLng = ?
         WHERE requestId = ?
           AND providerUserId = ?`,
        [pLat, pLng, requestId, pid]
      );
    }

    res.json({ success: true, requestId, lat: pLat, lng: pLng });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/provider/:userId/blocked-slots', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT scheduledAt
       FROM servicerequest
         WHERE providerUserId = ?
         AND LOWER(TRIM(CAST(status AS CHAR(64)))) IN
           ('confirmed', 'accepted', 'approved', 'scheduled', 'in_progress')
         AND scheduledAt >= CURDATE()`,
      [req.params.userId]
    );
    res.json(rows.map((r) => r.scheduledAt));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

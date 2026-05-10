const express = require('express');
const db = require('../db');
const { insertNotification } = require('../notifications');

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

// جميع مقدمي الخدمة: دكاترة + ممرضين
router.get('/', async (req, res) => {
  try {
    const gpsProjection = await getGpsProjection();
    const providerExtrasProjection = await getProviderExtrasProjection();
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
        c.specialization,
        c.overallRating,
        ${rcProj},
        c.isAvailable,
        ${experienceProjection},
        ${providerExtrasProjection},
        ${gpsProjection}
      FROM user u
      JOIN careprovider c ON u.userId = c.userId
      WHERE u.role IN ('doctor', 'nurse')
      ORDER BY c.overallRating DESC, u.fullName ASC
    `);

    const providersWithSlots = await Promise.all(
      rows.map(async (provider) => {
        const [slots] = await db.query(
          `
          SELECT day, startTime, endTime
          FROM availabilityslot
          WHERE providerUserId = ?
          ORDER BY day, startTime
          `,
          [provider.userId]
        );

        return {
          ...provider,
          availableSlots: slots,
          availableTimeSlots: slots.map(
            (slot) => `${slot.day} ${slot.startTime}-${slot.endTime}`
          ),
        };
      })
    );

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
    const rcProj = await ratingsCountProjection();
    const [rows] = await db.query(`
      SELECT 
        u.userId,
        u.fullName,
        u.email,
        u.phone,
        u.role,
        c.specialization,
        c.overallRating,
        ${rcProj},
        c.isAvailable,
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
    const rcProj = await ratingsCountProjection();
    const [rows] = await db.query(
      `
      SELECT 
        u.userId,
        u.fullName,
        u.email,
        u.phone,
        u.role,
        c.specialization,
        c.overallRating,
        ${rcProj},
        c.isAvailable,
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

    const provider = rows[0];

    const [slots] = await db.query(
      `
      SELECT day, startTime, endTime
      FROM availabilityslot
      WHERE providerUserId = ?
      ORDER BY day, startTime
      `,
      [userId]
    );

    provider.availableSlots = slots;
    provider.availableTimeSlots = slots.map(
      (slot) => `${slot.day} ${slot.startTime}-${slot.endTime}`
    );

    res.json(provider);
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
    } else if (current === 'confirmed') {
      if (next !== 'completed' && next !== 'cancelled') {
        return res
          .status(400)
          .json({ error: 'From confirmed, only completed or cancelled' });
      }
    } else {
      return res.status(400).json({ error: 'Unexpected current status' });
    }

    await db.execute(
      `UPDATE servicerequest SET status = ? WHERE requestId = ? AND providerUserId = ?`,
      [next, requestId, pid]
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
        title: t.title,
        body:
          next === 'confirmed'
            ? 'مقدم الخدمة قَبِلَ الطلب. سيظهر الموعد في جدولك. يمكنك متابعة الموقع بعد بدء التوجّه.'
            : next === 'cancelled'
            ? 'تم إلغاء هذا الطلب. يمكنك اختيار مقدم خدمة آخر.'
            : 'سجّلنا إكمال زيارة الخدمة. شكراً لاستخدامك CareLink.',
        relatedRequestId: requestId
      });
    } catch (_) {}

    res.json({ success: true, requestId, status: next });
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

module.exports = router;

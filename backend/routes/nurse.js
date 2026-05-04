const express = require('express');
const { randomUUID } = require('crypto');
const db = require('../db');
const { insertNotification } = require('../notifications');
const medicalRecordService = require('../services/medicalRecordService');

const router = express.Router();

const columnCache = new Map();

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

async function ensureAuxTables() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS nurse_appsettings (
      userId VARCHAR(64) PRIMARY KEY,
      settingsJson TEXT NOT NULL,
      updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
  await db.query(`
    CREATE TABLE IF NOT EXISTS provider_payment_method (
      methodId VARCHAR(64) PRIMARY KEY,
      providerUserId VARCHAR(64) NOT NULL,
      type VARCHAR(64) NOT NULL,
      details TEXT,
      isDefault TINYINT(1) NOT NULL DEFAULT 0,
      createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      KEY idx_provider_payment_method (providerUserId)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
  await db.query(`
    CREATE TABLE IF NOT EXISTS provider_certification (
      certId VARCHAR(64) PRIMARY KEY,
      providerUserId VARCHAR(64) NOT NULL,
      name VARCHAR(512) NOT NULL,
      createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      KEY idx_provider_cert (providerUserId)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
}

const DEFAULT_SETTINGS = {
  newRequestsNotifications: true,
  scheduleReminders: true,
  paymentNotifications: true,
  messageNotifications: true,
  emergencyAlerts: true,
  profileVisible: true,
  showPhoneNumber: false,
  showEmail: false,
  darkMode: false,
  language: 'English',
};

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  if (
    ![lat1, lon1, lat2, lon2].every(
      (v) => typeof v === 'number' && Number.isFinite(v),
    )
  ) {
    return null;
  }
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

async function assertNurseUser(userId, res) {
  const [rows] = await db.query(
    `SELECT role FROM user WHERE userId = ? LIMIT 1`,
    [userId],
  );
  if (!rows.length) {
    res.status(404).json({ error: 'User not found' });
    return false;
  }
  if ((rows[0].role || '').toLowerCase() !== 'nurse') {
    res.status(403).json({ error: 'Nurse access only' });
    return false;
  }
  return true;
}

/** --- Settings --- */
router.get('/settings/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    await ensureAuxTables();
    const [rows] = await db.query(
      `SELECT settingsJson FROM nurse_appsettings WHERE userId = ?`,
      [userId],
    );
    if (!rows.length) {
      return res.json(DEFAULT_SETTINGS);
    }
    try {
      const parsed = JSON.parse(rows[0].settingsJson || '{}');
      return res.json({ ...DEFAULT_SETTINGS, ...parsed });
    } catch (_) {
      return res.json(DEFAULT_SETTINGS);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/settings/:userId', async (req, res) => {
  const { userId } = req.params;
  const body = { ...DEFAULT_SETTINGS, ...(req.body || {}) };
  try {
    await ensureAuxTables();
    const json = JSON.stringify(body);
    await db.execute(
      `INSERT INTO nurse_appsettings (userId, settingsJson)
       VALUES (?, ?)
       ON DUPLICATE KEY UPDATE settingsJson = VALUES(settingsJson)`,
      [userId, json],
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/** --- Dashboard --- */
router.get('/dashboard/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    if (!(await assertNurseUser(userId, res))) return;

    const [[pending]] = await db.query(
      `SELECT COUNT(*) AS c FROM servicerequest
       WHERE providerUserId = ? AND status = 'pending'`,
      [userId],
    );
    const [[today]] = await db.query(
      `SELECT COUNT(*) AS c FROM servicerequest
       WHERE providerUserId = ?
         AND status IN ('pending','confirmed')
         AND DATE(scheduledAt) = CURDATE()`,
      [userId],
    );
    const [[done]] = await db.query(
      `SELECT COUNT(*) AS c FROM servicerequest
       WHERE providerUserId = ? AND status = 'completed'`,
      [userId],
    );

    let weeklyEarnings = 0;
    try {
      const [[pay]] = await db.query(
        `SELECT COALESCE(SUM(amount), 0) AS s FROM payment
         WHERE providerUserId = ?
           AND paymentStatus IN ('paid', 'pending')
           AND YEARWEEK(createdAt, 1) = YEARWEEK(CURDATE(), 1)`,
        [userId],
      );
      weeklyEarnings = Number(pay?.s || 0);
    } catch (_) {}

    res.json({
      pendingRequests: Number(pending?.c || 0),
      todaysVisits: Number(today?.c || 0),
      completedVisits: Number(done?.c || 0),
      weeklyEarnings,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/** --- Service requests (list + status) --- */
async function listRequestsForProvider(providerUserId, statusQ) {
  const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');
  const hasCreatedAt = await hasColumn('servicerequest', 'createdAt');
  const createdExpr = hasCreatedAt ? 'sr.createdAt' : 'sr.scheduledAt';

  const params = [providerUserId];
  let statusClause = '';
  if (statusQ && statusQ.length) {
    statusClause = ' AND LOWER(sr.status) = ?';
    params.push(statusQ.toLowerCase());
  }

  const [rows] = await db.query(
    `SELECT
        sr.requestId AS requestId,
        sr.patientUserId AS patientUserId,
        sr.providerUserId AS providerUserId,
        sr.serviceType,
        sr.status,
        sr.notes,
        sr.location,
        sr.scheduledAt,
        ${hasVisitAddress ? 'sr.visitAddress' : "'' AS visitAddress"},
        ${createdExpr} AS createdAt,
        pu.fullName AS patientName
     FROM servicerequest sr
     LEFT JOIN user pu ON sr.patientUserId = pu.userId
     WHERE sr.providerUserId = ?${statusClause}
     ORDER BY sr.scheduledAt DESC
     LIMIT 500`,
    params,
  );

  return rows.map((r) => ({
    requestId: r.requestId,
    patientUserId: r.patientUserId,
    providerUserId: r.providerUserId,
    patientId: r.patientUserId,
    providerId: r.providerUserId,
    patientName: r.patientName || '',
    serviceType: r.serviceType || '',
    location: (r.visitAddress && String(r.visitAddress).trim()) || r.location || '',
    status: r.status,
    notes: r.notes,
    scheduledAt: r.scheduledAt,
    scheduledDate: r.scheduledAt,
    createdAt: r.createdAt,
  }));
}

router.get('/requests/:providerId', async (req, res) => {
  const { providerId } = req.params;
  const statusQ = req.query.status ? req.query.status.toString().trim() : '';
  try {
    const [userRows] = await db.query(
      `SELECT role FROM user WHERE userId = ?`,
      [providerId],
    );
    if (!userRows.length) {
      return res.status(404).json({ error: 'User not found' });
    }
    if ((userRows[0].role || '').toLowerCase() !== 'nurse') {
      return res.status(403).json({ error: 'Nurse requests only' });
    }

    let normalizedStatus = statusQ.toLowerCase();
    if (normalizedStatus === 'scheduled') normalizedStatus = 'confirmed';

    const rows = await listRequestsForProvider(
      providerId,
      normalizedStatus && normalizedStatus !== 'all' ? normalizedStatus : '',
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/requests/:requestId/status', async (req, res) => {
  const { requestId } = req.params;
  let { providerUserId, status } = req.body || {};
  providerUserId = providerUserId ? providerUserId.toString().trim() : '';
  let next = status ? status.toString().trim().toLowerCase() : '';
  if (next === 'scheduled') next = 'confirmed';

  if (!providerUserId || !next) {
    return res
      .status(400)
      .json({ error: 'providerUserId and status are required' });
  }

  const allowed = new Set(['confirmed', 'cancelled', 'completed']);
  if (!allowed.has(next)) {
    return res.status(400).json({
      error: 'status must be one of: confirmed, cancelled, completed',
    });
  }

  try {
    const [rows] = await db.query(
      `SELECT requestId, patientUserId, providerUserId, status
       FROM servicerequest
       WHERE requestId = ?`,
      [requestId],
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }

    const row = rows[0];
    if (row.providerUserId !== providerUserId) {
      return res.status(403).json({ error: 'Not allowed for this provider' });
    }

    const current = (row.status || '').toString().toLowerCase();

    if (['completed', 'cancelled'].includes(current)) {
      return res.status(409).json({ error: 'This request is already closed' });
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
      [next, requestId, providerUserId],
    );

    const titles = {
      confirmed: { title: 'تم قبول الموعد', en: 'Appointment accepted' },
      cancelled: { title: 'تم رفض أو إلغاء الموعد', en: 'Visit cancelled' },
      completed: { title: 'تم إكمال الخدمة', en: 'Visit completed' },
    };
    const t = titles[next] || { title: 'تحديث الطلب', en: 'Booking update' };

    try {
      await insertNotification({
        userId: row.patientUserId,
        type: 'appointment',
        title: t.title,
        body:
          next === 'confirmed'
            ? 'مقدّم الرعاية قبل الطلب. ستصلك إشعارات متابعة على CareLink.'
            : next === 'cancelled'
              ? 'تم إلغاء هذا الطلب. يمكنك اختيار مقدّم خدمة آخر.'
              : 'سجّلنا إكمال زيارة الخدمة. شكراً لاستخدامك CareLink.',
        relatedRequestId: requestId,
      });
    } catch (_) {}

    res.json({ success: true, requestId, status: next });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/** AI-style recommendations: pending visits for this nurse + distance hint */
router.get('/recommendations/:nurseUserId', async (req, res) => {
  const { nurseUserId } = req.params;
  try {
    if (!(await assertNurseUser(nurseUserId, res))) return;

    const hasNurseLat = await hasColumn('careprovider', 'gpsLat');
    const hasNurseLng = await hasColumn('careprovider', 'gpsLng');
    const hasPatientLat = await hasColumn('patient', 'gpsLat');
    const hasPatientLng = await hasColumn('patient', 'gpsLng');

    let nurseLat = null;
    let nurseLng = null;
    if (hasNurseLat && hasNurseLng) {
      const [[np]] = await db.query(
        `SELECT gpsLat, gpsLng FROM careprovider WHERE userId = ?`,
        [nurseUserId],
      );
      if (np) {
        nurseLat = np.gpsLat != null ? Number(np.gpsLat) : null;
        nurseLng = np.gpsLng != null ? Number(np.gpsLng) : null;
      }
    }

    const [rows] = await db.query(
      `SELECT sr.requestId, sr.serviceType, sr.location, sr.notes, sr.scheduledAt,
              pu.fullName AS patientName,
              pat.addressText,
              ${hasPatientLat ? 'pat.gpsLat' : 'NULL AS gpsLat'},
              ${hasPatientLng ? 'pat.gpsLng' : 'NULL AS gpsLng'}
       FROM servicerequest sr
       JOIN user pu ON pu.userId = sr.patientUserId
       LEFT JOIN patient pat ON pat.userId = sr.patientUserId
       WHERE sr.providerUserId = ?
         AND sr.status = 'pending'
       ORDER BY sr.scheduledAt ASC
       LIMIT 50`,
      [nurseUserId],
    );

    const out = rows.map((r) => {
      const plat = r.gpsLat != null ? Number(r.gpsLat) : null;
      const plng = r.gpsLng != null ? Number(r.gpsLng) : null;
      const km = haversineKm(nurseLat, nurseLng, plat, plng);
      let recommendationReason = 'Pending visit matched to your profile.';
      if (km != null) {
        recommendationReason = `About ${km.toFixed(1)} km from your base · ${r.serviceType || 'care visit'}`;
      } else if ((r.addressText || '').trim()) {
        recommendationReason = `${r.addressText.trim()} · ${r.serviceType || ''}`.trim();
      }
      return {
        recommendationId: r.requestId,
        requestId: r.requestId,
        patientName: r.patientName || 'Patient',
        recommendationReason,
        addressText: r.addressText || '',
        serviceType: r.serviceType || '',
      };
    });

    res.json(out);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/recommendations/:nurseUserId/:recommendationId/accept', async (req, res) => {
  const { nurseUserId, recommendationId } = req.params;
  try {
    const [rows] = await db.query(
      `SELECT requestId, patientUserId, providerUserId, status
       FROM servicerequest WHERE requestId = ?`,
      [recommendationId],
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }
    const row = rows[0];
    if (row.providerUserId !== nurseUserId) {
      return res.status(403).json({ error: 'Not your recommendation' });
    }
    const current = (row.status || '').toString().toLowerCase();
    if (current !== 'pending') {
      return res.status(409).json({ error: 'Request is not pending' });
    }
    await db.execute(
      `UPDATE servicerequest SET status = 'confirmed' WHERE requestId = ? AND providerUserId = ?`,
      [recommendationId, nurseUserId],
    );
    try {
      await insertNotification({
        userId: row.patientUserId,
        type: 'appointment',
        title: 'تم قبول الموعد',
        body: 'الممرض/ة قبل طلب الزيارة.',
        relatedRequestId: recommendationId,
      });
    } catch (_) {}
    res.json({ success: true, requestId: recommendationId, status: 'confirmed' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/** --- Visit reports (nurse UI shape ↔ visit_reports table) --- */
function mapVisitReportRow(r) {
  const scheduled =
    r.visit_date ||
    (r.created_at ? String(r.created_at).slice(0, 10) : '') ||
    new Date().toISOString();
  return {
    id: r.id,
    providerId: r.provider_id,
    patientId: r.patient_id,
    patientName: r.patientName || '',
    serviceType: '',
    location: '',
    scheduledDate: scheduled,
    durationHours: 0,
    visitSummary: r.diagnosis || '',
    vitalSigns: r.vital_signs || '',
    medications: r.medications_prescribed || '',
    observations: r.treatment_plan || '',
    recommendations: r.recommendations || '',
    status: 'completed',
    createdAt: r.created_at,
    updatedAt: r.created_at,
  };
}

router.get('/reports/:providerId', async (req, res) => {
  const { providerId } = req.params;
  try {
    if (!(await medicalRecordService.tableExists('visit_reports'))) {
      return res.json([]);
    }
    const hasMed = await hasColumn('visit_reports', 'medications_prescribed');
    const medSel = hasMed ? 'vr.medications_prescribed' : "'' AS medications_prescribed";

    const [rows] = await db.query(
      `SELECT vr.id, vr.patient_id, vr.provider_id, vr.appointment_id,
              vr.vital_signs, vr.diagnosis, vr.treatment_plan, vr.recommendations,
              ${medSel},
              vr.created_at, vr.visit_date,
              u.fullName AS patientName
       FROM visit_reports vr
       LEFT JOIN user u ON u.userId = vr.patient_id
       WHERE vr.provider_id = ?
       ORDER BY vr.created_at DESC
       LIMIT 200`,
      [providerId],
    );
    res.json(rows.map(mapVisitReportRow));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/reports/:providerId', async (req, res) => {
  const { providerId } = req.params;
  const b = req.body || {};

  const reportId = (b.reportId || b.id || '').toString().trim();
  const patientId = (b.patientId || '').toString().trim();
  const appointmentId = (b.requestId || b.appointmentId || '').toString().trim();
  const visitSummary = (b.visitSummary || '').toString().trim();
  const observations = (b.observations || '').toString().trim();
  const vitalSigns = (b.vitalSigns || '').toString().trim();
  const medications = (b.medications || '').toString().trim();
  const recommendations = (b.recommendations || '').toString().trim();

  try {
    if (!(await medicalRecordService.tableExists('visit_reports'))) {
      return res.status(503).json({ error: 'visit_reports table missing' });
    }

    if (reportId) {
      const hasMedUp = await hasColumn('visit_reports', 'medications_prescribed');
      const sets = [
        'diagnosis = ?',
        'treatment_plan = ?',
        'vital_signs = ?',
        'recommendations = ?',
      ];
      const vals = [
        visitSummary || observations,
        observations,
        vitalSigns,
        recommendations,
      ];
      if (hasMedUp) {
        sets.push('medications_prescribed = ?');
        vals.push(medications);
      }
      vals.push(reportId, providerId);
      await db.execute(
        `UPDATE visit_reports SET ${sets.join(', ')} WHERE id = ? AND provider_id = ?`,
        vals,
      );
      const medSelUp = hasMedUp
        ? 'vr.medications_prescribed'
        : "'' AS medications_prescribed";
      const [updated] = await db.query(
        `SELECT vr.id, vr.patient_id, vr.provider_id, vr.vital_signs, vr.diagnosis,
                vr.treatment_plan, vr.recommendations, ${medSelUp},
                vr.created_at, vr.visit_date, u.fullName AS patientName
         FROM visit_reports vr
         LEFT JOIN user u ON u.userId = vr.patient_id
         WHERE vr.id = ?`,
        [reportId],
      );
      return res.json(mapVisitReportRow(updated[0]));
    }

    if (!patientId || !appointmentId) {
      return res.status(400).json({
        error: 'patientId and requestId (appointment) are required for new reports',
      });
    }

    const okLink = await medicalRecordService.appointmentLinksPatientProvider(
      appointmentId,
      patientId,
      providerId,
    );
    if (!okLink) {
      return res.status(400).json({
        error: 'requestId does not match this patient and provider',
      });
    }

    const row = await medicalRecordService.insertVisitReport({
      patient_id: patientId,
      provider_id: providerId,
      appointment_id: appointmentId,
      vital_signs: vitalSigns,
      diagnosis: visitSummary || observations || 'Visit report',
      treatment_plan: observations,
      recommendations,
      follow_up_required: false,
      medications_prescribed: medications,
    });

    const hasMedIns = await hasColumn('visit_reports', 'medications_prescribed');
    const medSelIns = hasMedIns
      ? 'vr.medications_prescribed'
      : "'' AS medications_prescribed";
    const [full] = await db.query(
      `SELECT vr.id, vr.patient_id, vr.provider_id, vr.vital_signs, vr.diagnosis,
              vr.treatment_plan, vr.recommendations, ${medSelIns},
              vr.created_at, vr.visit_date, u.fullName AS patientName
       FROM visit_reports vr
       LEFT JOIN user u ON u.userId = vr.patient_id
       WHERE vr.id = ?`,
      [row.id],
    );
    res.status(201).json(mapVisitReportRow(full[0]));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/** --- Profile, certs, availability --- */
router.get('/profile/:providerId', async (req, res) => {
  const { providerId } = req.params;
  try {
    const hasExp = await hasColumn('careprovider', 'experienceYears');
    const hasHourly = await hasColumn('careprovider', 'hourlyRate');
    const hasFee = await hasColumn('careprovider', 'consultationFee');
    const expSel = hasExp ? 'c.experienceYears' : '0 AS experienceYears';
    const rateSel =
      hasHourly && hasFee
        ? 'COALESCE(c.hourlyRate, c.consultationFee, 0) AS hourlyRate'
        : hasHourly
          ? 'COALESCE(c.hourlyRate, 0) AS hourlyRate'
          : hasFee
            ? 'COALESCE(c.consultationFee, 0) AS hourlyRate'
            : '0 AS hourlyRate';

    const [rows] = await db.query(
      `SELECT u.userId AS providerId, u.fullName, u.email, u.phone,
              c.specialization, c.isAvailable, c.serviceType,
              ${expSel}, ${rateSel}
       FROM user u
       JOIN careprovider c ON c.userId = u.userId
       WHERE u.userId = ?`,
      [providerId],
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Provider not found' });
    }
    const r = rows[0];
    await ensureAuxTables();
    const [certs] = await db.query(
      `SELECT name FROM provider_certification WHERE providerUserId = ? ORDER BY createdAt DESC`,
      [providerId],
    );

    const [slots] = await db.query(
      `SELECT day, startTime, endTime FROM availabilityslot WHERE providerUserId = ?`,
      [providerId],
    );
    const availabilitySchedule = {};
    for (const s of slots) {
      availabilitySchedule[s.day] = `${s.startTime}-${s.endTime}`;
    }

    res.json({
      providerId: r.providerId,
      fullName: r.fullName || '',
      email: r.email || '',
      phone: r.phone || '',
      bio: (r.serviceType || '').toString(),
      specialization: r.specialization || '',
      experienceYears: Number(r.experienceYears || 0),
      hourlyRate: Number(r.hourlyRate || 0),
      isAvailable: r.isAvailable === 1 || r.isAvailable === true,
      certifications: certs.map((x) => x.name),
      availabilitySchedule,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/profile/:providerId', async (req, res) => {
  const { providerId } = req.params;
  const b = req.body || {};
  try {
    const fullName = (b.fullName || '').toString().trim();
    const email = (b.email || '').toString().trim();
    const phone = (b.phone || '').toString().trim();
    const specialization = (b.specialization || '').toString().trim();
    const bio = (b.bio || '').toString().trim();
    const experienceYears = Number(b.experienceYears || 0);
    const hourlyRate = Number(b.hourlyRate || 0);
    const isAvailable =
      b.isAvailable === true || b.isAvailable === 1 || b.isAvailable === '1';

    if (fullName) {
      await db.execute(`UPDATE user SET fullName = ? WHERE userId = ?`, [
        fullName,
        providerId,
      ]);
    }
    if (email) {
      await db.execute(`UPDATE user SET email = ? WHERE userId = ?`, [
        email,
        providerId,
      ]);
    }
    if (phone) {
      await db.execute(`UPDATE user SET phone = ? WHERE userId = ?`, [
        phone,
        providerId,
      ]);
    }

    const hasHourly = await hasColumn('careprovider', 'hourlyRate');
    const hasFee = await hasColumn('careprovider', 'consultationFee');
    const hasExp = await hasColumn('careprovider', 'experienceYears');
    const sets = ['specialization = ?', 'isAvailable = ?', 'serviceType = ?'];
    const vals = [specialization, isAvailable ? 1 : 0, bio || specialization];
    if (hasExp) {
      sets.push('experienceYears = ?');
      vals.push(Number.isFinite(experienceYears) ? experienceYears : 0);
    }
    if (hasHourly) {
      sets.push('hourlyRate = ?');
      vals.push(hourlyRate);
    } else if (hasFee) {
      sets.push('consultationFee = ?');
      vals.push(hourlyRate);
    }
    vals.push(providerId);
    await db.execute(
      `UPDATE careprovider SET ${sets.join(', ')} WHERE userId = ?`,
      vals,
    );

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/certifications/:providerId', async (req, res) => {
  const { providerId } = req.params;
  const name = ((req.body || {}).name || '').toString().trim();
  if (!name) return res.status(400).json({ error: 'name is required' });
  try {
    await ensureAuxTables();
    const certId = randomUUID();
    await db.execute(
      `INSERT INTO provider_certification (certId, providerUserId, name) VALUES (?, ?, ?)`,
      [certId, providerId, name],
    );
    res.status(201).json({ certId, success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/availability/:providerId', async (req, res) => {
  const { providerId } = req.params;
  try {
    const [slots] = await db.query(
      `SELECT day, startTime, endTime FROM availabilityslot WHERE providerUserId = ? ORDER BY day, startTime`,
      [providerId],
    );
    res.json(slots);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/availability/:providerId', async (req, res) => {
  const { providerId } = req.params;
  const slots = (req.body || {}).slots;
  if (!Array.isArray(slots)) {
    return res.status(400).json({ error: 'slots array required' });
  }
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    await conn.execute(`DELETE FROM availabilityslot WHERE providerUserId = ?`, [
      providerId,
    ]);
    for (const s of slots) {
      const day = (s.day ?? s['day'] ?? '').toString().trim();
      const startTime = (s.startTime ?? s['start'] ?? '').toString().trim();
      const endTime = (s.endTime ?? s['end'] ?? '').toString().trim();
      if (!day || !startTime || !endTime) continue;
      const slotId = randomUUID();
      await conn.execute(
        `INSERT INTO availabilityslot (slotId, providerUserId, day, startTime, endTime)
         VALUES (?, ?, ?, ?, ?)`,
        [slotId, providerId, day, startTime, endTime],
      );
    }
    await conn.commit();
    res.json({ success: true });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

/** --- Nurse payout methods / history (lightweight) --- */
router.get('/payment-methods/:providerId', async (req, res) => {
  const { providerId } = req.params;
  try {
    await ensureAuxTables();
    const [rows] = await db.query(
      `SELECT methodId AS id, providerUserId AS providerId, type, details, isDefault
       FROM provider_payment_method WHERE providerUserId = ?`,
      [providerId],
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/payment-methods/:providerId', async (req, res) => {
  const { providerId } = req.params;
  const b = req.body || {};
  try {
    await ensureAuxTables();
    const methodId = randomUUID();
    const isDef = b.isDefault === 1 || b.isDefault === true;
    if (isDef) {
      await db.execute(
        `UPDATE provider_payment_method SET isDefault = 0 WHERE providerUserId = ?`,
        [providerId],
      );
    }
    await db.execute(
      `INSERT INTO provider_payment_method (methodId, providerUserId, type, details, isDefault)
       VALUES (?, ?, ?, ?, ?)`,
      [
        methodId,
        providerId,
        (b.type || '').toString(),
        (b.details || '').toString(),
        isDef ? 1 : 0,
      ],
    );
    res.status(201).json({ success: true, id: methodId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/payment-methods/:providerId/:methodId', async (req, res) => {
  const { providerId, methodId } = req.params;
  const b = req.body || {};
  try {
    await ensureAuxTables();
    const isDef = b.isDefault === 1 || b.isDefault === true;
    if (isDef) {
      await db.execute(
        `UPDATE provider_payment_method SET isDefault = 0 WHERE providerUserId = ?`,
        [providerId],
      );
    }
    await db.execute(
      `UPDATE provider_payment_method SET type = ?, details = ?, isDefault = ?
       WHERE methodId = ? AND providerUserId = ?`,
      [
        (b.type || '').toString(),
        (b.details || '').toString(),
        isDef ? 1 : 0,
        methodId,
        providerId,
      ],
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/payment-methods/:providerId/:methodId', async (req, res) => {
  const { providerId, methodId } = req.params;
  try {
    await ensureAuxTables();
    await db.execute(
      `DELETE FROM provider_payment_method WHERE methodId = ? AND providerUserId = ?`,
      [methodId, providerId],
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/payments/:providerId', async (req, res) => {
  const { providerId } = req.params;
  try {
    const [rows] = await db.query(
      `SELECT p.paymentId AS id, p.providerUserId AS providerId,
              sr.serviceType AS service, pu.fullName AS patientName,
              p.amount, p.paymentStatus AS status, p.paymentMethod AS paymentMethod,
              p.createdAt AS date
       FROM payment p
       LEFT JOIN servicerequest sr ON sr.requestId = p.requestId
       LEFT JOIN user pu ON pu.userId = p.patientUserId
       WHERE p.providerUserId = ?
       ORDER BY p.createdAt DESC
       LIMIT 200`,
      [providerId],
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/payments/:providerId/summary', async (req, res) => {
  const { providerId } = req.params;
  try {
    const [[m]] = await db.query(
      `SELECT
        COALESCE(SUM(CASE
          WHEN YEAR(createdAt) = YEAR(CURDATE()) AND MONTH(createdAt) = MONTH(CURDATE())
          THEN amount ELSE 0 END), 0) AS monthSum,
        COALESCE(SUM(CASE
          WHEN YEARWEEK(createdAt, 1) = YEARWEEK(CURDATE(), 1)
          THEN amount ELSE 0 END), 0) AS weekSum,
        COALESCE(SUM(CASE WHEN DATE(createdAt) = CURDATE() THEN amount ELSE 0 END), 0) AS daySum
       FROM payment
       WHERE providerUserId = ? AND paymentStatus IN ('paid','pending')`,
      [providerId],
    );
    res.json({
      thisMonth: Number(m?.monthSum || 0),
      thisWeek: Number(m?.weekSum || 0),
      today: Number(m?.daySum || 0),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/payments/:providerId/:transactionId/status', async (req, res) => {
  const { providerId, transactionId } = req.params;
  const st = ((req.body || {}).status || 'paid').toString().toLowerCase();
  try {
    const hasUpdated = await hasColumn('payment', 'updatedAt');
    if (hasUpdated) {
      await db.execute(
        `UPDATE payment SET paymentStatus = ?, updatedAt = NOW()
         WHERE paymentId = ? AND providerUserId = ?`,
        [st, transactionId, providerId],
      );
    } else {
      await db.execute(
        `UPDATE payment SET paymentStatus = ?
         WHERE paymentId = ? AND providerUserId = ?`,
        [st, transactionId, providerId],
      );
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

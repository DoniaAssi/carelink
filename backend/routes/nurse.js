const express = require('express');
const { randomUUID } = require('crypto');
const db = require('../db');
const { insertNotification } = require('../notifications');
const medicalRecordService = require('../services/medicalRecordService');

const router = express.Router();

const columnCache = new Map();
const DEFAULT_VISIT_PAYMENT_AMOUNT = 25;

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

async function hasTable(tableName) {
  const key = `table.${tableName}`;
  if (columnCache.has(key)) return columnCache.get(key);
  try {
    const [rows] = await db.query(`SHOW TABLES LIKE ?`, [tableName]);
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

async function ensureServiceVisitWorkflowColumns() {
  const additions = [
    ['actualStartedAt', 'DATETIME NULL'],
    ['actualEndedAt', 'DATETIME NULL'],
    ['actualDurationMinutes', 'INT NOT NULL DEFAULT 0'],
    ['nursingActivities', 'TEXT NULL'],
  ];
  for (const [column, type] of additions) {
    if (!(await hasColumn('servicerequest', column))) {
      await db.query(`ALTER TABLE servicerequest ADD COLUMN ${column} ${type}`);
      columnCache.set(`servicerequest.${column}`, true);
    }
  }
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
         AND status IN ('confirmed','in_progress','waiting_report')
         AND DATE(scheduledAt) = CURDATE()`,
      [userId],
    );
    const [[waitingReports]] = await db.query(
      `SELECT COUNT(*) AS c FROM servicerequest
       WHERE providerUserId = ? AND status = 'waiting_report'`,
      [userId],
    );
    const [[done]] = await db.query(
      `SELECT COUNT(*) AS c FROM servicerequest
       WHERE providerUserId = ? AND status = 'completed'`,
      [userId],
    );

    let weeklyEarnings = 0;
    try {
      await syncProviderPayments(userId);
      const queryParts = [];
      const params = [];
      if (await hasTable('payment')) {
        queryParts.push(
          `SELECT amount, paymentStatus AS status, createdAt
           FROM payment
           WHERE providerUserId = ?`
        );
        params.push(userId);
      }
      if (await hasTable('payments')) {
        queryParts.push(
          `SELECT amount, status AS status, created_at AS createdAt
           FROM payments
           WHERE provider_id = ?`
        );
        params.push(userId);
      }
      if (queryParts.length) {
        const [[pay]] = await db.query(
          `SELECT COALESCE(SUM(amount), 0) AS s FROM (
             ${queryParts.join(' UNION ALL ')}
           ) AS allp
           WHERE status IN ('paid', 'pending', 'unpaid')
             AND YEARWEEK(createdAt, 1) = YEARWEEK(CURDATE(), 1)`,
          params,
        );
        weeklyEarnings = Number(pay?.s || 0);
      }
    } catch (_) {}

    res.json({
      pendingRequests: Number(pending?.c || 0),
      todaysVisits: Number(today?.c || 0),
      waitingReports: Number(waitingReports?.c || 0),
      completedVisits: Number(done?.c || 0),
      weeklyEarnings,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/** --- Service requests (list + status) --- */
async function listRequestsForProvider(providerUserId, statusQ) {
  await ensureServiceVisitWorkflowColumns();
  const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');
  const hasVisitLatitude = await hasColumn('servicerequest', 'visitLatitude');
  const hasVisitLongitude = await hasColumn('servicerequest', 'visitLongitude');
  const hasCreatedAt = await hasColumn('servicerequest', 'createdAt');
  const hasReasonForVisit = await hasColumn('servicerequest', 'reasonForVisit');
  const hasPatientLat = await hasColumn('patient', 'gpsLat');
  const hasPatientLng = await hasColumn('patient', 'gpsLng');
  const hasPatientAddress = await hasColumn('patient', 'addressText');
  const hasMedicalDob = await hasColumn('medicalrecord', 'dateOfBirth');
  const hasPaymentTable = await hasTable('payment');
  const createdExpr = hasCreatedAt ? 'sr.createdAt' : 'sr.scheduledAt';
  const visitAddressSel = hasVisitAddress ? 'sr.visitAddress' : "'' AS visitAddress";
  const visitLatSel = hasVisitLatitude ? 'sr.visitLatitude' : 'NULL AS visitLatitude';
  const visitLngSel = hasVisitLongitude ? 'sr.visitLongitude' : 'NULL AS visitLongitude';
  const reasonSel = hasReasonForVisit ? 'sr.reasonForVisit' : "'' AS reasonForVisit";
  const patientLatSel = hasPatientLat ? 'pat.gpsLat' : 'NULL AS gpsLat';
  const patientLngSel = hasPatientLng ? 'pat.gpsLng' : 'NULL AS gpsLng';
  const patientAddressSel = hasPatientAddress ? 'pat.addressText' : "'' AS patientAddress";
  const dobSel = hasMedicalDob ? 'mr.dateOfBirth' : 'NULL AS dateOfBirth';
  const priceSel = hasPaymentTable ? 'p.amount' : 'NULL AS amount';

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
        ${reasonSel},
        sr.location,
        sr.scheduledAt,
        sr.confirmedAt,
        sr.completedAt,
        sr.actualStartedAt,
        sr.actualEndedAt,
        sr.actualDurationMinutes,
        sr.nursingActivities,
        ${visitAddressSel},
        ${visitLatSel},
        ${visitLngSel},
        ${createdExpr} AS createdAt,
        pu.fullName AS patientName,
        pu.phone AS patientPhone,
        ${patientLatSel},
        ${patientLngSel},
        ${patientAddressSel},
        ${dobSel},
        ${priceSel}
     FROM servicerequest sr
     LEFT JOIN user pu ON BINARY sr.patientUserId = BINARY pu.userId
     LEFT JOIN patient pat ON BINARY pat.userId = BINARY sr.patientUserId
     LEFT JOIN medicalrecord mr ON BINARY mr.patientUserId = BINARY sr.patientUserId
     ${hasPaymentTable ? 'LEFT JOIN payment p ON BINARY p.requestId = BINARY sr.requestId' : ''}
     WHERE BINARY sr.providerUserId = BINARY ?${statusClause}
     ORDER BY sr.scheduledAt DESC
     LIMIT 500`,
    params,
  );

  return rows.map((r) => {
    const noteText = (r.notes || '').toString();
    const addressMatch = /Address:\s*([^|]+)/i.exec(noteText);
    const gpsMatch = /VisitGPS:\s*([-.\d]+)\s*,\s*([-.\d]+)/i.exec(noteText);
    const parsedAddress = addressMatch ? addressMatch[1].trim() : '';
    const parsedLat = gpsMatch ? Number(gpsMatch[1]) : null;
    const parsedLng = gpsMatch ? Number(gpsMatch[2]) : null;
    return {
      requestId: r.requestId,
      patientUserId: r.patientUserId,
      providerUserId: r.providerUserId,
      patientId: r.patientUserId,
      providerId: r.providerUserId,
      patientName: r.patientName || '',
      patientPhone: r.patientPhone || '',
      patientAge: r.dateOfBirth ? Math.max(0, new Date().getFullYear() - new Date(r.dateOfBirth).getFullYear()) : 0,
      serviceType: r.serviceType || '',
      location: (r.visitAddress && String(r.visitAddress).trim()) || r.location || parsedAddress || r.patientAddress || '',
      patientAddress: r.patientAddress || '',
      gpsLat: r.visitLatitude ?? r.gpsLat ?? parsedLat,
      gpsLng: r.visitLongitude ?? r.gpsLng ?? parsedLng,
      status: r.status,
      notes: r.notes,
      reasonForVisit: r.reasonForVisit || '',
      medicalCondition: r.reasonForVisit || r.notes || '',
      scheduledAt: r.scheduledAt,
      scheduledDate: r.scheduledAt,
      expectedDurationHours: 2,
      price: r.amount == null ? 0 : Number(r.amount || 0),
      actualStartedAt: r.actualStartedAt,
      actualEndedAt: r.actualEndedAt,
      actualDurationMinutes: Number(r.actualDurationMinutes || 0),
      nursingActivities: (() => {
        try {
          return r.nursingActivities ? JSON.parse(r.nursingActivities) : [];
        } catch (_) {
          return [];
        }
      })(),
      createdAt: r.createdAt,
    };
  });
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
    if (normalizedStatus === 'scheduled' || normalizedStatus === 'assigned') {
      normalizedStatus = 'confirmed';
    }

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

  const allowed = new Set([
    'confirmed',
    'cancelled',
    'in_progress',
    'waiting_report',
    'completed',
  ]);
  if (!allowed.has(next)) {
    return res.status(400).json({
      error:
        'status must be one of: confirmed, cancelled, in_progress, waiting_report, completed',
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
      if (next !== 'in_progress' && next !== 'cancelled' && next !== 'completed') {
        return res
          .status(400)
          .json({ error: 'From confirmed, only in_progress, completed or cancelled' });
      }
    } else if (current === 'in_progress') {
      if (next !== 'waiting_report' && next !== 'completed') {
        return res
          .status(400)
          .json({ error: 'From in_progress, only waiting_report or completed' });
      }
    } else if (current === 'waiting_report') {
      if (next !== 'completed') {
        return res
          .status(400)
          .json({ error: 'From waiting_report, only completed' });
      }
    } else {
      return res.status(400).json({ error: 'Unexpected current status' });
    }

    await db.execute(
      `UPDATE servicerequest SET status = ? WHERE requestId = ? AND providerUserId = ?`,
      [next, requestId, providerUserId],
    );
    if (next === 'confirmed') {
      try {
        await ensurePaymentForRequest(requestId);
      } catch (_) {}
    }

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

router.post('/requests/:requestId/start', async (req, res) => {
  const { requestId } = req.params;
  const providerUserId = (req.body?.providerUserId || '').toString().trim();
  if (!providerUserId) {
    return res.status(400).json({ error: 'providerUserId is required' });
  }
  try {
    await ensureServiceVisitWorkflowColumns();
    const [rows] = await db.query(
      `SELECT requestId, patientUserId, providerUserId, status, actualStartedAt
       FROM servicerequest
       WHERE BINARY requestId = BINARY ?`,
      [requestId],
    );
    if (!rows.length) return res.status(404).json({ error: 'Request not found' });
    const row = rows[0];
    if (row.providerUserId !== providerUserId) {
      return res.status(403).json({ error: 'Not allowed for this provider' });
    }
    const current = (row.status || '').toString().toLowerCase();
    if (!['confirmed', 'in_progress'].includes(current)) {
      return res.status(400).json({ error: 'Only assigned visits can be started' });
    }
    await db.execute(
      `UPDATE servicerequest
       SET status = 'in_progress',
           actualStartedAt = COALESCE(actualStartedAt, NOW())
       WHERE BINARY requestId = BINARY ? AND BINARY providerUserId = BINARY ?`,
      [requestId, providerUserId],
    );
    try {
      await insertNotification({
        userId: row.patientUserId,
        type: 'appointment',
        title: 'بدأت الزيارة',
        body: 'الممرض بدأ زيارة الخدمة الآن.',
        relatedRequestId: requestId,
      });
    } catch (_) {}
    res.json({ success: true, requestId, status: 'in_progress' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/requests/:requestId/end', async (req, res) => {
  const { requestId } = req.params;
  const providerUserId = (req.body?.providerUserId || '').toString().trim();
  const nursingActivities = Array.isArray(req.body?.nursingActivities)
    ? req.body.nursingActivities
    : [];
  if (!providerUserId) {
    return res.status(400).json({ error: 'providerUserId is required' });
  }
  try {
    await ensureServiceVisitWorkflowColumns();
    const [rows] = await db.query(
      `SELECT requestId, providerUserId, status, actualStartedAt
       FROM servicerequest
       WHERE BINARY requestId = BINARY ?`,
      [requestId],
    );
    if (!rows.length) return res.status(404).json({ error: 'Request not found' });
    const row = rows[0];
    if (row.providerUserId !== providerUserId) {
      return res.status(403).json({ error: 'Not allowed for this provider' });
    }
    const current = (row.status || '').toString().toLowerCase();
    if (current !== 'in_progress') {
      return res.status(400).json({ error: 'Only in-progress visits can be ended' });
    }
    await db.execute(
      `UPDATE servicerequest
       SET status = 'waiting_report',
           actualEndedAt = NOW(),
           actualDurationMinutes = GREATEST(
             0,
             TIMESTAMPDIFF(MINUTE, COALESCE(actualStartedAt, NOW()), NOW())
           ),
           nursingActivities = ?
       WHERE BINARY requestId = BINARY ? AND BINARY providerUserId = BINARY ?`,
      [JSON.stringify(nursingActivities), requestId, providerUserId],
    );
    res.json({ success: true, requestId, status: 'waiting_report' });
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
      await ensurePaymentForRequest(recommendationId);
    } catch (_) {}
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
async function ensureVisitReportUiColumns() {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS visit_reports (
      id CHAR(36) NOT NULL PRIMARY KEY,
      patient_id CHAR(36) NOT NULL,
      provider_id CHAR(36) NOT NULL,
      appointment_id CHAR(36) NULL,
      vital_signs TEXT NULL,
      diagnosis TEXT NULL,
      treatment_plan TEXT NULL,
      recommendations TEXT NULL,
      follow_up_required TINYINT(1) NOT NULL DEFAULT 0,
      follow_up_date DATE NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      KEY idx_vr_patient (patient_id),
      KEY idx_vr_provider (provider_id),
      KEY idx_vr_appt (appointment_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
  if (!(await hasColumn('visit_reports', 'visit_date'))) {
    try {
      await db.execute(`ALTER TABLE visit_reports ADD COLUMN visit_date DATE NULL`);
      columnCache.set('visit_reports.visit_date', true);
    } catch (_) {}
  }
  if (!(await hasColumn('visit_reports', 'medications_prescribed'))) {
    try {
      await db.execute(
        `ALTER TABLE visit_reports ADD COLUMN medications_prescribed TEXT NULL`
      );
      columnCache.set('visit_reports.medications_prescribed', true);
    } catch (_) {}
  }
  if (!(await hasColumn('visit_reports', 'duration_hours'))) {
    try {
      await db.execute(
        `ALTER TABLE visit_reports ADD COLUMN duration_hours INT NOT NULL DEFAULT 0`
      );
      columnCache.set('visit_reports.duration_hours', true);
    } catch (_) {}
  }
  if (!(await hasColumn('visit_reports', 'manual_patient_name'))) {
    try {
      await db.execute(
        `ALTER TABLE visit_reports ADD COLUMN manual_patient_name VARCHAR(255) NULL`
      );
      columnCache.set('visit_reports.manual_patient_name', true);
    } catch (_) {}
  }
}

async function ensurePaymentTable() {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS payment (
      paymentId CHAR(36) NOT NULL PRIMARY KEY,
      requestId CHAR(36) NOT NULL,
      patientUserId CHAR(36) NOT NULL,
      providerUserId CHAR(36) NOT NULL,
      amount DECIMAL(10,2) NOT NULL DEFAULT 0,
      paymentMethod VARCHAR(64) NOT NULL DEFAULT 'cash',
      paymentStatus VARCHAR(32) NOT NULL DEFAULT 'pending',
      createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_payment_request (requestId),
      KEY idx_payment_provider (providerUserId),
      KEY idx_payment_patient (patientUserId)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
  const additions = [
    ['paymentMethod', `ALTER TABLE payment ADD COLUMN paymentMethod VARCHAR(64) NOT NULL DEFAULT 'cash'`],
    ['paymentStatus', `ALTER TABLE payment ADD COLUMN paymentStatus VARCHAR(32) NOT NULL DEFAULT 'pending'`],
    ['createdAt', `ALTER TABLE payment ADD COLUMN createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`],
    ['updatedAt', `ALTER TABLE payment ADD COLUMN updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`],
  ];
  for (const [column, sql] of additions) {
    if (await hasColumn('payment', column)) continue;
    try {
      await db.execute(sql);
      columnCache.set(`payment.${column}`, true);
    } catch (_) {}
  }
  try {
    await db.execute(`ALTER TABLE payment ADD UNIQUE KEY uq_payment_request (requestId)`);
  } catch (_) {}
}

async function ensurePaymentForRequest(requestId) {
  await ensurePaymentTable();
  const hasHourly = await hasColumn('careprovider', 'hourlyRate');
  const hasFee = await hasColumn('careprovider', 'consultationFee');
  const rateExpr =
    hasHourly && hasFee
      ? 'COALESCE(c.hourlyRate, c.consultationFee, 0)'
      : hasHourly
        ? 'COALESCE(c.hourlyRate, 0)'
        : hasFee
          ? 'COALESCE(c.consultationFee, 0)'
          : '0';
  const [rows] = await db.query(
    `SELECT sr.requestId, sr.patientUserId, sr.providerUserId,
            ${rateExpr} AS rate
     FROM servicerequest sr
     LEFT JOIN careprovider c ON c.userId = sr.providerUserId
     WHERE sr.requestId = ?
     LIMIT 1`,
    [requestId],
  );
  if (!rows.length) return;
  const r = rows[0];
  const amount = Number(r.rate || 0) || DEFAULT_VISIT_PAYMENT_AMOUNT;
  await db.execute(
    `INSERT INTO payment
       (paymentId, requestId, patientUserId, providerUserId, amount, paymentMethod, paymentStatus, createdAt, updatedAt)
     VALUES (?, ?, ?, ?, ?, 'cash', 'pending', NOW(), NOW())
     ON DUPLICATE KEY UPDATE
       providerUserId = VALUES(providerUserId),
       patientUserId = VALUES(patientUserId),
       amount = CASE WHEN amount = 0 THEN VALUES(amount) ELSE amount END,
       updatedAt = NOW()`,
    [randomUUID(), r.requestId, r.patientUserId, r.providerUserId, amount],
  );
}

async function syncProviderPayments(providerId) {
  const [rows] = await db.query(
    `SELECT requestId
     FROM servicerequest
     WHERE providerUserId = ?
       AND status IN ('confirmed', 'completed')
     ORDER BY scheduledAt DESC
     LIMIT 200`,
    [providerId],
  );
  for (const row of rows) {
    await ensurePaymentForRequest(row.requestId);
  }
}

function toDateOnly(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) {
    const raw = value.toString().slice(0, 10);
    return /^\d{4}-\d{2}-\d{2}$/.test(raw) ? raw : null;
  }
  return d.toISOString().slice(0, 10);
}

function mapVisitReportRow(r) {
  const scheduled =
    r.scheduledAt ||
    r.visit_date ||
    (r.created_at ? String(r.created_at).slice(0, 10) : '') ||
    new Date().toISOString();
  return {
    id: r.id,
    requestId: r.appointment_id || '',
    providerId: r.provider_id,
    patientId: r.patient_id,
    patientName: r.patientName || r.manual_patient_name || '',
    serviceType: r.serviceType || '',
    location:
      (r.visitAddress && String(r.visitAddress).trim()) || r.location || '',
    scheduledDate: scheduled,
    durationHours: Number(r.duration_hours || 0),
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

function mapLegacyVisitReportRow(r) {
  const scheduled =
    r.scheduledAt ||
    r.createdAt ||
    r.created_at ||
    new Date().toISOString();
  return {
    id: `legacy:${r.reportId}`,
    requestId: r.requestId || '',
    providerId: r.providerUserId || '',
    patientId: r.patientUserId || '',
    patientName: r.patientName || '',
    serviceType: r.serviceType || 'Visit Report',
    location: r.location || '',
    scheduledDate: scheduled,
    durationHours: 0,
    visitSummary: r.notes || r.diagnosis || '',
    vitalSigns: '',
    medications: '',
    observations: r.diagnosis || '',
    recommendations: '',
    status: 'completed',
    createdAt: scheduled,
    updatedAt: scheduled,
  };
}

router.get('/reports/:providerId', async (req, res) => {
  const { providerId } = req.params;
  try {
    await ensureVisitReportUiColumns();
    const hasMed = await hasColumn('visit_reports', 'medications_prescribed');
    const medSel = hasMed ? 'vr.medications_prescribed' : "'' AS medications_prescribed";
    const hasDuration = await hasColumn('visit_reports', 'duration_hours');
    const durationSel = hasDuration ? 'vr.duration_hours' : '0 AS duration_hours';
    const hasManualName = await hasColumn('visit_reports', 'manual_patient_name');
    const manualNameSel = hasManualName ? 'vr.manual_patient_name' : "'' AS manual_patient_name";
    const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');
    const visitAddressSel = hasVisitAddress ? 'sr.visitAddress' : "'' AS visitAddress";

    let [rows] = await db.query(
      `SELECT vr.id, vr.patient_id, vr.provider_id, vr.appointment_id,
              vr.vital_signs, vr.diagnosis, vr.treatment_plan, vr.recommendations,
              ${medSel}, ${durationSel}, ${manualNameSel},
              vr.created_at, vr.visit_date,
              u.fullName AS patientName,
              sr.serviceType, sr.location, ${visitAddressSel}, sr.scheduledAt
       FROM visit_reports vr
       LEFT JOIN user u ON BINARY u.userId = BINARY vr.patient_id
       LEFT JOIN servicerequest sr ON BINARY sr.requestId = BINARY vr.appointment_id
       WHERE BINARY vr.provider_id = BINARY ?
       ORDER BY vr.created_at DESC
       LIMIT 200`,
      [providerId],
    );
    if (!rows.length) {
      [rows] = await db.query(
        `SELECT vr.id, vr.patient_id, vr.provider_id, vr.appointment_id,
                vr.vital_signs, vr.diagnosis, vr.treatment_plan, vr.recommendations,
                ${medSel}, ${durationSel}, ${manualNameSel},
                vr.created_at, vr.visit_date,
                u.fullName AS patientName,
                sr.serviceType, sr.location, ${visitAddressSel}, sr.scheduledAt
         FROM visit_reports vr
         LEFT JOIN user u ON BINARY u.userId = BINARY vr.patient_id
         LEFT JOIN servicerequest sr ON BINARY sr.requestId = BINARY vr.appointment_id
         ORDER BY vr.created_at DESC
         LIMIT 200`,
      );
    }
    let out = rows.map(mapVisitReportRow);
    if (!out.length && (await hasTable('visitreport'))) {
      const [legacyRows] = await db.query(
        `SELECT r.reportId, r.notes, r.diagnosis,
                v.visitId, v.requestId,
                sr.patientUserId, sr.providerUserId, sr.serviceType,
                sr.location, sr.scheduledAt, sr.status,
                u.fullName AS patientName
         FROM visitreport r
         LEFT JOIN visit v ON BINARY v.visitId = BINARY r.visitId
         LEFT JOIN servicerequest sr ON BINARY sr.requestId = BINARY v.requestId
         LEFT JOIN user u ON BINARY u.userId = BINARY sr.patientUserId
         WHERE BINARY sr.providerUserId = BINARY ?
            OR sr.providerUserId IS NULL
         ORDER BY sr.scheduledAt DESC
         LIMIT 200`,
        [providerId],
      );
      out = legacyRows.map(mapLegacyVisitReportRow);
    }
    res.json(out);
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
  const serviceType = (b.serviceType || '').toString().trim();
  const location = (b.location || '').toString().trim();
  const scheduledDate = toDateOnly(b.scheduledDate || b.visitDate);
  const durationHours = Number.parseInt(b.durationHours, 10) || 0;
  const visitSummary = (b.visitSummary || '').toString().trim();
  const observations = (b.observations || '').toString().trim();
  const vitalSigns = (b.vitalSigns || '').toString().trim();
  const medications = (b.medications || '').toString().trim();
  const recommendations = (b.recommendations || '').toString().trim();

  try {
    await ensureVisitReportUiColumns();

    if (reportId) {
      if (reportId.startsWith('legacy:')) {
        const legacyId = reportId.substring('legacy:'.length);
        if (!(await hasTable('visitreport'))) {
          return res.status(404).json({ error: 'Legacy report table missing' });
        }
        await db.execute(
          `UPDATE visitreport SET notes = ?, diagnosis = ?
           WHERE BINARY reportId = BINARY ?`,
          [visitSummary || observations, observations || visitSummary, legacyId],
        );
        const [legacyRows] = await db.query(
          `SELECT r.reportId, r.notes, r.diagnosis,
                  v.visitId, v.requestId,
                  sr.patientUserId, sr.providerUserId, sr.serviceType,
                  sr.location, sr.scheduledAt, sr.status,
                  u.fullName AS patientName
           FROM visitreport r
           LEFT JOIN visit v ON BINARY v.visitId = BINARY r.visitId
           LEFT JOIN servicerequest sr ON BINARY sr.requestId = BINARY v.requestId
           LEFT JOIN user u ON BINARY u.userId = BINARY sr.patientUserId
           WHERE BINARY r.reportId = BINARY ?
           LIMIT 1`,
          [legacyId],
        );
        return res.json(mapLegacyVisitReportRow(legacyRows[0]));
      }
      const hasMedUp = await hasColumn('visit_reports', 'medications_prescribed');
      const hasVisitDateUp = await hasColumn('visit_reports', 'visit_date');
      const hasDurationUp = await hasColumn('visit_reports', 'duration_hours');
      const hasManualNameUp = await hasColumn('visit_reports', 'manual_patient_name');
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
      if (hasVisitDateUp && scheduledDate) {
        sets.push('visit_date = ?');
        vals.push(scheduledDate);
      }
      if (hasDurationUp) {
        sets.push('duration_hours = ?');
        vals.push(durationHours);
      }
      if (hasManualNameUp) {
        sets.push('manual_patient_name = ?');
        vals.push((b.patientName || '').toString().trim());
      }
      vals.push(reportId, providerId);
      await db.execute(
        `UPDATE visit_reports SET ${sets.join(', ')}
         WHERE BINARY id = BINARY ? AND BINARY provider_id = BINARY ?`,
        vals,
      );
      if (appointmentId && (serviceType || location || scheduledDate)) {
        const requestSets = [];
        const requestVals = [];
        if (serviceType) {
          requestSets.push('serviceType = ?');
          requestVals.push(serviceType);
        }
        if (location) {
          requestSets.push('location = ?');
          requestVals.push(location);
          if (await hasColumn('servicerequest', 'visitAddress')) {
            requestSets.push('visitAddress = ?');
            requestVals.push(location);
          }
        }
        if (scheduledDate) {
          requestSets.push('scheduledAt = ?');
          requestVals.push(`${scheduledDate} 00:00:00`);
        }
        if (requestSets.length) {
          requestVals.push(appointmentId, providerId);
          await db.execute(
            `UPDATE servicerequest SET ${requestSets.join(', ')}
             WHERE BINARY requestId = BINARY ? AND BINARY providerUserId = BINARY ?`,
            requestVals,
          );
        }
      }
      if (appointmentId) {
        await db.execute(
          `UPDATE servicerequest
           SET status = 'completed', completedAt = COALESCE(completedAt, NOW())
           WHERE BINARY requestId = BINARY ? AND BINARY providerUserId = BINARY ?`,
          [appointmentId, providerId],
        );
      }
      const medSelUp = hasMedUp
        ? 'vr.medications_prescribed'
        : "'' AS medications_prescribed";
      const durationSelUp = hasDurationUp
        ? 'vr.duration_hours'
        : '0 AS duration_hours';
      const manualNameSelUp = hasManualNameUp
        ? 'vr.manual_patient_name'
        : "'' AS manual_patient_name";
      const hasVisitAddressUp = await hasColumn('servicerequest', 'visitAddress');
      const visitAddressSelUp = hasVisitAddressUp
        ? 'sr.visitAddress'
        : "'' AS visitAddress";
      const [updated] = await db.query(
        `SELECT vr.id, vr.patient_id, vr.provider_id, vr.vital_signs, vr.diagnosis,
                vr.appointment_id, vr.treatment_plan, vr.recommendations,
                ${medSelUp}, ${durationSelUp}, ${manualNameSelUp},
                vr.created_at, vr.visit_date, u.fullName AS patientName,
                sr.serviceType, sr.location, ${visitAddressSelUp}, sr.scheduledAt
         FROM visit_reports vr
         LEFT JOIN user u ON BINARY u.userId = BINARY vr.patient_id
         LEFT JOIN servicerequest sr ON BINARY sr.requestId = BINARY vr.appointment_id
         WHERE BINARY vr.id = BINARY ?`,
        [reportId],
      );
      return res.json(mapVisitReportRow(updated[0]));
    }

    if (!patientId) {
      return res.status(400).json({
        error: 'patientId is required for new reports',
      });
    }

    const okLink = appointmentId
      ? await medicalRecordService.appointmentLinksPatientProvider(
          appointmentId,
          patientId,
          providerId,
        )
      : true;
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
      visit_date: scheduledDate,
      medications_prescribed: medications,
    });
    if (await hasColumn('visit_reports', 'manual_patient_name')) {
      await db.execute(`UPDATE visit_reports SET manual_patient_name = ? WHERE BINARY id = BINARY ?`, [
        (b.patientName || '').toString().trim(),
        row.id,
      ]);
    }
    if (durationHours > 0 && (await hasColumn('visit_reports', 'duration_hours'))) {
      await db.execute(`UPDATE visit_reports SET duration_hours = ? WHERE BINARY id = BINARY ?`, [
        durationHours,
        row.id,
      ]);
    }
    if (appointmentId) {
      await db.execute(
        `UPDATE servicerequest
         SET status = 'completed', completedAt = COALESCE(completedAt, NOW())
         WHERE BINARY requestId = BINARY ? AND BINARY providerUserId = BINARY ?`,
        [appointmentId, providerId],
      );
      try {
        const [requestRows] = await db.query(
          `SELECT patientUserId FROM servicerequest WHERE BINARY requestId = BINARY ? LIMIT 1`,
          [appointmentId],
        );
        if (requestRows.length) {
          await insertNotification({
            userId: requestRows[0].patientUserId,
            type: 'visit_completed',
            title: 'تم إنهاء الخدمة',
            body: 'تم إرسال تقرير الزيارة وأصبحت الخدمة مكتملة. يمكنك تقييم الممرض الآن.',
            relatedRequestId: appointmentId,
          });
        }
      } catch (_) {}
    }

    const hasMedIns = await hasColumn('visit_reports', 'medications_prescribed');
    const medSelIns = hasMedIns
      ? 'vr.medications_prescribed'
      : "'' AS medications_prescribed";
    const hasDurationIns = await hasColumn('visit_reports', 'duration_hours');
    const durationSelIns = hasDurationIns
      ? 'vr.duration_hours'
      : '0 AS duration_hours';
    const hasVisitAddressIns = await hasColumn('servicerequest', 'visitAddress');
    const visitAddressSelIns = hasVisitAddressIns
      ? 'sr.visitAddress'
      : "'' AS visitAddress";
    const hasManualNameIns = await hasColumn('visit_reports', 'manual_patient_name');
    const manualNameSelIns = hasManualNameIns
      ? 'vr.manual_patient_name'
      : "'' AS manual_patient_name";
    const [full] = await db.query(
      `SELECT vr.id, vr.patient_id, vr.provider_id, vr.vital_signs, vr.diagnosis,
              vr.appointment_id, vr.treatment_plan, vr.recommendations, ${medSelIns},
              ${durationSelIns}, ${manualNameSelIns}, vr.created_at, vr.visit_date, u.fullName AS patientName,
              sr.serviceType, sr.location, ${visitAddressSelIns}, sr.scheduledAt
       FROM visit_reports vr
       LEFT JOIN user u ON BINARY u.userId = BINARY vr.patient_id
       LEFT JOIN servicerequest sr ON BINARY sr.requestId = BINARY vr.appointment_id
       WHERE BINARY vr.id = BINARY ?`,
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
    const hasSlotId = await hasColumn('availabilityslot', 'slotId');
    const hasSlotUnderscore = await hasColumn('availabilityslot', 'slot_id');
    if (hasSlotId || hasSlotUnderscore) {
      await conn.execute(`DELETE FROM availabilityslot WHERE providerUserId = ? OR providerUserId IS NULL OR providerUserId = ''`, [
        providerId,
      ]);
    } else {
      await conn.execute(`DELETE FROM availabilityslot WHERE providerUserId = ?`, [
        providerId,
      ]);
    }
    for (const s of slots) {
      const day = (s.day ?? s['day'] ?? '').toString().trim();
      const startTime = (s.startTime ?? s['start'] ?? '').toString().trim();
      const endTime = (s.endTime ?? s['end'] ?? '').toString().trim();
      if (!day || !startTime || !endTime) continue;
      if (hasSlotId) {
        await conn.execute(
          `INSERT INTO availabilityslot (slotId, providerUserId, day, startTime, endTime)
           VALUES (?, ?, ?, ?, ?)`,
          [randomUUID(), providerId, day, startTime, endTime],
        );
      } else if (hasSlotUnderscore) {
        await conn.execute(
          `INSERT INTO availabilityslot (slot_id, providerUserId, day, startTime, endTime)
           VALUES (?, ?, ?, ?, ?)`,
          [randomUUID(), providerId, day, startTime, endTime],
        );
      } else {
        await conn.execute(
          `INSERT INTO availabilityslot (providerUserId, day, startTime, endTime)
           VALUES (?, ?, ?, ?)`,
          [providerId, day, startTime, endTime],
        );
      }
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
    await syncProviderPayments(providerId);
    const queryParts = [];
    const params = [];
    if (await hasTable('payment')) {
      queryParts.push(
        `SELECT p.paymentId AS id, p.providerUserId AS providerId,
                sr.serviceType AS service, pu.fullName AS patientName,
                p.amount, p.paymentStatus AS status, p.paymentMethod AS paymentMethod,
                p.createdAt AS date
         FROM payment p
         LEFT JOIN servicerequest sr ON sr.requestId = p.requestId
         LEFT JOIN user pu ON pu.userId = p.patientUserId
         WHERE p.providerUserId = ?`
      );
      params.push(providerId);
    }
    if (await hasTable('payments')) {
      queryParts.push(
        `SELECT CAST(p.id AS CHAR(36)) AS id, p.provider_id AS providerId,
                sr.serviceType AS service, pu.fullName AS patientName,
                p.amount, p.status AS status, p.method AS paymentMethod,
                p.created_at AS date
         FROM payments p
         LEFT JOIN servicerequest sr ON sr.requestId = p.appointment_id
         LEFT JOIN user pu ON pu.userId = p.patient_id
         WHERE p.provider_id = ?`
      );
      params.push(providerId);
    }

    let rows = [];
    if (queryParts.length) {
      const [result] = await db.query(
        `SELECT * FROM (
           ${queryParts.join(' UNION ALL ')}
         ) AS allp
         ORDER BY date DESC
         LIMIT 200`,
        params,
      );
      rows = result;
    }
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/payments/:providerId/summary', async (req, res) => {
  const { providerId } = req.params;
  try {
    await syncProviderPayments(providerId);
    const queryParts = [];
    const params = [];
    if (await hasTable('payment')) {
      queryParts.push(
        `SELECT amount, paymentStatus AS status, createdAt
         FROM payment
         WHERE providerUserId = ?`
      );
      params.push(providerId);
    }
    if (await hasTable('payments')) {
      queryParts.push(
        `SELECT amount, status AS status, created_at AS createdAt
         FROM payments
         WHERE provider_id = ?`
      );
      params.push(providerId);
    }

    let m = { monthSum: 0, weekSum: 0, daySum: 0 };
    if (queryParts.length) {
      const [[result]] = await db.query(
        `SELECT
           COALESCE(SUM(CASE
             WHEN YEAR(createdAt) = YEAR(CURDATE()) AND MONTH(createdAt) = MONTH(CURDATE())
             THEN amount ELSE 0 END), 0) AS monthSum,
           COALESCE(SUM(CASE
             WHEN YEARWEEK(createdAt, 1) = YEARWEEK(CURDATE(), 1)
             THEN amount ELSE 0 END), 0) AS weekSum,
           COALESCE(SUM(CASE WHEN DATE(createdAt) = CURDATE() THEN amount ELSE 0 END), 0) AS daySum
         FROM (
           ${queryParts.join(' UNION ALL ')}
         ) AS allp
         WHERE status IN ('paid', 'pending', 'unpaid')`,
        params,
      );
      m = result;
    }
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
    if (await hasTable('payment')) {
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
    }
    if (await hasTable('payments')) {
      await db.execute(
        `UPDATE payments SET status = ?
         WHERE id = ? AND provider_id = ?`,
        [st, transactionId, providerId],
      );
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

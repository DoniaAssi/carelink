const express = require('express');
const bcrypt = require('bcrypt');
const { randomUUID } = require('crypto');
const db = require('../db');
const { insertNotification } = require('../notifications');
const visitRatingService = require('../services/visitRatingService');
const medicalRecordService = require('../services/medicalRecordService');
const initialDiagnosisReportService = require('../services/initialDiagnosisReportService');

const router = express.Router();
const columnCache = new Map();
const tableCache = new Map();

function dbBool(value) {
  if (typeof value === 'bigint') return value === 1n;
  if (Buffer.isBuffer(value)) return value.length > 0 && value[0] === 1;
  return (
    value === true ||
    value === 1 ||
    value === '1' ||
    value?.toString?.().toLowerCase?.() === 'true'
  );
}

async function hasColumn(tableName, columnName) {
  const key = `${tableName}.${columnName}`;
  if (columnCache.has(key)) return columnCache.get(key);

  try {
    const [rows] = await db.query(
      `SHOW COLUMNS FROM ${tableName} LIKE ?`,
      [columnName]
    );
    const exists = rows.length > 0;
    columnCache.set(key, exists);
    return exists;
  } catch (_) {
    columnCache.set(key, false);
    return false;
  }
}

async function hasTable(tableName) {
  if (tableCache.has(tableName)) return tableCache.get(tableName);

  try {
    const [rows] = await db.query('SHOW TABLES LIKE ?', [tableName]);
    const exists = rows.length > 0;
    tableCache.set(tableName, exists);
    return exists;
  } catch (_) {
    tableCache.set(tableName, false);
    return false;
  }
}

async function ensureDoctorRateGateTables() {
  if (await hasTable('careprovider')) {
    const columns = [
      ['is_rate_approved', 'TINYINT(1) NOT NULL DEFAULT 0'],
      ['hourly_rate', 'DECIMAL(10,2) NULL'],
      ["status", "ENUM('pending','active','inactive') NOT NULL DEFAULT 'pending'"],
      ["experience_level", "ENUM('junior','mid','senior') NULL"],
    ];
    for (const [column, definition] of columns) {
      if (!(await hasColumn('careprovider', column))) {
        await db.execute(`ALTER TABLE careprovider ADD COLUMN ${column} ${definition}`);
        columnCache.set(`careprovider.${column}`, true);
      }
    }
  }

  await db.execute(`
    CREATE TABLE IF NOT EXISTS provider_rates (
      id INT AUTO_INCREMENT PRIMARY KEY,
      providerId CHAR(36) NOT NULL,
      provider_id CHAR(36) NULL,
      specialization VARCHAR(120) NOT NULL,
      provider_hour_rate DECIMAL(10,2) NOT NULL DEFAULT 0,
      provider_rate DECIMAL(10,2) NOT NULL DEFAULT 0,
      admin_rate DECIMAL(10,2) NOT NULL DEFAULT 0,
      patient_rate DECIMAL(10,2) NOT NULL DEFAULT 0,
      status VARCHAR(24) NOT NULL DEFAULT 'active',
      rateAcceptanceStatus ENUM('pending','accepted','rejected') NOT NULL DEFAULT 'pending',
      rateSetAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      rateAcceptedAt DATETIME NULL,
      rateRejectedAt DATETIME NULL,
      updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      KEY idx_provider_rates_provider (providerId),
      KEY idx_provider_rates_status (status, rateAcceptanceStatus)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
  const rateColumns = [
    ['provider_id', 'CHAR(36) NULL'],
    ['provider_hour_rate', 'DECIMAL(10,2) NOT NULL DEFAULT 0'],
    ['provider_rate', 'DECIMAL(10,2) NOT NULL DEFAULT 0'],
    ['admin_rate', 'DECIMAL(10,2) NOT NULL DEFAULT 0'],
    ['patient_rate', 'DECIMAL(10,2) NOT NULL DEFAULT 0'],
    ['status', "VARCHAR(24) NOT NULL DEFAULT 'active'"],
    [
      'rateAcceptanceStatus',
      "ENUM('pending','accepted','rejected') NOT NULL DEFAULT 'pending'",
    ],
    ['rateSetAt', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'],
    ['rateAcceptedAt', 'DATETIME NULL'],
    ['rateRejectedAt', 'DATETIME NULL'],
  ];
  for (const [column, definition] of rateColumns) {
    if (!(await hasColumn('provider_rates', column))) {
      await db.execute(`ALTER TABLE provider_rates ADD COLUMN ${column} ${definition}`);
      columnCache.set(`provider_rates.${column}`, true);
    }
  }
}

async function getProviderWorkEligibility(providerId) {
  await ensureDoctorRateGateTables();
  const [[profile]] = await db.query(
    `SELECT
       c.userId,
       COALESCE(c.specialization, c.serviceType, '') AS specialization,
       COALESCE(c.status, 'pending') AS providerStatus,
       COALESCE(c.approvalStatus, 'pending') AS approvalStatus,
       COALESCE(c.is_rate_approved, 0) AS isRateApproved,
       COALESCE(c.hourly_rate, 0) AS hourlyRate,
       COALESCE(u.isActive, 1) AS userIsActive
     FROM careprovider c
     JOIN user u ON BINARY u.userId = BINARY c.userId
     WHERE BINARY c.userId = BINARY ?
     LIMIT 1`,
    [providerId],
  );

  if (!profile) {
    return {
      canWork: false,
      reason: 'Provider profile not found',
      providerStatus: 'inactive',
      rateAcceptanceStatus: 'missing',
      providerRate: 0,
      specialization: '',
    };
  }

  const [[rate]] = await db.query(
    `SELECT
       specialization,
       COALESCE(NULLIF(provider_rate, 0), provider_hour_rate, 0) AS providerRate,
       rateAcceptanceStatus,
       status,
       rateSetAt,
       rateAcceptedAt,
       rateRejectedAt
     FROM provider_rates
     WHERE BINARY providerId = BINARY ?
     ORDER BY
       CASE WHEN rateAcceptanceStatus = 'accepted' THEN 0 ELSE 1 END,
       rateSetAt DESC,
       id DESC
     LIMIT 1`,
    [providerId],
  );

  const providerRate = Number(rate?.providerRate || profile.hourlyRate || 0);
  const rateAccepted = (rate?.rateAcceptanceStatus || '').toLowerCase() === 'accepted';
  const careproviderApproved = dbBool(profile.isRateApproved);
  const adminApproved =
    (profile.approvalStatus || '').toLowerCase() === 'approved';
  const userActive = dbBool(profile.userIsActive);
  const activeStatus = (profile.providerStatus || '').toLowerCase() === 'active';
  const canWork =
    adminApproved &&
    userActive &&
    activeStatus &&
    providerRate > 0 &&
    (rateAccepted || careproviderApproved);

  let reason = '';
  if (!adminApproved) {
    reason = 'Admin approval is required before using doctor services.';
  } else if (providerRate <= 0) {
    reason = 'The administrator has not assigned your service rate yet.';
  } else if ((rate?.rateAcceptanceStatus || '').toLowerCase() === 'rejected') {
    reason = 'You rejected the assigned rate. Please wait for administrator review.';
  } else if (!rateAccepted) {
    reason = 'Please review and accept your admin-assigned service rate.';
  } else if (!userActive || !activeStatus) {
    reason = 'Your doctor account is inactive. Please contact the administrator.';
  }

  return {
    canWork,
    reason: canWork
      ? 'Doctor account and service rate are active.'
      : reason,
    providerStatus: profile.providerStatus || 'pending',
    approvalStatus: profile.approvalStatus || 'pending',
    rateAcceptanceStatus: rate?.rateAcceptanceStatus || 'pending',
    providerRate,
    specialization: rate?.specialization || profile.specialization || '',
    rateSetAt: rate?.rateSetAt || null,
    rateAcceptedAt: rate?.rateAcceptedAt || null,
    rateRejectedAt: rate?.rateRejectedAt || null,
    isActive: dbBool(profile.userIsActive),
  };
}

async function assertDoctorUser(doctorId) {
  const [[doctor]] = await db.query(
    `SELECT userId
     FROM user
     WHERE BINARY userId = BINARY ?
       AND BINARY LOWER(CAST(role AS CHAR)) = BINARY 'doctor'
     LIMIT 1`,
    [doctorId],
  );
  if (!doctor) {
    const err = new Error('Doctor not found');
    err.status = 404;
    throw err;
  }
  return doctor;
}

async function assertProviderCanWork(providerId) {
  const eligibility = await getProviderWorkEligibility(providerId);
  if (!eligibility.canWork) {
    const err = new Error(eligibility.reason);
    err.status = 403;
    err.eligibility = eligibility;
    throw err;
  }
  return eligibility;
}

function minutesFromScheduleTime(value) {
  const parts = String(value || '').trim().split(':');
  if (parts.length < 2) return null;
  const hour = Number(parts[0]);
  const minute = Number(parts[1]);
  if (!Number.isInteger(hour) || !Number.isInteger(minute)) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

function scheduleTimeFromMinutes(totalMinutes) {
  const hour = Math.floor(totalMinutes / 60);
  const minute = totalMinutes % 60;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00`;
}

function expandDoctorScheduleSlot({ day, startTime, endTime }) {
  const startMinutes = minutesFromScheduleTime(startTime);
  const endMinutes = minutesFromScheduleTime(endTime);

  if (startMinutes == null || endMinutes == null || endMinutes <= startMinutes) {
    const err = new Error('End time must be after start time');
    err.status = 400;
    throw err;
  }

  const slots = [];
  for (let current = startMinutes; current < endMinutes; current += 60) {
    const next = Math.min(current + 60, endMinutes);
    slots.push({
      day,
      startTime: scheduleTimeFromMinutes(current),
      endTime: scheduleTimeFromMinutes(next),
    });
  }
  return slots;
}

async function ensureMedicalAccessLogTable() {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS medicalrecordaccesslog (
      accessLogId CHAR(36) NOT NULL PRIMARY KEY,
      patientUserId CHAR(36) NOT NULL,
      doctorUserId CHAR(36) NOT NULL,
      requestId CHAR(36) NULL,
      accessType VARCHAR(64) NOT NULL DEFAULT 'view',
      createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      KEY idx_mral_patient (patientUserId),
      KEY idx_mral_doctor (doctorUserId),
      KEY idx_mral_created (createdAt)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
}

async function initialDiagnosisExistsForCase(patientId, doctorId) {
  const [rows] = await db.query(
    `SELECT EXISTS (
       SELECT 1
       FROM initial_diagnosis_report idr
       JOIN servicerequest sr
         ON BINARY sr.requestId = BINARY idr.serviceRequestId
       WHERE BINARY sr.patientUserId = BINARY ?
         AND BINARY idr.doctorUserId = BINARY ?
       LIMIT 1
     ) AS hasInitialDiagnosisReport`,
    [patientId, doctorId]
  );

  const exists = dbBool(rows[0]?.hasInitialDiagnosisReport);
  console.log('[doctor:reports:initial-check]', {
    patientId,
    doctorId,
    rawValue: rows[0]?.hasInitialDiagnosisReport,
    exists,
  });
  return exists;
}

async function initialDiagnosisSelectSql() {
  return `EXISTS (
    SELECT 1
    FROM initial_diagnosis_report idr
    WHERE BINARY idr.serviceRequestId = BINARY sr.requestId
      AND BINARY idr.doctorUserId = BINARY sr.providerUserId
    LIMIT 1
  )`;
}

async function reportExistsForRequest(requestId) {
  const checks = [];

  if (await hasTable('initial_diagnosis_report')) {
    checks.push(
      db
        .query(
          `SELECT 1
           FROM initial_diagnosis_report
           WHERE BINARY serviceRequestId = BINARY ?
           LIMIT 1`,
          [requestId]
        )
        .then(([rows]) => rows.length > 0)
    );
  }

  if ((await hasTable('visit')) && (await hasTable('visitreport'))) {
    checks.push(
      db
        .query(
          `SELECT 1
           FROM visit v
           JOIN visitreport r ON BINARY r.visitId = BINARY v.visitId
           WHERE BINARY v.requestId = BINARY ?
           LIMIT 1`,
          [requestId]
        )
        .then(([rows]) => rows.length > 0)
    );
  }

  if (
    (await hasTable('visit_reports')) &&
    (await hasColumn('visit_reports', 'appointment_id'))
  ) {
    const hasReportKind = await hasColumn('visit_reports', 'report_kind');
    checks.push(
      db
        .query(
          `SELECT 1
           FROM visit_reports
           WHERE BINARY appointment_id = BINARY ?
             ${hasReportKind ? "AND COALESCE(report_kind, 'visit_report') = 'visit_report'" : ''}
           LIMIT 1`,
          [requestId]
        )
        .then(([rows]) => rows.length > 0)
    );
  }

  if (checks.length === 0) return false;
  const results = await Promise.all(checks);
  return results.some(Boolean);
}

async function ensureDoctorRoleRow(userId) {
  await db.execute(
    `INSERT IGNORE INTO doctor (userId)
     SELECT userId
     FROM user
     WHERE BINARY userId = BINARY ?
       AND role = 'doctor'`,
    [userId]
  );
}

async function ensureDoctorNotificationPreferenceTable() {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS doctornotificationpreference (
      doctorUserId CHAR(36) NOT NULL PRIMARY KEY,
      medicalCases TINYINT(1) NOT NULL DEFAULT 1,
      patientUpdates TINYINT(1) NOT NULL DEFAULT 1,
      newAppointments TINYINT(1) NOT NULL DEFAULT 1,
      assignmentUpdates TINYINT(1) NOT NULL DEFAULT 1,
      cancellations TINYINT(1) NOT NULL DEFAULT 1,
      updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
}

async function getDoctorNotificationPrefs(doctorId) {
  await ensureDoctorNotificationPreferenceTable();
  await db.execute(
    `INSERT IGNORE INTO doctornotificationpreference (doctorUserId)
     VALUES (?)`,
    [doctorId]
  );
  const [rows] = await db.query(
    `SELECT doctorUserId, medicalCases, patientUpdates, newAppointments,
            assignmentUpdates, cancellations
     FROM doctornotificationpreference
     WHERE doctorUserId = ?`,
    [doctorId]
  );
  const row = rows[0] || {};
  return {
    doctorUserId: doctorId,
    medicalCases: row.medicalCases !== 0,
    patientUpdates: row.patientUpdates !== 0,
    newAppointments: row.newAppointments !== 0,
    assignmentUpdates: row.assignmentUpdates !== 0,
    cancellations: row.cancellations !== 0,
  };
}

async function insertDoctorNotificationIfEnabled({
  doctorId,
  preferenceKey,
  type,
  title,
  body,
  relatedRequestId,
}) {
  const prefs = await getDoctorNotificationPrefs(doctorId);
  if (prefs[preferenceKey] === false) return null;
  return insertNotification({
    userId: doctorId,
    type,
    title,
    body,
    relatedRequestId,
  });
}

function toNumberOrNull(value) {
  if (value == null || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function escapeLike(value) {
  return value.replace(/[\\%_]/g, (ch) => `\\${ch}`);
}

// Middleware to verify doctor authentication
async function verifyDoctor(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized', message: 'No token provided' });
  }

  const token = authHeader.split(' ')[1];
  if (!token) {
    return res.status(401).json({ error: 'Unauthorized', message: 'Invalid token' });
  }

  try {
    const [rows] = await db.query(
      'SELECT userId, fullName, email, phone, role FROM user WHERE userId = ? AND role = ?',
      [token, 'doctor']
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: 'Unauthorized', message: 'Invalid token or not a doctor' });
    }

    req.doctor = rows[0];
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Unauthorized', message: 'Authentication failed' });
  }
}

// ============================================
// DOCTOR LOGIN
// ============================================
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    const [rows] = await db.query(
      'SELECT userId, fullName, email, phone, role, passwordHash FROM user WHERE email = ? AND role = ?',
      [email.trim().toLowerCase(), 'doctor']
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = rows[0];
    const isValidPassword = await bcrypt.compare(password, user.passwordHash);

    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Check if doctor is approved (exists in doctor table)
    const [doctorRows] = await db.query(
      'SELECT * FROM doctor WHERE userId = ?',
      [user.userId]
    );

    if (doctorRows.length === 0) {
      return res.status(403).json({
        error: 'pending_approval',
        message: 'Your account is pending approval',
        userId: user.userId,
        fullName: user.fullName,
        email: user.email,
        role: user.role,
        status: 'pending'
      });
    }

    // Get doctor profile from careprovider
    const [providerRows] = await db.query(
      'SELECT * FROM careprovider WHERE userId = ?',
      [user.userId]
    );

    res.json({
      success: true,
      token: user.userId, // Using userId as token for simplicity
      user: {
        userId: user.userId,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        role: user.role,
        status: 'approved'
      },
      profile: providerRows.length > 0 ? providerRows[0] : null
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// CHECK APPROVAL STATUS
// ============================================
router.get('/approval-status/:userId', async (req, res) => {
  const { userId } = req.params;

  try {
    const [userRows] = await db.query(
      'SELECT userId, fullName, email, role FROM user WHERE userId = ? AND role = ?',
      [userId, 'doctor']
    );

    if (userRows.length === 0) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    const [doctorRows] = await db.query(
      'SELECT * FROM doctor WHERE userId = ?',
      [userId]
    );

    const isApproved = doctorRows.length > 0;

    res.json({
      userId: userId,
      fullName: userRows[0].fullName,
      email: userRows[0].email,
      status: isApproved ? 'approved' : 'pending',
      message: isApproved ? 'Your account is approved' : 'Your account is pending approval'
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// DOCTOR SERVICE RATE APPROVAL
// ============================================
router.get('/rate-status/:doctorId', async (req, res) => {
  const doctorId = (req.params.doctorId || '').toString().trim();
  try {
    await assertDoctorUser(doctorId);
    res.json(await getProviderWorkEligibility(doctorId));
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

router.post('/rate-status/:doctorId/decision', async (req, res) => {
  const doctorId = (req.params.doctorId || '').toString().trim();
  const decision = (req.body?.decision || '').toString().trim().toLowerCase();
  if (!['accepted', 'rejected'].includes(decision)) {
    return res.status(400).json({
      error: 'decision must be accepted or rejected',
    });
  }

  try {
    await assertDoctorUser(doctorId);
    await ensureDoctorRateGateTables();

    const [[provider]] = await db.query(
      `SELECT COALESCE(specialization, 'General Medicine') AS specialization
       FROM careprovider
       WHERE BINARY userId = BINARY ?
       LIMIT 1`,
      [doctorId],
    );
    const [rates] = await db.query(
      `SELECT id, specialization,
              COALESCE(NULLIF(provider_rate, 0), provider_hour_rate, 0) AS providerRate
       FROM provider_rates
       WHERE BINARY providerId = BINARY ?
       ORDER BY rateSetAt DESC, id DESC
       LIMIT 1`,
      [doctorId],
    );
    if (!rates.length || Number(rates[0].providerRate || 0) <= 0) {
      return res.status(404).json({
        error: 'The administrator has not assigned your service rate yet',
      });
    }

    const rate = rates[0];
    await db.query(
      `UPDATE provider_rates
       SET rateAcceptanceStatus = ?,
           rateAcceptedAt = CASE WHEN ? = 'accepted' THEN NOW() ELSE NULL END,
           rateRejectedAt = CASE WHEN ? = 'rejected' THEN NOW() ELSE NULL END
       WHERE id = ?`,
      [decision, decision, decision, rate.id],
    );

    const accepted = decision === 'accepted';
    const specialization =
      rate.specialization || provider?.specialization || 'General Medicine';
    const providerRate = Number(rate.providerRate || 0);

    if (await hasTable('provider_rate_approval')) {
      await db.query(
        `INSERT INTO provider_rate_approval
           (provider_id, specialization, admin_rate, status)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           admin_rate = VALUES(admin_rate),
           status = VALUES(status),
           updated_at = NOW()`,
        [
          doctorId,
          specialization,
          providerRate,
          accepted ? 'approved' : 'rejected',
        ],
      );
    }
    if (await hasTable('rate_approvals')) {
      await db.query(
        `INSERT INTO rate_approvals (provider_id, admin_rate, status)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE
           admin_rate = VALUES(admin_rate),
           status = VALUES(status),
           updated_at = NOW()`,
        [doctorId, providerRate, accepted ? 'approved' : 'rejected'],
      );
    }

    await db.query(
      `UPDATE careprovider
       SET is_rate_approved = ?,
           hourly_rate = ?,
           status = ?
       WHERE BINARY userId = BINARY ?`,
      [accepted ? 1 : 0, providerRate, accepted ? 'active' : 'inactive', doctorId],
    );
    await db.query(
      `UPDATE user SET isActive = ? WHERE BINARY userId = BINARY ?`,
      [accepted ? 1 : 0, doctorId],
    );

    res.json({
      success: true,
      ...(await getProviderWorkEligibility(doctorId)),
    });
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

// ============================================
// GET DOCTOR PROFILE
// ============================================
router.get('/profile/:userId', async (req, res) => {
  const { userId } = req.params;

  try {
    const [userRows] = await db.query(
      'SELECT userId, fullName, email, phone FROM user WHERE userId = ?',
      [userId]
    );

    if (userRows.length === 0) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    const [providerRows] = await db.query(
      'SELECT * FROM careprovider WHERE userId = ?',
      [userId]
    );

    res.json({
      user: userRows[0],
      profile: providerRows.length > 0 ? providerRows[0] : null
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// UPDATE DOCTOR PROFILE
// ============================================
router.put('/profile/:userId', async (req, res) => {
  const { userId } = req.params;
  const { fullName, phone, specialization, shortBio, experienceYears, consultationFee } = req.body;

  try {
    // Update user table
    if (fullName || phone) {
      const updates = [];
      const values = [];

      if (fullName) {
        updates.push('fullName = ?');
        values.push(fullName);
      }
      if (phone) {
        updates.push('phone = ?');
        values.push(phone);
      }

      if (updates.length > 0) {
        values.push(userId);
        await db.query(
          `UPDATE user SET ${updates.join(', ')} WHERE userId = ?`,
          values
        );
      }
    }

    // Update careprovider table
    const providerUpdates = [];
    const providerValues = [];

    if (specialization) {
      providerUpdates.push('specialization = ?');
      providerValues.push(specialization);
    }
    if (shortBio !== undefined) {
      providerUpdates.push('shortBio = ?');
      providerValues.push(shortBio);
    }
    if (experienceYears !== undefined) {
      providerUpdates.push('experienceYears = ?');
      providerValues.push(experienceYears);
    }
    if (consultationFee) {
      providerUpdates.push('consultationFee = ?');
      providerValues.push(consultationFee);
    }

    if (providerUpdates.length > 0) {
      providerValues.push(userId);
      await db.query(
        `UPDATE careprovider SET ${providerUpdates.join(', ')} WHERE userId = ?`,
        providerValues
      );
    }

    res.json({ success: true, message: 'Profile updated successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// GET PENDING REQUESTS FOR DOCTOR
// ============================================
router.get('/requests/pending', async (req, res) => {
  const { doctorId } = req.query;

  if (!doctorId) {
    return res.status(400).json({ error: 'Doctor ID is required' });
  }

  try {
    const [rows] = await db.query(
      `
      SELECT 
        sr.requestId,
        sr.serviceType,
        sr.status,
        sr.location,
        sr.notes,
        sr.reasonForVisit,
        sr.scheduledAt,
        sr.cancelledAt,
        sr.confirmedAt,
        sr.completedAt,
        sr.patientUserId,
        sr.providerUserId,
        u.fullName as patientName,
        u.phone as patientPhone,
        u.email as patientEmail
      FROM servicerequest sr
      JOIN user u ON sr.patientUserId = u.userId
      WHERE sr.providerUserId = ?
        AND LOWER(TRIM(CAST(sr.status AS CHAR(64)))) IN ('pending', 'pending_provider_approval')
      ORDER BY sr.scheduledAt ASC
      `,
      [doctorId]
    );

    console.log('[doctor:requests:pending]', {
      doctorId,
      count: rows.length,
      rows: rows.map((row) => ({
        requestId: row.requestId,
        status: row.status,
        providerUserId: row.providerUserId,
        patientUserId: row.patientUserId,
      })),
    });

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// GET AVAILABLE REQUESTS MATCHED TO DOCTOR
// ============================================
router.get('/requests/available', async (req, res) => {
  const { doctorId, maxDistanceKm } = req.query;

  if (!doctorId) {
    return res.status(400).json({ error: 'Doctor ID is required' });
  }

  try {
    const hasVisitLatitude = await hasColumn('servicerequest', 'visitLatitude');
    const hasVisitLongitude = await hasColumn('servicerequest', 'visitLongitude');
    const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');
    const hasSymptoms = await hasColumn('servicerequest', 'symptoms');
    const hasAdditionalNotes = await hasColumn('servicerequest', 'additionalNotes');
    const hasProviderLat = await hasColumn('careprovider', 'gpsLat');
    const hasProviderLng = await hasColumn('careprovider', 'gpsLng');
    const hasServiceType = await hasColumn('careprovider', 'serviceType');

    const [doctorRows] = await db.query(
      `SELECT specialization,
              ${hasServiceType ? 'serviceType' : "'' AS serviceType"},
              isAvailable,
              ${hasProviderLat ? 'gpsLat' : 'NULL AS gpsLat'},
              ${hasProviderLng ? 'gpsLng' : 'NULL AS gpsLng'}
       FROM careprovider
       WHERE userId = ?`,
      [doctorId]
    );

    if (doctorRows.length === 0) {
      return res.status(404).json({ error: 'Doctor profile not found' });
    }

    const doctor = doctorRows[0];
    if (doctor.isAvailable === 0) {
      return res.json([]);
    }

    const specialties = [
      doctor.specialization,
      doctor.serviceType,
    ]
      .flatMap((value) => (value || '').toString().split(/[,\|/]+/))
      .map((value) => value.trim())
      .filter(Boolean);

    const doctorLat = toNumberOrNull(doctor.gpsLat);
    const doctorLng = toNumberOrNull(doctor.gpsLng);
    const distanceCap = Number(maxDistanceKm || 25);
    const canFilterDistance =
      hasVisitLatitude &&
      hasVisitLongitude &&
      doctorLat != null &&
      doctorLng != null &&
      Number.isFinite(distanceCap) &&
      distanceCap > 0;

    const serviceWhere = specialties.length
      ? `AND (${specialties
          .map(() => 'LOWER(sr.serviceType) LIKE ?')
          .join(' OR ')})`
      : '';
    const serviceParams = specialties.map(
      (spec) => `%${escapeLike(spec.toLowerCase())}%`
    );

    const distanceSelect = canFilterDistance
      ? `, (6371 * ACOS(
            LEAST(1, GREATEST(-1,
              COS(RADIANS(?)) * COS(RADIANS(sr.visitLatitude)) *
              COS(RADIANS(sr.visitLongitude) - RADIANS(?)) +
              SIN(RADIANS(?)) * SIN(RADIANS(sr.visitLatitude))
            ))
          )) AS distanceKm`
      : ', NULL AS distanceKm';
    const distanceParams = canFilterDistance
      ? [doctorLat, doctorLng, doctorLat]
      : [];
    const distanceWhere = canFilterDistance
      ? `AND sr.visitLatitude IS NOT NULL
         AND sr.visitLongitude IS NOT NULL
         AND (6371 * ACOS(
            LEAST(1, GREATEST(-1,
              COS(RADIANS(?)) * COS(RADIANS(sr.visitLatitude)) *
              COS(RADIANS(sr.visitLongitude) - RADIANS(?)) +
              SIN(RADIANS(?)) * SIN(RADIANS(sr.visitLatitude))
            ))
          )) <= ?`
      : '';
    const distanceWhereParams = canFilterDistance
      ? [doctorLat, doctorLng, doctorLat, distanceCap]
      : [];

    const [rows] = await db.query(
      `
      SELECT
        sr.requestId,
        sr.serviceType,
        sr.status,
        sr.location,
        sr.notes,
        sr.reasonForVisit,
        sr.scheduledAt,
        sr.patientUserId,
        sr.providerUserId,
        ${hasVisitLatitude ? 'sr.visitLatitude' : 'NULL AS visitLatitude'},
        ${hasVisitLongitude ? 'sr.visitLongitude' : 'NULL AS visitLongitude'},
        ${hasVisitAddress ? 'sr.visitAddress' : "'' AS visitAddress"},
        ${hasSymptoms ? 'sr.symptoms' : "'' AS symptoms"},
        ${hasAdditionalNotes ? 'sr.additionalNotes' : "'' AS additionalNotes"},
        u.fullName as patientName,
        u.phone as patientPhone,
        u.email as patientEmail
        ${distanceSelect}
      FROM servicerequest sr
      JOIN user u ON sr.patientUserId = u.userId
      WHERE LOWER(TRIM(CAST(sr.status AS CHAR(64)))) IN ('pending', 'pending_provider_approval')
        AND (sr.providerUserId IS NULL OR sr.providerUserId = '' OR sr.providerUserId = ?)
        ${serviceWhere}
        ${distanceWhere}
      ORDER BY distanceKm IS NULL ASC, distanceKm ASC, sr.scheduledAt ASC
      LIMIT 100
      `,
      [
        ...distanceParams,
        doctorId,
        ...serviceParams,
        ...distanceWhereParams,
      ]
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// GET ALL REQUESTS FOR DOCTOR
// ============================================
router.get('/requests', async (req, res) => {
  const { doctorId, status } = req.query;

  if (!doctorId) {
    return res.status(400).json({ error: 'Doctor ID is required' });
  }

  try {
    const initialDiagnosisSelect = await initialDiagnosisSelectSql();
    const hasVisitLatitude = await hasColumn('servicerequest', 'visitLatitude');
    const hasVisitLongitude = await hasColumn('servicerequest', 'visitLongitude');
    const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');

    let query = `
      SELECT 
        sr.requestId,
        sr.serviceType,
        sr.status,
        sr.location,
        sr.notes,
        sr.reasonForVisit,
        sr.scheduledAt,
        sr.cancelledAt,
        sr.confirmedAt,
        sr.completedAt,
        sr.patientUserId,
        sr.providerUserId,
        ${hasVisitLatitude ? 'sr.visitLatitude' : 'NULL AS visitLatitude'},
        ${hasVisitLongitude ? 'sr.visitLongitude' : 'NULL AS visitLongitude'},
        ${hasVisitAddress ? 'sr.visitAddress' : "'' AS visitAddress"},
        u.fullName as patientName,
        u.phone as patientPhone,
        u.email as patientEmail,
        ${initialDiagnosisSelect} as hasInitialDiagnosisReport
      FROM servicerequest sr
      JOIN user u ON sr.patientUserId = u.userId
      WHERE sr.providerUserId = ?
        AND LOWER(TRIM(CAST(sr.status AS CHAR(64)))) <> 'draft'
    `;
    const params = [doctorId];

    if (status) {
      const normalizedStatus = status.toString().trim().toLowerCase();
      if (normalizedStatus === 'pending') {
        query += ` AND LOWER(TRIM(CAST(sr.status AS CHAR(64)))) IN ('pending', 'pending_provider_approval')`;
      } else {
        query += ' AND LOWER(TRIM(CAST(sr.status AS CHAR(64)))) = ?';
        params.push(normalizedStatus);
      }
    }

    query += ' ORDER BY sr.scheduledAt DESC';

    const [rows] = await db.query(query, params);
    const normalizedRows = await Promise.all(
      rows.map(async (row) => {
        const hasReportForVisit = await reportExistsForRequest(row.requestId);
        const hasInitialDiagnosisReportForCase =
          await initialDiagnosisExistsForCase(
            row.patientUserId,
            row.providerUserId
          );
        const statusText = (row.status || '').toString().trim().toLowerCase();
        return {
          ...row,
          hasInitialDiagnosisReport: dbBool(row.hasInitialDiagnosisReport),
          hasInitialDiagnosisReportForCase,
          hasReportForVisit,
          canCreateReport: statusText === 'completed' && !hasReportForVisit,
        };
      })
    );

    console.log('[doctor:requests:list]', {
      doctorId,
      status: status || 'all',
      count: normalizedRows.length,
      rows: normalizedRows.map((row) => ({
        requestId: row.requestId,
        status: row.status,
        providerUserId: row.providerUserId,
        patientUserId: row.patientUserId,
        hasInitialDiagnosisReport: row.hasInitialDiagnosisReport,
        hasInitialDiagnosisReportForCase:
          row.hasInitialDiagnosisReportForCase,
        hasReportForVisit: row.hasReportForVisit,
        canCreateReport: row.canCreateReport,
      })),
    });

    res.json(normalizedRows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// GET REQUEST DETAILS
// ============================================
router.get('/requests/:requestId', async (req, res) => {
  const { requestId } = req.params;

  try {
    const initialDiagnosisSelect = await initialDiagnosisSelectSql();
    const hasVisitLatitude = await hasColumn('servicerequest', 'visitLatitude');
    const hasVisitLongitude = await hasColumn('servicerequest', 'visitLongitude');
    const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');

    const [rows] = await db.query(
      `
      SELECT 
        sr.requestId,
        sr.serviceType,
        sr.status,
        sr.location,
        sr.notes,
        sr.reasonForVisit,
        sr.scheduledAt,
        sr.cancelledAt,
        sr.confirmedAt,
        sr.completedAt,
        sr.patientUserId,
        sr.providerUserId,
        ${hasVisitLatitude ? 'sr.visitLatitude' : 'NULL AS visitLatitude'},
        ${hasVisitLongitude ? 'sr.visitLongitude' : 'NULL AS visitLongitude'},
        ${hasVisitAddress ? 'sr.visitAddress' : "'' AS visitAddress"},
        u.fullName as patientName,
        u.phone as patientPhone,
        u.email as patientEmail,
        ${initialDiagnosisSelect} as hasInitialDiagnosisReport
      FROM servicerequest sr
      JOIN user u ON sr.patientUserId = u.userId
      WHERE sr.requestId = ?
      `,
      [requestId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }

    const hasReportForVisit = await reportExistsForRequest(rows[0].requestId);
    const hasInitialDiagnosisReportForCase =
      await initialDiagnosisExistsForCase(
        rows[0].patientUserId,
        rows[0].providerUserId
      );
    const statusText = (rows[0].status || '').toString().trim().toLowerCase();

    const normalizedRow = {
      ...rows[0],
      hasInitialDiagnosisReport: dbBool(rows[0].hasInitialDiagnosisReport),
      hasInitialDiagnosisReportForCase,
      hasReportForVisit,
      canCreateReport: statusText === 'completed' && !hasReportForVisit,
    };

    console.log('[doctor:requests:detail]', {
      requestId,
      status: normalizedRow.status,
      providerUserId: normalizedRow.providerUserId,
      patientUserId: normalizedRow.patientUserId,
      hasInitialDiagnosisReport: normalizedRow.hasInitialDiagnosisReport,
      hasInitialDiagnosisReportForCase:
        normalizedRow.hasInitialDiagnosisReportForCase,
      hasReportForVisit: normalizedRow.hasReportForVisit,
      canCreateReport: normalizedRow.canCreateReport,
    });

    res.json(normalizedRow);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// GET INITIAL DIAGNOSIS REPORT
// ============================================
router.get('/initial-diagnosis/:serviceRequestId', async (req, res) => {
  const { serviceRequestId } = req.params;
  const doctorUserId = (req.query.doctorUserId || req.query.doctorId || '')
    .toString()
    .trim();

  try {
    const report = await initialDiagnosisReportService.findByServiceRequestId(
      serviceRequestId,
      doctorUserId || undefined
    );

    if (!report) {
      return res.json({
        hasInitialDiagnosisReport: false,
        report: null,
      });
    }

    res.json({
      hasInitialDiagnosisReport: true,
      report: report.toJSON(),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// CREATE INITIAL DIAGNOSIS REPORT
// ============================================
router.post('/initial-diagnosis', async (req, res) => {
  const {
    serviceRequestId,
    doctorUserId,
    chiefComplaint,
    symptoms,
    diagnosis,
    treatmentPlan,
    nursingInstructions,
    requiredVisits,
  } = req.body;

  if (!serviceRequestId || !doctorUserId) {
    return res.status(400).json({
      error: 'serviceRequestId and doctorUserId are required',
    });
  }

  try {
    const [requestRows] = await db.query(
      `SELECT requestId, patientUserId, providerUserId, status
       FROM servicerequest
       WHERE BINARY requestId = BINARY ?
       LIMIT 1`,
      [serviceRequestId]
    );

    if (requestRows.length === 0) {
      return res.status(404).json({ error: 'Service request not found' });
    }

    const request = requestRows[0];
    if (request.providerUserId !== doctorUserId) {
      return res.status(403).json({
        error: 'Doctor is not assigned to this service request',
      });
    }

    if ((request.status || '').toString().toLowerCase() !== 'completed') {
      return res.status(400).json({
        error: 'Initial diagnosis can only be saved for completed visits',
      });
    }

    if (await reportExistsForRequest(serviceRequestId)) {
      return res.status(409).json({
        error: 'A report already exists for this completed visit',
        hasReportForVisit: true,
      });
    }

    await ensureDoctorRoleRow(doctorUserId);

    if (await initialDiagnosisExistsForCase(request.patientUserId, doctorUserId)) {
      return res.status(409).json({
        error: 'Initial diagnosis report already exists for this patient case',
        hasInitialDiagnosisReportForCase: true,
      });
    }

    const existing = await initialDiagnosisReportService.findByServiceRequestId(
      serviceRequestId,
      doctorUserId
    );

    if (existing) {
      return res.status(409).json({
        error: 'Initial diagnosis report already exists for this visit',
        report: existing.toJSON(),
      });
    }

    const report = await initialDiagnosisReportService.create({
      serviceRequestId,
      doctorUserId,
      chiefComplaint,
      symptoms,
      diagnosis,
      treatmentPlan,
      nursingInstructions,
      requiredVisits,
    });

    res.status(201).json({
      success: true,
      hasInitialDiagnosisReport: true,
      report: report.toJSON(),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// ACCEPT REQUEST
// ============================================
router.post('/requests/:requestId/accept', async (req, res) => {
  const { requestId } = req.params;
  const { doctorId } = req.body;

  if (!doctorId) {
    return res.status(400).json({ error: 'Doctor ID is required' });
  }

  try {
    try {
      await assertProviderCanWork(doctorId);
    } catch (err) {
      return res.status(err.status || 403).json({
        error: err.message,
        eligibility: err.eligibility || null,
      });
    }
    // Check if request exists and is available to this doctor
    const [requestRows] = await db.query(
      `SELECT * FROM servicerequest
       WHERE requestId = ?
         AND (providerUserId = ? OR providerUserId IS NULL OR providerUserId = '')`,
      [requestId, doctorId]
    );

    if (requestRows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }

    const request = requestRows[0];
    const currentStatus = (request.status || '').toString().trim().toLowerCase();
    if (currentStatus === 'confirmed') {
      if (request.providerUserId === doctorId) {
        return res.json({ success: true, message: 'Request already accepted by this doctor' });
      }
      return res.status(400).json({ error: `Cannot accept request with status: ${request.status}` });
    }
    if (!['pending', 'pending_provider_approval'].includes(currentStatus)) {
      return res.status(400).json({ error: `Cannot accept request with status: ${request.status}` });
    }

    await db.query(
      `UPDATE servicerequest 
       SET status = 'confirmed', providerUserId = ?, confirmedAt = NOW()
       WHERE requestId = ?`,
      [doctorId, requestId]
    );

    await db.query(
      `INSERT INTO appointmentstatushistory (statusHistoryId, requestId, patientUserId, providerUserId, statusCode, sourceRole, note)
       VALUES (?, ?, ?, ?, 'confirmed', 'doctor', 'Request accepted')`,
      [randomUUID(), requestId, request.patientUserId, doctorId]
    );

    try {
      await insertDoctorNotificationIfEnabled({
        doctorId,
        preferenceKey: 'assignmentUpdates',
        type: 'appointment',
        title: 'Request assigned',
        body: 'You accepted a patient request.',
        relatedRequestId: requestId,
      });
      await insertNotification({
        userId: request.patientUserId,
        type: 'appointment',
        title: 'Appointment confirmed',
        body: 'Your doctor accepted the request. Your appointment is confirmed.',
        relatedRequestId: requestId,
      });
    } catch (_) {}

    res.json({
      success: true,
      status: 'confirmed',
      message: 'Request accepted and appointment confirmed',
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// COMPLETE REQUEST
// ============================================
router.post('/requests/:requestId/complete', async (req, res) => {
  const { requestId } = req.params;
  const { doctorId } = req.body;

  if (!doctorId) {
    return res.status(400).json({ error: 'Doctor ID is required' });
  }

  try {
    try {
      await assertProviderCanWork(doctorId);
    } catch (err) {
      return res.status(err.status || 403).json({
        error: err.message,
        eligibility: err.eligibility || null,
      });
    }
    const [requestRows] = await db.query(
      'SELECT * FROM servicerequest WHERE requestId = ? AND providerUserId = ?',
      [requestId, doctorId]
    );

    if (requestRows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }

    const request = requestRows[0];
    if (request.status !== 'confirmed') {
      return res.status(400).json({
        error: `Can only complete confirmed requests, current status: ${request.status}`,
      });
    }

    await db.query(
      `UPDATE servicerequest
       SET status = 'completed', completedAt = NOW()
       WHERE requestId = ? AND providerUserId = ?`,
      [requestId, doctorId]
    );

    await db.query(
      `INSERT INTO appointmentstatushistory (statusHistoryId, requestId, patientUserId, providerUserId, statusCode, sourceRole, note)
       VALUES (?, ?, ?, ?, 'completed', 'doctor', 'Visit marked completed')`,
      [randomUUID(), requestId, request.patientUserId, doctorId]
    );

    try {
      await insertNotification({
        userId: request.patientUserId,
        type: 'appointment',
        title: 'Visit completed',
        body: 'Your visit was marked completed. The doctor can now submit the medical report.',
        relatedRequestId: requestId,
      });
    } catch (_) {}

    res.json({ success: true, message: 'Visit marked completed' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// REJECT REQUEST
// ============================================
router.post('/requests/:requestId/reject', async (req, res) => {
  const { requestId } = req.params;
  const { doctorId, reason } = req.body;

  if (!doctorId) {
    return res.status(400).json({ error: 'Doctor ID is required' });
  }

  try {
    try {
      await assertProviderCanWork(doctorId);
    } catch (err) {
      return res.status(err.status || 403).json({
        error: err.message,
        eligibility: err.eligibility || null,
      });
    }
    // Check if request exists and is available to this doctor or unassigned
    const [requestRows] = await db.query(
      `SELECT * FROM servicerequest
       WHERE requestId = ?
         AND (providerUserId = ? OR providerUserId IS NULL OR providerUserId = '')`,
      [requestId, doctorId]
    );

    if (requestRows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }

    const request = requestRows[0];
    const currentStatus = (request.status || '').toString().trim().toLowerCase();
    if (!['pending', 'pending_provider_approval'].includes(currentStatus)) {
      return res.status(400).json({ error: `Cannot reject request with status: ${request.status}` });
    }

    // Update request status
    await db.query(
      `UPDATE servicerequest 
       SET status = 'cancelled', cancelledAt = NOW() 
       WHERE requestId = ?`,
      [requestId]
    );

    // Add status history
    await db.query(
      `INSERT INTO appointmentstatushistory (statusHistoryId, requestId, patientUserId, providerUserId, statusCode, sourceRole, note)
       VALUES (?, ?, ?, ?, 'cancelled', 'doctor', ?)`,
      [randomUUID(), requestId, request.patientUserId, doctorId, reason || 'Request rejected by doctor']
    );

    try {
      await insertDoctorNotificationIfEnabled({
        doctorId,
        preferenceKey: 'cancellations',
        type: 'appointment',
        title: 'Request cancelled',
        body: 'You rejected a patient request.',
        relatedRequestId: requestId,
      });
      await insertNotification({
        userId: request.patientUserId,
        type: 'appointment',
        title: 'Appointment cancelled',
        body: reason || 'The doctor declined this request.',
        relatedRequestId: requestId,
      });
    } catch (_) {}

    res.json({ success: true, message: 'Request rejected successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// GET DOCTOR PATIENTS
// ============================================
router.get('/patients', async (req, res) => {
  const { doctorId } = req.query;

  if (!doctorId) {
    return res.status(400).json({ error: 'Doctor ID is required' });
  }

  try {
    const hasProfileImageUrl = await hasColumn('user', 'profileImageUrl');
    const hasPatientAddress = await hasColumn('patient', 'addressText');
    const hasPatientDob = await hasColumn('patient', 'dateOfBirth');
    const hasPatientGender = await hasColumn('patient', 'gender');
    const hasPatientLat = await hasColumn('patient', 'gpsLat');
    const hasPatientLng = await hasColumn('patient', 'gpsLng');
    const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');
    const visitLocationExpr = hasVisitAddress
      ? "COALESCE(NULLIF(sr2.visitAddress, ''), NULLIF(sr2.location, ''))"
      : "NULLIF(sr2.location, '')";

    const [rows] = await db.query(
      `
      SELECT *
      FROM (
        SELECT
          sr.patientUserId,
          u.fullName as patientName,
          u.phone as patientPhone,
          u.email as patientEmail,
          ${hasProfileImageUrl ? 'MAX(u.profileImageUrl)' : 'NULL'} as profileImageUrl,
          ${hasPatientAddress ? 'MAX(p.addressText)' : 'NULL'} as addressText,
          ${hasPatientAddress ? 'MAX(p.addressText)' : 'NULL'} as patientAddress,
          ${hasPatientDob ? 'MAX(p.dateOfBirth)' : 'NULL'} as dateOfBirth,
          ${hasPatientGender ? 'MAX(p.gender)' : 'NULL'} as gender,
          ${hasPatientLat ? 'MAX(p.gpsLat)' : 'NULL'} as gpsLat,
          ${hasPatientLng ? 'MAX(p.gpsLng)' : 'NULL'} as gpsLng,
          (
            SELECT ${visitLocationExpr}
            FROM servicerequest sr2
            WHERE sr2.patientUserId = sr.patientUserId
              AND sr2.providerUserId = ?
              AND LOWER(TRIM(CAST(sr2.status AS CHAR(64)))) <> 'draft'
              AND ${visitLocationExpr} IS NOT NULL
            ORDER BY sr2.scheduledAt DESC
            LIMIT 1
          ) as location,
          (
            SELECT ${visitLocationExpr}
            FROM servicerequest sr2
            WHERE sr2.patientUserId = sr.patientUserId
              AND sr2.providerUserId = ?
              AND LOWER(TRIM(CAST(sr2.status AS CHAR(64)))) <> 'draft'
              AND ${visitLocationExpr} IS NOT NULL
            ORDER BY sr2.scheduledAt DESC
            LIMIT 1
          ) as visitAddress,
          COUNT(*) as totalVisits,
          MAX(CASE WHEN LOWER(TRIM(CAST(sr.status AS CHAR(64)))) = 'completed' THEN sr.scheduledAt ELSE NULL END) as lastVisit,
          MIN(CASE WHEN LOWER(TRIM(CAST(sr.status AS CHAR(64)))) IN ('pending', 'pending_provider_approval', 'pending_payment', 'confirmed') AND sr.scheduledAt >= NOW() THEN sr.scheduledAt ELSE NULL END) as nextVisit
        FROM servicerequest sr
        JOIN user u ON sr.patientUserId = u.userId
        LEFT JOIN patient p ON sr.patientUserId = p.userId
        WHERE sr.providerUserId = ?
          AND LOWER(TRIM(CAST(sr.status AS CHAR(64)))) <> 'draft'
        GROUP BY sr.patientUserId, u.fullName, u.phone, u.email
      ) patients
      ORDER BY COALESCE(nextVisit, lastVisit) DESC
      `,
      [doctorId, doctorId, doctorId]
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// GET PATIENT MEDICAL RECORD
// ============================================
router.get('/patients/:patientId/medical-record', async (req, res) => {
  const { patientId } = req.params;
  const doctorId = (req.query.doctorId || '').toString().trim();

  if (!doctorId) {
    return res.status(400).json({ error: 'Doctor ID is required' });
  }

  try {
    const [accessRows] = await db.query(
      `SELECT requestId
       FROM servicerequest
       WHERE patientUserId = ?
         AND providerUserId = ?
         AND status IN ('confirmed', 'completed')
       ORDER BY COALESCE(completedAt, confirmedAt, scheduledAt) DESC
       LIMIT 1`,
      [patientId, doctorId]
    );

    if (accessRows.length === 0) {
      console.log('[doctor:medical-record] denied', {
        patientId,
        doctorId,
        initialDiagnosisReportsLength: 0,
        visitReportsLength: 0,
      });
      return res.status(403).json({
        error: 'Medical record access is allowed only after accepting this patient request',
      });
    }

    const [rows] = await db.query(
      'SELECT * FROM medicalrecord WHERE patientUserId = ?',
      [patientId]
    );

    if (rows.length === 0) {
      const initialDiagnosisReports =
        await initialDiagnosisReportService.listByPatientAndDoctor(
          patientId,
          doctorId
        );
      const visitReports = await getDoctorVisibleVisitReports(patientId, doctorId);
      console.log('[doctor:medical-record] response without medicalrecord', {
        patientId,
        doctorId,
        initialDiagnosisReportsLength: initialDiagnosisReports.length,
        visitReportsLength: visitReports.length,
      });
      return res.json(
        initialDiagnosisReports.length > 0 || visitReports.length > 0
          ? { initialDiagnosisReports, visitReports }
          : {}
      );
    }

    const record = rows[0];

    // Get allergies
    const [allergyRows] = await db.query(
      `SELECT a.*, mra.severity, mra.reaction, mra.notes as allergyNotes
       FROM medicalrecordallergy mra
       JOIN allergy a ON mra.allergyId = a.allergyId
       WHERE mra.recordId = ?`,
      [record.recordId]
    );

    // Get diseases
    const [diseaseRows] = await db.query(
      `SELECT d.*, mrd.diseaseStatus, mrd.notes as diseaseNotes
       FROM medicalrecorddisease mrd
       JOIN disease d ON mrd.diseaseId = d.diseaseId
       WHERE mrd.recordId = ?`,
      [record.recordId]
    );

    // Get lab results
    const [labRows] = await db.query(
      'SELECT * FROM medicallabresult WHERE recordId = ? ORDER BY resultDate DESC',
      [record.recordId]
    );

    // Get clinical notes
    const [noteRows] = await db.query(
      `SELECT cn.*, u.fullName as authorName
       FROM clinicalnote cn
       JOIN user u ON cn.authorUserId = u.userId
       WHERE cn.recordId = ?
       ORDER BY cn.createdAt DESC`,
      [record.recordId]
    );

    const initialDiagnosisReports =
      await initialDiagnosisReportService.listByPatientAndDoctor(
        patientId,
        doctorId
      );
    const visitReports = await getDoctorVisibleVisitReports(patientId, doctorId);
    console.log('[doctor:medical-record] response', {
      patientId,
      doctorId,
      initialDiagnosisReportsLength: initialDiagnosisReports.length,
      visitReportsLength: visitReports.length,
    });

    try {
      await ensureMedicalAccessLogTable();
      await db.execute(
        `INSERT INTO medicalrecordaccesslog
         (accessLogId, patientUserId, doctorUserId, requestId, accessType, createdAt)
         VALUES (?, ?, ?, ?, 'view', NOW())`,
        [randomUUID(), patientId, doctorId, accessRows[0].requestId]
      );
    } catch (_) {}

    res.json({
      ...record,
      allergies: allergyRows,
      diseases: diseaseRows,
      labResults: labRows,
      clinicalNotes: noteRows,
      initialDiagnosisReports,
      visitReports
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

async function getDoctorVisibleVisitReports(patientId, doctorId) {
  let visitReports = [];

  try {
    if (await medicalRecordService.tableExists('visit_reports')) {
      visitReports = await medicalRecordService.listVisitReportsForPatient(patientId);
      visitReports = visitReports.filter(
        (report) => (report.provider_id || '').toString() === doctorId
      );
    }
  } catch (_) {}

  if (visitReports.length > 0 || !(await hasTable('visitreport'))) {
    return visitReports;
  }

  const [legacyRows] = await db.query(
    `SELECT
       r.reportId AS id,
       sr.patientUserId AS patient_id,
       sr.providerUserId AS provider_id,
       sr.requestId AS appointment_id,
       'visit_report' AS record_type,
       COALESCE(NULLIF(TRIM(r.diagnosis), ''), 'Visit report') AS title,
       r.diagnosis,
       r.notes,
       NULL AS medications,
       NULL AS treatment_plan,
       NULL AS recommendations,
       COALESCE(sr.completedAt, sr.scheduledAt) AS visit_date,
       COALESCE(sr.completedAt, sr.scheduledAt) AS created_at,
       u.fullName AS providerName
     FROM visitreport r
     JOIN visit v ON BINARY v.visitId = BINARY r.visitId
     JOIN servicerequest sr ON BINARY sr.requestId = BINARY v.requestId
     LEFT JOIN user u ON BINARY u.userId = BINARY sr.providerUserId
     WHERE BINARY sr.patientUserId = BINARY ?
       AND BINARY sr.providerUserId = BINARY ?
     ORDER BY COALESCE(sr.completedAt, sr.scheduledAt) DESC`,
    [patientId, doctorId]
  );

  return legacyRows;
}

// ============================================
// SUBMIT MEDICAL REPORT
// ============================================
router.post('/requests/:requestId/report', async (req, res) => {
  const { requestId } = req.params;
  const {
    doctorId,
    diagnosis,
    notes,
    prescription,
    isInitialDiagnosis,
    chiefComplaint,
    symptoms,
    medicalHistory,
    treatmentPlan,
    requiredVisits,
  } = req.body;

  if (!doctorId) {
    return res.status(400).json({ error: 'Doctor ID is required' });
  }

  try {
    // Check if request exists and completed before report submission
    const [requestRows] = await db.query(
      'SELECT * FROM servicerequest WHERE requestId = ? AND providerUserId = ?',
      [requestId, doctorId]
    );

    if (requestRows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }

    const request = requestRows[0];
    if (request.status !== 'completed') {
      return res.status(400).json({ error: 'Can only submit report for completed visits' });
    }

    const submitInitialDiagnosis =
      isInitialDiagnosis === true ||
      isInitialDiagnosis === 'true' ||
      isInitialDiagnosis === 1 ||
      isInitialDiagnosis === '1';

    console.log('[doctor:reports:submit:start]', {
      requestId,
      doctorId,
      patientId: request.patientUserId,
      requestProviderId: request.providerUserId,
      status: request.status,
      submitInitialDiagnosis,
      bodyIsInitialDiagnosis: isInitialDiagnosis,
    });

    if (submitInitialDiagnosis) {
      return res.status(400).json({
        error: 'Use /doctor/initial-diagnosis to create initial diagnosis reports',
      });
    }

    // Create visit record
    const [existingVisitRows] = await db.query(
      'SELECT visitId FROM visit WHERE requestId = ? LIMIT 1',
      [requestId]
    );
    const visitId = existingVisitRows.length > 0
      ? existingVisitRows[0].visitId
      : randomUUID();
    if (existingVisitRows.length === 0) {
      await db.query(
        'INSERT INTO visit (visitId, requestId) VALUES (?, ?)',
        [visitId, requestId]
      );
    }

    const existingReportForVisit = await reportExistsForRequest(requestId);
    if (existingReportForVisit) {
      console.log('[doctor:reports:submit:duplicate-blocked]', {
        requestId,
        patientId: request.patientUserId,
        doctorId,
        visitId,
      });
      return res.status(409).json({
        error: 'A report already exists for this completed visit',
        hasReportForVisit: true,
      });
    }

    const finalDiagnosis = (diagnosis || '').toString();
    const finalTreatmentPlan = submitInitialDiagnosis
      ? (treatmentPlan || notes || '').toString()
      : (notes || '').toString();
    const legacyNotes = submitInitialDiagnosis
      ? [
          chiefComplaint ? `Chief Complaint:\n${chiefComplaint}` : '',
          symptoms ? `Symptoms:\n${symptoms}` : '',
          medicalHistory ? `Medical History:\n${medicalHistory}` : '',
          finalTreatmentPlan ? `Treatment Plan:\n${finalTreatmentPlan}` : '',
          requiredVisits ? `Required Visits:\n${requiredVisits}` : '',
        ]
          .filter(Boolean)
          .join('\n\n')
      : (notes || '').toString();

    // Create visit report
    const reportId = randomUUID();
    await db.query(
      'INSERT INTO visitreport (reportId, notes, diagnosis, visitId) VALUES (?, ?, ?, ?)',
      [reportId, legacyNotes, finalDiagnosis, visitId]
    );

    try {
      if (await medicalRecordService.tableExists('visit_reports')) {
        const structuredReport = await medicalRecordService.insertVisitReport({
          patient_id: request.patientUserId,
          provider_id: doctorId,
          appointment_id: requestId,
          report_kind: 'visit_report',
          chief_complaint: '',
          symptoms: '',
          medical_history: '',
          required_visits: '',
          diagnosis: finalDiagnosis,
          treatment_plan: finalTreatmentPlan,
          recommendations: prescription || '',
          medications_prescribed: prescription || '',
          follow_up_required: false,
        });
        console.log('[doctor:reports:structured-insert]', {
          requestId,
          patientId: request.patientUserId,
          doctorId,
          reportKind: 'visit_report',
          structuredReportId: structuredReport?.id,
          structuredReportKind:
            structuredReport?.report_kind ?? structuredReport?.record_type,
        });
      }
    } catch (err) {
      console.error('[doctor:reports:structured-insert:error]', {
        requestId,
        patientId: request.patientUserId,
        doctorId,
        reportKind: submitInitialDiagnosis
          ? 'initial_diagnosis'
          : 'visit_report',
        error: err.message,
      });
    }

    const initialExistsAfterSubmit = await initialDiagnosisExistsForCase(
      request.patientUserId,
      doctorId
    );
    console.log('[doctor:reports:submit:after-save]', {
      requestId,
      patientId: request.patientUserId,
      doctorId,
      submitInitialDiagnosis,
      legacyReportId: reportId,
      visitId,
      initialExistsAfterSubmit,
    });

    if (prescription && prescription.trim()) {
      const [recordRows] = await db.query(
        'SELECT recordId FROM medicalrecord WHERE patientUserId = ? LIMIT 1',
        [request.patientUserId]
      );

      if (recordRows.length > 0) {
        const columns = ['recordId', 'authorUserId', 'noteText'];
        const placeholders = ['?', '?', '?'];
        const values = [
          recordRows[0].recordId,
          doctorId,
          `Prescription / Instructions: ${prescription.trim()}`
        ];

        if (await hasColumn('clinicalnote', 'noteId')) {
          columns.unshift('noteId');
          placeholders.unshift('?');
          values.unshift(randomUUID());
        } else if (await hasColumn('clinicalnote', 'clinicalNoteId')) {
          columns.unshift('clinicalNoteId');
          placeholders.unshift('?');
          values.unshift(randomUUID());
        }

        if (await hasColumn('clinicalnote', 'createdAt')) {
          columns.push('createdAt');
          placeholders.push('NOW()');
        }

        await db.query(
          `INSERT INTO clinicalnote (${columns.join(', ')})
           VALUES (${placeholders.join(', ')})`,
          values
        );
      }
    }

    // Add status history
    await db.query(
      `INSERT INTO appointmentstatushistory (statusHistoryId, requestId, patientUserId, providerUserId, statusCode, sourceRole, note)
       VALUES (?, ?, ?, ?, 'completed', 'doctor', 'Medical report submitted')`,
      [randomUUID(), requestId, request.patientUserId, doctorId]
    );

    try {
      await insertNotification({
        userId: request.patientUserId,
        type: 'medical_report',
        title: 'Medical report ready',
        body: 'Your doctor submitted the medical report for the completed visit.',
        relatedRequestId: requestId,
      });
    } catch (_) {}

    res.json({ 
      success: true, 
      message: 'Medical report submitted successfully',
      reportType: submitInitialDiagnosis ? 'initial_diagnosis' : 'visit_report',
      visitId,
      reportId
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// MANAGE AVAILABILITY (AVAILABLE/UNAVAILABLE)
// ============================================
router.put('/availability/:doctorId', async (req, res) => {
  const { doctorId } = req.params;
  const { isAvailable } = req.body;

  try {
    try {
      await assertProviderCanWork(doctorId);
    } catch (err) {
      return res.status(err.status || 403).json({
        error: err.message,
        eligibility: err.eligibility || null,
      });
    }
    await db.query(
      'UPDATE careprovider SET isAvailable = ? WHERE userId = ?',
      [isAvailable ? 1 : 0, doctorId]
    );

    res.json({ 
      success: true, 
      message: `Doctor is now ${isAvailable ? 'available' : 'unavailable'}` 
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// GET AVAILABILITY STATUS
// ============================================
router.get('/availability/:doctorId', async (req, res) => {
  const { doctorId } = req.params;

  try {
    await assertDoctorUser(doctorId);
    const [rows] = await db.query(
      'SELECT isAvailable FROM careprovider WHERE userId = ?',
      [doctorId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    res.json({
      doctorId,
      isAvailable: rows[0].isAvailable === 1
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// NOTIFICATION PREFERENCES
// ============================================
router.get('/notification-preferences/:doctorId', async (req, res) => {
  const { doctorId } = req.params;

  if (!doctorId) {
    return res.status(400).json({ error: 'Doctor ID is required' });
  }

  try {
    const prefs = await getDoctorNotificationPrefs(doctorId);
    res.json(prefs);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/notification-preferences/:doctorId', async (req, res) => {
  const { doctorId } = req.params;
  const allowed = [
    'medicalCases',
    'patientUpdates',
    'newAppointments',
    'assignmentUpdates',
    'cancellations',
  ];

  if (!doctorId) {
    return res.status(400).json({ error: 'Doctor ID is required' });
  }

  try {
    await ensureDoctorNotificationPreferenceTable();
    await db.execute(
      `INSERT IGNORE INTO doctornotificationpreference (doctorUserId)
       VALUES (?)`,
      [doctorId]
    );

    const updates = [];
    const values = [];
    for (const key of allowed) {
      if (Object.prototype.hasOwnProperty.call(req.body || {}, key)) {
        updates.push(`${key} = ?`);
        values.push(req.body[key] ? 1 : 0);
      }
    }

    if (updates.length > 0) {
      values.push(doctorId);
      await db.execute(
        `UPDATE doctornotificationpreference
         SET ${updates.join(', ')}
         WHERE doctorUserId = ?`,
        values
      );
    }

    const prefs = await getDoctorNotificationPrefs(doctorId);
    res.json({ success: true, preferences: prefs });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// MANAGE SCHEDULE (AVAILABILITY SLOTS)
// ============================================
router.get('/schedule/:doctorId', async (req, res) => {
  const { doctorId } = req.params;

  try {
    await assertDoctorUser(doctorId);
    const [rows] = await db.query(
      'SELECT * FROM availabilityslot WHERE providerUserId = ? ORDER BY day, startTime',
      [doctorId]
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// ADD AVAILABILITY SLOT
// ============================================
router.post('/schedule/:doctorId', async (req, res) => {
  const { doctorId } = req.params;
  const { day, startTime, endTime } = req.body;

  if (!day || !startTime || !endTime) {
    return res
      .status(400)
      .json({ error: 'Day, startTime, and endTime are required' });
  }

  try {
    try {
      await assertProviderCanWork(doctorId);
    } catch (err) {
      return res.status(err.status || 403).json({
        error: err.message,
        eligibility: err.eligibility || null,
      });
    }
    const hourlySlots = expandDoctorScheduleSlot({ day, startTime, endTime });
    const savedSlots = [];

    for (const slot of hourlySlots) {
      const slotId = `slot-${doctorId.substring(0, 4)}-${randomUUID().substring(0, 8)}`;
      await db.query(
        'INSERT INTO availabilityslot (slot_id, day, startTime, endTime, providerUserId) VALUES (?, ?, ?, ?, ?)',
        [slotId, slot.day, slot.startTime, slot.endTime, doctorId]
      );
      savedSlots.push({ slot_id: slotId, ...slot, providerUserId: doctorId });
    }

    res.json({
      success: true,
      message: 'Availability slots added',
      slotId: savedSlots[0]?.slot_id,
      slots: savedSlots,
    });
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

// ============================================
// UPDATE AVAILABILITY SLOT
// ============================================
router.put('/schedule/:doctorId/:slotId', async (req, res) => {
  const { doctorId, slotId } = req.params;
  const { day, startTime, endTime } = req.body;

  if (!day || !startTime || !endTime) {
    return res.status(400).json({
      error: 'Day, startTime, and endTime are required',
    });
  }

  try {
    try {
      await assertProviderCanWork(doctorId);
    } catch (err) {
      return res.status(err.status || 403).json({
        error: err.message,
        eligibility: err.eligibility || null,
      });
    }
    const hourlySlots = expandDoctorScheduleSlot({ day, startTime, endTime });
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const [deleted] = await conn.query(
        'DELETE FROM availabilityslot WHERE slot_id = ? AND providerUserId = ?',
        [slotId, doctorId]
      );
      if (!deleted.affectedRows) {
        await conn.rollback();
        conn.release();
        return res.status(404).json({ error: 'Availability slot not found' });
      }

      const savedSlots = [];
      for (const slot of hourlySlots) {
        const nextSlotId = `slot-${doctorId.substring(0, 4)}-${randomUUID().substring(0, 8)}`;
        await conn.query(
          'INSERT INTO availabilityslot (slot_id, day, startTime, endTime, providerUserId) VALUES (?, ?, ?, ?, ?)',
          [nextSlotId, slot.day, slot.startTime, slot.endTime, doctorId]
        );
        savedSlots.push({
          slot_id: nextSlotId,
          ...slot,
          providerUserId: doctorId,
        });
      }

      await conn.commit();
      conn.release();
      return res.json({
        success: true,
        message: 'Availability slots updated',
        slots: savedSlots,
      });
    } catch (err) {
      await conn.rollback();
      conn.release();
      throw err;
    }
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

// ============================================
// DELETE AVAILABILITY SLOT
// ============================================
router.delete('/schedule/:doctorId/:slotId', async (req, res) => {
  const { doctorId, slotId } = req.params;

  try {
    try {
      await assertProviderCanWork(doctorId);
    } catch (err) {
      return res.status(err.status || 403).json({
        error: err.message,
        eligibility: err.eligibility || null,
      });
    }
    await db.query(
      'DELETE FROM availabilityslot WHERE slot_id = ? AND providerUserId = ?',
      [slotId, doctorId]
    );

    res.json({ success: true, message: 'Availability slot deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// GET RATINGS AND FEEDBACK
// ============================================
router.get('/ratings/:doctorId', async (req, res) => {
  const { doctorId } = req.params;

  try {
    if (!(await hasTable('providervisitrating'))) {
      return res.json({
        reviews: [],
        summary: {
          averageRating: 0,
          totalReviews: 0,
          distribution: [],
        },
      });
    }

    const ratings = await visitRatingService.listRatingsForProvider(doctorId);

    const [reviews] = await db.query(
      `SELECT
         pvr.ratingId,
         pvr.requestId,
         pvr.patientUserId,
         pvr.providerUserId,
         pvr.stars AS rating,
         pvr.comment AS reviewText,
         pvr.createdAt,
         u.fullName as patientName,
         sr.reasonForVisit,
         sr.serviceType
       FROM providervisitrating pvr
       JOIN user u ON pvr.patientUserId = u.userId
       JOIN servicerequest sr ON pvr.requestId = sr.requestId
       WHERE pvr.providerUserId = ?
       ORDER BY pvr.createdAt DESC`,
      [doctorId]
    );

    const [distribution] = await db.query(
      `SELECT stars AS rating, COUNT(*) as count
       FROM providervisitrating
       WHERE providerUserId = ?
       GROUP BY stars
       ORDER BY stars DESC`,
      [doctorId]
    );

    res.json({
      reviews,
      summary: {
        averageRating: ratings.averageRating || 0,
        totalReviews: ratings.ratingsCount || 0,
        distribution
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// GET PAYMENT HISTORY
// ============================================
router.get('/payments/:doctorId', async (req, res) => {
  const { doctorId } = req.params;

  try {
    await assertDoctorUser(doctorId);
    try {
      await assertProviderCanWork(doctorId);
    } catch (err) {
      return res.status(err.status || 403).json({
        error: err.message,
        eligibility: err.eligibility || null,
      });
    }
    const [rows] = await db.query(
      `SELECT 
        p.*,
        sr.serviceType,
        sr.status as requestStatus,
        sr.scheduledAt,
        u.fullName as patientName
      FROM payment p
      JOIN servicerequest sr ON p.requestId = sr.requestId
      JOIN user u ON p.patientUserId = u.userId
      WHERE p.providerUserId = ?
      ORDER BY p.createdAt DESC`,
      [doctorId]
    );

    // Calculate totals
    const [totals] = await db.query(
      `SELECT 
        SUM(CASE WHEN paymentStatus = 'paid' THEN amount ELSE 0 END) as totalPaid,
        SUM(CASE WHEN paymentStatus = 'unpaid' THEN amount ELSE 0 END) as totalUnpaid,
        SUM(CASE WHEN paymentStatus = 'refunded' THEN amount ELSE 0 END) as totalRefunded,
        COUNT(*) as totalPayments
      FROM payment 
      WHERE providerUserId = ?`,
      [doctorId]
    );

    res.json({
      payments: rows,
      summary: totals[0]
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================
// GET DASHBOARD STATS
// ============================================
router.get('/dashboard/:doctorId', async (req, res) => {
  const { doctorId } = req.params;

  try {
    // Pending requests count
    const [pendingResult] = await db.query(
      "SELECT COUNT(*) as count FROM servicerequest WHERE providerUserId = ? AND status = 'pending'",
      [doctorId]
    );

    // Confirmed requests count
    const [confirmedResult] = await db.query(
      "SELECT COUNT(*) as count FROM servicerequest WHERE providerUserId = ? AND status = 'confirmed'",
      [doctorId]
    );

    // Completed requests count
    const [completedResult] = await db.query(
      "SELECT COUNT(*) as count FROM servicerequest WHERE providerUserId = ? AND status = 'completed'",
      [doctorId]
    );

    // Cancelled requests count
    const [cancelledResult] = await db.query(
      "SELECT COUNT(*) as count FROM servicerequest WHERE providerUserId = ? AND status = 'cancelled'",
      [doctorId]
    );

    // Total earnings
    const [earningsResult] = await db.query(
      "SELECT SUM(amount) as total FROM payment WHERE providerUserId = ? AND paymentStatus = 'paid'",
      [doctorId]
    );

    let averageRating = 0;
    if (await hasTable('providervisitrating')) {
      const [ratingResult] = await db.query(
        'SELECT AVG(stars) as average FROM providervisitrating WHERE providerUserId = ?',
        [doctorId]
      );
      averageRating = ratingResult[0].average || 0;
    }

    // Today's appointments
    const today = new Date().toISOString().split('T')[0];
    const [todayResult] = await db.query(
      `SELECT COUNT(*) as count FROM servicerequest 
       WHERE providerUserId = ? AND DATE(scheduledAt) = ? AND status IN ('pending', 'confirmed')`,
      [doctorId, today]
    );

    const [patientsResult] = await db.query(
      `SELECT COUNT(DISTINCT patientUserId) as count
       FROM servicerequest
       WHERE providerUserId = ? AND status IN ('pending', 'confirmed', 'completed')`,
      [doctorId]
    );

    const pendingRequests = pendingResult[0].count || 0;
    const confirmedRequests = confirmedResult[0].count || 0;
    const completedRequests = completedResult[0].count || 0;
    const cancelledRequests = cancelledResult[0].count || 0;
    const totalRequests =
      pendingRequests + confirmedRequests + completedRequests + cancelledRequests;
    const respondedRequests = confirmedRequests + completedRequests + cancelledRequests;
    const responseRate =
      totalRequests > 0 ? Math.round((respondedRequests / totalRequests) * 100) : 0;

    res.json({
      pendingRequests,
      confirmedRequests,
      completedRequests,
      totalEarnings: earningsResult[0].total || 0,
      averageRating,
      todayAppointments: todayResult[0].count || 0,
      totalPatients: patientsResult[0].count || 0,
      responseRate
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

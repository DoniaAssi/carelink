const express = require('express');
const { randomUUID } = require('crypto');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const db = require('../db');
const { insertNotification } = require('../notifications');
const visitRatingService = require('../services/visitRatingService');
const bookingPaymentService = require('../services/bookingPaymentService');

const router = express.Router();
const chatUploadsDir = path.join(__dirname, '..', 'uploads', 'chat');
fs.mkdirSync(chatUploadsDir, { recursive: true });

const chatUpload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, chatUploadsDir),
    filename: (req, file, cb) => {
      const safeName = path
        .basename(file.originalname)
        .replace(/[^a-zA-Z0-9._-]+/g, '-');
      cb(null, `${Date.now()}-${randomUUID()}-${safeName}`);
    },
  }),
  limits: { fileSize: 25 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed =
      file.mimetype.startsWith('image/') ||
      file.mimetype.startsWith('audio/') ||
      file.mimetype === 'application/pdf';
    cb(allowed ? null : new Error('Only images, PDF files, and audio are supported'), allowed);
  },
});

const chatTyping = new Map();
let chatSchemaPromise;

const BOOKING_STATUSES = [
  'pending_provider_approval',
  'pending',
  'pending_payment',
  'payment_pending',
  'confirmed',
  'completed',
  'cancelled',
];
const PAYMENT_STATUSES = ['unpaid', 'pending', 'paid', 'failed', 'refunded'];
const columnCache = new Map();
const tableCache = new Map();

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

/** Safe EXISTS() for legacy `providerreview` (column names vary). Returns `0` if unusable. */
async function providerReviewExistsSql() {
  const hasTab = await hasTable('providerreview');
  if (!hasTab) return '0';
  const hasReq = await hasColumn('providerreview', 'requestId');
  const hasApp = await hasColumn('providerreview', 'appointmentId');
  const parts = [];
  if (hasReq) {
    parts.push(
      'EXISTS (SELECT 1 FROM providerreview prv_req WHERE prv_req.requestId = sr.requestId)',
    );
  }
  if (hasApp) {
    parts.push(
      'EXISTS (SELECT 1 FROM providerreview prv_app WHERE prv_app.appointmentId = sr.requestId)',
    );
  }
  if (!parts.length) return '0';
  return `(${parts.join(' OR ')})`;
}

async function appointmentRatingSqlFragments() {
  const hasPvr = await hasTable('providervisitrating');
  const prExistsSql = await providerReviewExistsSql();

  if (hasPvr) {
    return {
      ratingSelect: `pvr.stars AS patientRatingStars, pvr.comment AS patientRatingComment,
        (pvr.ratingId IS NOT NULL OR (${prExistsSql})) AS hasPatientRating`,
      ratingJoin:
        'LEFT JOIN providervisitrating pvr ON TRIM(pvr.requestId) = TRIM(sr.requestId)',
    };
  }
  if ((await hasTable('providerreview')) && prExistsSql !== '0') {
    return {
      ratingSelect: `NULL AS patientRatingStars, NULL AS patientRatingComment,
        (${prExistsSql}) AS hasPatientRating`,
      ratingJoin: '',
    };
  }
  return {
    ratingSelect:
      'NULL AS patientRatingStars, NULL AS patientRatingComment, 0 AS hasPatientRating',
    ratingJoin: '',
  };
}

function scheduleDbgEnabled() {
  const v = (process.env.CARELINK_DEBUG_SCHEDULE || '').toString().trim().toLowerCase();
  return v === '1' || v === 'true' || v === 'yes';
}

function scheduleDbg(tag, payload) {
  if (!scheduleDbgEnabled()) return;
  // eslint-disable-next-line no-console
  console.log(`[CareLink schedule] ${tag}`);
}

/** ENUM / mixed casing: normalize to lowercase string without breaking joins. */
const normStatusSql = `LOWER(TRIM(CAST(sr.status AS CHAR(64))))`;

function normalizeDateTime(date, time) {
  if (!date || !time) return null;
  const trimmedDate = date.toString().trim();
  let trimmedTime = time.toString().trim();
  const match12 = /^(\d{1,2}):(\d{2})\s*(AM|PM)$/i.exec(trimmedTime);
  if (match12) {
    let hour = Number(match12[1]);
    const minute = match12[2];
    const period = match12[3].toUpperCase();
    if (hour < 1 || hour > 12) return null;
    hour %= 12;
    if (period === 'PM') hour += 12;
    trimmedTime = `${String(hour).padStart(2, '0')}:${minute}:00`;
  } else {
    const match24 = /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/.exec(trimmedTime);
    if (!match24) return null;
    const hour = Number(match24[1]);
    const minute = Number(match24[2]);
    const second = match24[3] == null ? 0 : Number(match24[3]);
    if (hour > 23 || minute > 59 || second > 59) return null;
    trimmedTime = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:${String(second).padStart(2, '0')}`;
  }
  return `${trimmedDate} ${trimmedTime}`;
}

function toStatus(value, allowed, fallback) {
  const normalized = (value || '').toString().trim().toLowerCase();
  if (allowed.includes(normalized)) return normalized;
  return fallback;
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

async function ensureChatSchema() {
  if (chatSchemaPromise) return chatSchemaPromise;

  chatSchemaPromise = (async () => {
    const columns = [
      ['conversationId', 'CHAR(36) NULL'],
      ['clientMessageId', 'VARCHAR(96) NULL'],
      ['senderRole', "VARCHAR(32) NULL"],
      ['receiverRole', "VARCHAR(32) NULL"],
      ['status', "VARCHAR(32) NOT NULL DEFAULT 'sent'"],
      ['messageType', "VARCHAR(32) NOT NULL DEFAULT 'text'"],
      ['attachmentUrl', 'TEXT NULL'],
      ['attachmentName', 'VARCHAR(255) NULL'],
      ['attachmentSize', 'BIGINT NULL'],
      ['attachmentMimeType', 'VARCHAR(128) NULL'],
      ['medicalRecordId', 'VARCHAR(64) NULL'],
      ['voiceDurationSeconds', 'INT NULL'],
      ['sentAt', 'DATETIME NULL'],
      ['deliveredAt', 'DATETIME NULL'],
      ['readAt', 'DATETIME NULL'],
      ['isRead', 'TINYINT(1) NOT NULL DEFAULT 0'],
    ];

    for (const [name, definition] of columns) {
      if (!(await hasColumn('message', name))) {
        await db.query(`ALTER TABLE message ADD COLUMN ${name} ${definition}`);
        columnCache.set(`message.${name}`, true);
      }
    }

    await db.query(
      `UPDATE message SET sentAt = COALESCE(sentAt, createdAt)
       WHERE sentAt IS NULL`
    );
    await db.query(
      `CREATE TABLE IF NOT EXISTS chat_presence (
        userId VARCHAR(64) NOT NULL,
        lastActive DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (userId)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
    );
    await db.query(
      `CREATE TABLE IF NOT EXISTS chatconversation (
        conversationId CHAR(36) NOT NULL PRIMARY KEY,
        patientId VARCHAR(64) NOT NULL,
        nurseId VARCHAR(64) NOT NULL,
        requestId VARCHAR(64) NOT NULL DEFAULT '',
        appointmentId VARCHAR(64) NOT NULL DEFAULT '',
        visitId VARCHAR(64) NOT NULL DEFAULT '',
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        lastMessage TEXT NULL,
        lastMessageAt DATETIME NULL,
        lastSenderId VARCHAR(64) NULL,
        UNIQUE KEY uniq_chatconversation_relation (nurseId, patientId, requestId)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
    );
  })().catch((error) => {
    chatSchemaPromise = null;
    throw error;
  });

  return chatSchemaPromise;
}

async function touchChatPresence(userId) {
  if (!userId) return;
  await db.query(
    `INSERT INTO chat_presence (userId, lastActive)
     VALUES (?, NOW())
     ON DUPLICATE KEY UPDATE lastActive = NOW()`,
    [userId]
  );
}

function chatMessageSelect() {
  return `messageId, conversationId, senderId, senderRole, receiverId, receiverRole,
    message, messageType, clientMessageId, status,
    attachmentUrl, attachmentName, attachmentSize, attachmentMimeType,
    medicalRecordId, voiceDurationSeconds, createdAt, sentAt, deliveredAt,
    readAt, isRead`;
}

function normalizeChatId(value) {
  return (value || '').toString().trim();
}

async function getConversationForUser(conversationId, userId) {
  const [rows] = await db.query(
    `SELECT * FROM chatconversation
     WHERE conversationId = ? AND (patientId = ? OR nurseId = ?)
     LIMIT 1`,
    [conversationId, userId, userId]
  );
  return rows[0] || null;
}

async function getConversationMeta(conversation) {
  const patientId = conversation.patientId;
  const nurseId = conversation.nurseId;
  const [users] = await db.query(
    `SELECT userId, fullName, role
     FROM user WHERE userId IN (?, ?)`,
    [patientId, nurseId]
  );
  const patient = users.find((u) => u.userId === patientId) || {};
  const nurse = users.find((u) => u.userId === nurseId) || {};
  return { patient, nurse };
}

function normalizeDiseasePayload(input) {
  if (!Array.isArray(input)) return [];

  const allowedStatuses = ['active', 'chronic', 'previous', 'resolved'];
  const seen = new Set();
  const normalized = [];

  for (const item of input) {
    const rawId =
      typeof item === 'string'
        ? item
        : item?.diseaseId ?? item?.id ?? '';
    const diseaseId = rawId.toString().trim();
    if (!diseaseId || seen.has(diseaseId)) continue;
    seen.add(diseaseId);

    const rawStatus =
      (typeof item === 'object' ? item?.diseaseStatus ?? item?.status : '')
        ?.toString()
        .trim()
        .toLowerCase() ?? '';

    normalized.push({
      diseaseId,
      diseaseStatus: allowedStatuses.includes(rawStatus) ? rawStatus : 'active',
      notes:
        typeof item === 'object' && item?.notes != null
          ? item.notes.toString()
          : null
    });
  }

  return normalized;
}

function normalizeAllergyPayload(input) {
  if (!Array.isArray(input)) return [];

  const allowedSeverities = ['mild', 'moderate', 'severe', 'unknown'];
  const seen = new Set();
  const normalized = [];

  for (const item of input) {
    const rawId =
      typeof item === 'string'
        ? item
        : item?.allergyId ?? item?.id ?? '';
    const allergyId = rawId.toString().trim();
    if (!allergyId || seen.has(allergyId)) continue;
    seen.add(allergyId);

    const rawSeverity =
      (typeof item === 'object' ? item?.severity : '')
        ?.toString()
        .trim()
        .toLowerCase() ?? '';

    normalized.push({
      allergyId,
      severity: allowedSeverities.includes(rawSeverity) ? rawSeverity : 'unknown',
      reaction:
        typeof item === 'object' && item?.reaction != null
          ? item.reaction.toString()
          : null,
      notes:
        typeof item === 'object' && item?.notes != null
          ? item.notes.toString()
          : null
    });
  }

  return normalized;
}

async function replaceMedicalRecordDiseases(connection, recordId, diseases) {
  await connection.execute(
    'DELETE FROM medicalrecorddisease WHERE recordId = ?',
    [recordId]
  );

  if (!diseases.length) return;

  for (const disease of diseases) {
    await connection.execute(
      `INSERT INTO medicalrecorddisease
       (recordDiseaseId, recordId, diseaseId, diseaseStatus, notes, createdAt)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [
        randomUUID(),
        recordId,
        disease.diseaseId,
        disease.diseaseStatus,
        disease.notes
      ]
    );
  }
}

async function replaceMedicalRecordAllergies(connection, recordId, allergies) {
  await connection.execute(
    'DELETE FROM medicalrecordallergy WHERE recordId = ?',
    [recordId]
  );

  if (!allergies.length) return;

  for (const allergy of allergies) {
    await connection.execute(
      `INSERT INTO medicalrecordallergy
       (recordAllergyId, recordId, allergyId, severity, reaction, notes, createdAt)
       VALUES (?, ?, ?, ?, ?, ?, NOW())`,
      [
        randomUUID(),
        recordId,
        allergy.allergyId,
        allergy.severity,
        allergy.reaction,
        allergy.notes
      ]
    );
  }
}

router.get('/profile/:userId', async (req, res) => {
  const { userId } = req.params;

  try {
    const hasProfileImageUrl = await hasColumn('user', 'profileImageUrl');
    const hasPatientDob = await hasColumn('patient', 'dateOfBirth');
    const hasPatientGender = await hasColumn('patient', 'gender');
    const hasChronic = await hasColumn('patient', 'chronicDiseases');
    const hasAllergies = await hasColumn('patient', 'allergies');
    const hasMeds = await hasColumn('patient', 'currentMedications');
    const hasBloodType = await hasColumn('medicalrecord', 'bloodType');

    const [rows] = await db.query(
      `SELECT
         u.userId,
         u.fullName,
         u.email,
         u.phone,
         u.role,
         ${
           hasProfileImageUrl ? 'u.profileImageUrl' : 'NULL AS profileImageUrl'
         },
         p.addressText,
         p.gpsLat,
         p.gpsLng,
         ${hasPatientDob ? 'p.dateOfBirth' : 'NULL AS dateOfBirth'},
         ${hasPatientGender ? 'p.gender' : 'NULL AS gender'},
         ${hasChronic ? 'p.chronicDiseases' : 'NULL AS chronicDiseases'},
         ${hasAllergies ? 'p.allergies' : 'NULL AS allergies'},
         ${hasMeds ? 'p.currentMedications' : 'NULL AS currentMedications'},
         ${
           hasBloodType
             ? `(SELECT mr.bloodType
                 FROM medicalrecord mr
                 WHERE mr.patientUserId = u.userId
                 ORDER BY mr.updatedAt DESC, mr.createdAt DESC
                 LIMIT 1) AS bloodType`
             : 'NULL AS bloodType'
         }
       FROM user u
       LEFT JOIN patient p ON u.userId = p.userId
       WHERE u.userId = ?`,
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadsDir = path.join(__dirname, '..', 'uploads');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, `profile_${Date.now()}_${Math.round(Math.random() * 1E9)}${ext}`);
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit
  }
});

router.post('/profile/upload', (req, res) => {
  const contentLength = req.headers['content-length'];
  console.log(`[Upload] Incoming upload request. Content-Length: ${contentLength} bytes`);

  upload.single('image')(req, res, (err) => {
    if (err) {
      console.error(`[Upload] Upload failed: ${err.message}`);
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({ error: 'Image size must be less than 5MB' });
      }
      return res.status(400).json({ error: err.message });
    }

    if (!req.file) {
      return res.status(400).json({ error: 'No image file uploaded' });
    }

    console.log(`[Upload] Saved image to uploads/${req.file.filename}. Size: ${req.file.size} bytes`);
    res.json({
      url: `/uploads/${req.file.filename}`
    });
  });
});

router.put('/profile/:userId', async (req, res) => {
  const { userId } = req.params;
  const contentLength = req.headers['content-length'];
  console.log(`[Profile Update] PUT /patient/profile/${userId} - Content-Length: ${contentLength} bytes`);

  const {
    fullName,
    email,
    phone,
    addressText,
    gpsLat,
    gpsLng,
    dateOfBirth,
    gender,
    profileImageUrl,
    chronicDiseases,
    allergies,
    currentMedications,
    bloodType
  } = req.body;

  if (!fullName || !email || !phone) {
    return res.status(400).json({ error: 'fullName, email and phone are required' });
  }

  try {
    const normalizedGender = gender?.toString().trim().toLowerCase();
    const allowedGenders = ['male', 'female', 'other', 'prefer_not_to_say'];
    if (normalizedGender && !allowedGenders.includes(normalizedGender)) {
      return res.status(400).json({
        error: 'gender must be one of: male, female, other, prefer_not_to_say'
      });
    }

    const hasProfileImageUrl = await hasColumn('user', 'profileImageUrl');
    const hasPatientDob = await hasColumn('patient', 'dateOfBirth');
    const hasPatientGender = await hasColumn('patient', 'gender');
    const hasChronic = await hasColumn('patient', 'chronicDiseases');
    const hasAllergies = await hasColumn('patient', 'allergies');
    const hasMeds = await hasColumn('patient', 'currentMedications');
    const hasBloodType = await hasColumn('medicalrecord', 'bloodType');

    let userResult;
    if (hasProfileImageUrl) {
      if (req.body.hasOwnProperty('profileImageUrl')) {
        [userResult] = await db.execute(
          `UPDATE user
           SET fullName = ?,
               email = ?,
               phone = ?,
               profileImageUrl = ?
           WHERE userId = ?`,
          [fullName, email, phone, profileImageUrl || null, userId]
        );
      } else {
        [userResult] = await db.execute(
          `UPDATE user
           SET fullName = ?,
               email = ?,
               phone = ?
           WHERE userId = ?`,
          [fullName, email, phone, userId]
        );
      }
    } else {
      [userResult] = await db.execute(
        `UPDATE user
         SET fullName = ?,
             email = ?,
             phone = ?
         WHERE userId = ?`,
        [fullName, email, phone, userId]
      );
    }

    if (!userResult.affectedRows) {
      return res.status(404).json({ error: 'User not found' });
    }

    const baselineUpdate =
      addressText != null ||
      gpsLat != null ||
      gpsLng != null ||
      dateOfBirth != null ||
      normalizedGender != null ||
      chronicDiseases != null ||
      allergies != null ||
      currentMedications != null;

    if (baselineUpdate) {
      const setParts = [
        'addressText = COALESCE(?, addressText)',
        'gpsLat = COALESCE(?, gpsLat)',
        'gpsLng = COALESCE(?, gpsLng)',
      ];
      const execVals = [
        addressText ?? null,
        gpsLat ?? null,
        gpsLng ?? null,
      ];
      if (hasPatientDob) {
        setParts.push('dateOfBirth = COALESCE(?, dateOfBirth)');
        execVals.push(dateOfBirth ?? null);
      }
      if (hasPatientGender) {
        setParts.push('gender = COALESCE(?, gender)');
        execVals.push(normalizedGender ?? null);
      }
      if (hasChronic) {
        setParts.push('chronicDiseases = COALESCE(?, chronicDiseases)');
        execVals.push(
          chronicDiseases != null
            ? chronicDiseases.toString()
            : null
        );
      }
      if (hasAllergies) {
        setParts.push('allergies = COALESCE(?, allergies)');
        execVals.push(allergies != null ? allergies.toString() : null);
      }
      if (hasMeds) {
        setParts.push('currentMedications = COALESCE(?, currentMedications)');
        execVals.push(
          currentMedications != null ? currentMedications.toString() : null
        );
      }
      execVals.push(userId);

      await db.execute(
        `UPDATE patient SET ${setParts.join(', ')} WHERE userId = ?`,
        execVals
      );
    }

    if (hasBloodType && Object.prototype.hasOwnProperty.call(req.body, 'bloodType')) {
      const normalizedBloodType = bloodType != null ? bloodType.toString().trim() : '';
      const [recordRows] = await db.query(
        `SELECT recordId
         FROM medicalrecord
         WHERE patientUserId = ?
         ORDER BY updatedAt DESC, createdAt DESC
         LIMIT 1`,
        [userId]
      );
      if (recordRows.length > 0) {
        await db.execute(
          `UPDATE medicalrecord
           SET bloodType = ?, updatedAt = NOW()
           WHERE recordId = ? AND patientUserId = ?`,
          [normalizedBloodType, recordRows[0].recordId, userId]
        );
      }
    }

    res.json({ message: 'Profile updated successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/location/:userId', async (req, res) => {
  const { userId } = req.params;
  const { gpsLat, gpsLng, addressText } = req.body;

  if (gpsLat == null || gpsLng == null) {
    return res.status(400).json({ error: 'gpsLat and gpsLng are required' });
  }

  try {
    const [result] = await db.execute(
      `UPDATE patient
       SET gpsLat = ?, gpsLng = ?, addressText = COALESCE(?, addressText)
       WHERE userId = ?`,
      [gpsLat, gpsLng, addressText ?? null, userId]
    );

    if (!result.affectedRows) {
      return res.status(404).json({ error: 'Patient not found' });
    }

    res.json({ message: 'Location updated successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/medical-record/:patientUserId', async (req, res) => {
  const { patientUserId } = req.params;

  try {
    const hasPastSurgeries = await hasColumn('medicalrecord', 'pastSurgeries');
    const hasBloodType = await hasColumn('medicalrecord', 'bloodType');
    const hasPreviousDiagnoses = await hasColumn('medicalrecord', 'previousDiagnoses');
    const hasDoctorNotes = await hasColumn('medicalrecord', 'doctorNotes');
    const hasNurseNotes = await hasColumn('medicalrecord', 'nurseNotes');

    const [rows] = await db.query(
      `SELECT
        recordId,
        patientUserId,
        dateOfBirth,
        gender,
        previousConditions,
        chronicConditions,
        allergies,
        currentMedications,
        ${hasPastSurgeries ? 'pastSurgeries' : "'' AS pastSurgeries"},
        ${hasBloodType ? 'bloodType' : "'' AS bloodType"},
        ${hasPreviousDiagnoses ? 'previousDiagnoses' : "'' AS previousDiagnoses"},
        ${hasDoctorNotes ? 'doctorNotes' : "'' AS doctorNotes"},
        ${hasNurseNotes ? 'nurseNotes' : "'' AS nurseNotes"},
        additionalNotes,
        createdAt,
        updatedAt
      FROM medicalrecord
      WHERE patientUserId = ?
      ORDER BY updatedAt DESC, createdAt DESC`,
      [patientUserId]
    );

    if (rows.length === 0) {
      return res.json([]);
    }

    const recordIds = rows.map((row) => row.recordId);

    let diseaseRows = [];
    let allergyRows = [];

    try {
      const [fetchedDiseaseRows] = await db.query(
        `SELECT
            mrd.recordId,
            mrd.diseaseId,
            d.diseaseName,
            d.icdCode,
            mrd.diseaseStatus,
            mrd.notes
         FROM medicalrecorddisease mrd
         JOIN disease d ON mrd.diseaseId = d.diseaseId
         WHERE mrd.recordId IN (?)`,
        [recordIds]
      );
      diseaseRows = fetchedDiseaseRows;
    } catch (_) {
      diseaseRows = [];
    }

    try {
      const [fetchedAllergyRows] = await db.query(
        `SELECT
            mra.recordId,
            mra.allergyId,
            a.allergyName,
            a.allergyCategory,
            mra.severity,
            mra.reaction,
            mra.notes
         FROM medicalrecordallergy mra
         JOIN allergy a ON mra.allergyId = a.allergyId
         WHERE mra.recordId IN (?)`,
        [recordIds]
      );
      allergyRows = fetchedAllergyRows;
    } catch (_) {
      allergyRows = [];
    }

    const diseaseMap = new Map();
    for (const row of diseaseRows) {
      if (!diseaseMap.has(row.recordId)) diseaseMap.set(row.recordId, []);
      diseaseMap.get(row.recordId).push({
        diseaseId: row.diseaseId,
        diseaseName: row.diseaseName,
        icdCode: row.icdCode,
        diseaseStatus: row.diseaseStatus,
        notes: row.notes
      });
    }

    const allergyMap = new Map();
    for (const row of allergyRows) {
      if (!allergyMap.has(row.recordId)) allergyMap.set(row.recordId, []);
      allergyMap.get(row.recordId).push({
        allergyId: row.allergyId,
        allergyName: row.allergyName,
        allergyCategory: row.allergyCategory,
        severity: row.severity,
        reaction: row.reaction,
        notes: row.notes
      });
    }

    const enriched = rows.map((record) => ({
      ...record,
      diseases: diseaseMap.get(record.recordId) ?? [],
      allergiesList: allergyMap.get(record.recordId) ?? []
    }));

    res.json(enriched);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/medical-record', async (req, res) => {
  const {
    patientUserId,
    dateOfBirth,
    gender,
    previousConditions,
    chronicConditions,
    allergies,
    currentMedications,
    pastSurgeries,
    bloodType,
    previousDiagnoses,
    doctorNotes,
    nurseNotes,
    additionalNotes,
    diseases,
    allergiesList,
    allergiesDetails
  } = req.body;

  if (!patientUserId || !dateOfBirth || !gender) {
    return res.status(400).json({ error: 'patientUserId, dateOfBirth and gender are required' });
  }

  try {
    const hasPastSurgeries = await hasColumn('medicalrecord', 'pastSurgeries');
    const hasBloodType = await hasColumn('medicalrecord', 'bloodType');
    const hasPreviousDiagnoses = await hasColumn('medicalrecord', 'previousDiagnoses');
    const hasDoctorNotes = await hasColumn('medicalrecord', 'doctorNotes');
    const hasNurseNotes = await hasColumn('medicalrecord', 'nurseNotes');

    const recordId = randomUUID();
    const normalizedDiseases = normalizeDiseasePayload(diseases);
    const normalizedAllergies = normalizeAllergyPayload(
      allergiesList ?? allergiesDetails
    );

    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      const columns = [
        'recordId',
        'patientUserId',
        'dateOfBirth',
        'gender',
        'previousConditions',
        'chronicConditions',
        'allergies',
        'currentMedications'
      ];
      const values = [
        recordId,
        patientUserId,
        dateOfBirth,
        gender,
        previousConditions ?? '',
        chronicConditions ?? '',
        allergies ?? '',
        currentMedications ?? ''
      ];

      if (hasPastSurgeries) {
        columns.push('pastSurgeries');
        values.push(pastSurgeries ?? '');
      }
      if (hasBloodType) {
        columns.push('bloodType');
        values.push(bloodType ?? '');
      }
      if (hasPreviousDiagnoses) {
        columns.push('previousDiagnoses');
        values.push(previousDiagnoses ?? '');
      }
      if (hasDoctorNotes) {
        columns.push('doctorNotes');
        values.push(doctorNotes ?? '');
      }
      if (hasNurseNotes) {
        columns.push('nurseNotes');
        values.push(nurseNotes ?? '');
      }

      columns.push('additionalNotes');
      values.push(additionalNotes ?? '');
      columns.push('createdAt', 'updatedAt');

      const placeholders = [
        ...List.filled(values.length, '?'),
        'NOW()',
        'NOW()'
      ];

      await connection.execute(
        `INSERT INTO medicalrecord
         (${columns.join(', ')})
         VALUES (${placeholders.join(', ')})`,
        values
      );

      await replaceMedicalRecordDiseases(connection, recordId, normalizedDiseases);
      await replaceMedicalRecordAllergies(connection, recordId, normalizedAllergies);

      await connection.commit();
    } catch (e) {
      await connection.rollback();
      throw e;
    } finally {
      connection.release();
    }

    res.status(201).json({
      message: 'Medical record created successfully',
      recordId
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/medical-record/:recordId', async (req, res) => {
  const { recordId } = req.params;
  const {
    patientUserId,
    dateOfBirth,
    gender,
    previousConditions,
    chronicConditions,
    allergies,
    currentMedications,
    pastSurgeries,
    bloodType,
    previousDiagnoses,
    doctorNotes,
    nurseNotes,
    additionalNotes,
    diseases,
    allergiesList,
    allergiesDetails
  } = req.body;

  if (!patientUserId || !dateOfBirth || !gender) {
    return res.status(400).json({ error: 'patientUserId, dateOfBirth and gender are required' });
  }

  try {
    const hasPastSurgeries = await hasColumn('medicalrecord', 'pastSurgeries');
    const hasBloodType = await hasColumn('medicalrecord', 'bloodType');
    const hasPreviousDiagnoses = await hasColumn('medicalrecord', 'previousDiagnoses');
    const hasDoctorNotes = await hasColumn('medicalrecord', 'doctorNotes');
    const hasNurseNotes = await hasColumn('medicalrecord', 'nurseNotes');

    const normalizedDiseases = normalizeDiseasePayload(diseases);
    const normalizedAllergies = normalizeAllergyPayload(
      allergiesList ?? allergiesDetails
    );
    const diseasesProvided = Object.prototype.hasOwnProperty.call(req.body, 'diseases');
    const allergiesProvided =
      Object.prototype.hasOwnProperty.call(req.body, 'allergiesList') ||
      Object.prototype.hasOwnProperty.call(req.body, 'allergiesDetails');

    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      const setParts = [
        'dateOfBirth = ?',
        'gender = ?',
        'previousConditions = ?',
        'chronicConditions = ?',
        'allergies = ?',
        'currentMedications = ?'
      ];

      const updateValues = [
        dateOfBirth,
        gender,
        previousConditions ?? '',
        chronicConditions ?? '',
        allergies ?? '',
        currentMedications ?? ''
      ];

      if (hasPastSurgeries) {
        setParts.push('pastSurgeries = ?');
        updateValues.push(pastSurgeries ?? '');
      }
      if (hasBloodType) {
        setParts.push('bloodType = ?');
        updateValues.push(bloodType ?? '');
      }
      if (hasPreviousDiagnoses) {
        setParts.push('previousDiagnoses = ?');
        updateValues.push(previousDiagnoses ?? '');
      }
      if (hasDoctorNotes) {
        setParts.push('doctorNotes = ?');
        updateValues.push(doctorNotes ?? '');
      }
      if (hasNurseNotes) {
        setParts.push('nurseNotes = ?');
        updateValues.push(nurseNotes ?? '');
      }

      setParts.push('additionalNotes = ?', 'updatedAt = NOW()');
      updateValues.push(additionalNotes ?? '');

      const [result] = await connection.execute(
        `UPDATE medicalrecord
         SET ${setParts.join(', ')}
         WHERE recordId = ? AND patientUserId = ?`,
        [...updateValues, recordId, patientUserId]
      );

      if (!result.affectedRows) {
        await connection.rollback();
        return res.status(404).json({ error: 'Medical record not found' });
      }

      if (diseasesProvided) {
        await replaceMedicalRecordDiseases(connection, recordId, normalizedDiseases);
      }
      if (allergiesProvided) {
        await replaceMedicalRecordAllergies(connection, recordId, normalizedAllergies);
      }

      await connection.commit();
    } catch (e) {
      await connection.rollback();
      throw e;
    } finally {
      connection.release();
    }

    res.json({ message: 'Medical record updated successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/medical-record-lookups/diseases', async (_req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT diseaseId, diseaseName, icdCode, diseaseCategory
       FROM disease
       ORDER BY diseaseName ASC`
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/medical-record-lookups/allergies', async (_req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT allergyId, allergyName, allergyCategory
       FROM allergy
       ORDER BY allergyName ASC`
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/appointments/check-duplicate', async (req, res) => {
  try {
    const { patientId, providerId, serviceType, date, time } = req.query;
    if (!patientId || !providerId || !date || !time) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    const scheduledAt = normalizeDateTime(date, time);
    if (!scheduledAt) {
      return res.status(400).json({ error: 'Invalid date or time' });
    }

    const [rows] = await db.query(
      `SELECT requestId
       FROM servicerequest
       WHERE patientUserId = ?
         AND providerUserId = ?
         AND LOWER(TRIM(serviceType)) = LOWER(TRIM(?))
         AND scheduledAt = ?
         AND LOWER(TRIM(CAST(status AS CHAR(64)))) IN
           ('pending_provider_approval', 'pending', 'pending_payment', 'payment_pending', 'confirmed')
       LIMIT 1`,
      [patientId, providerId, (serviceType || 'appointment').toString(), scheduledAt]
    );

    res.json({ exists: rows.length > 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/appointments/upcoming/:patientUserId', async (req, res) => {
  const { patientUserId } = req.params;

  scheduleDbg('endpoint', {
    route: '/patient/appointments/upcoming/:patientUserId',
    patientUserId,
  });

  try {
    const hasVisitLatitude = await hasColumn('servicerequest', 'visitLatitude');
    const hasVisitLongitude = await hasColumn('servicerequest', 'visitLongitude');
    const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');
    const hasLocationNote = await hasColumn('servicerequest', 'locationNote');
    const hasSymptoms = await hasColumn('servicerequest', 'symptoms');
    const hasIsUrgent = await hasColumn('servicerequest', 'isUrgent');
    const hasAdditionalNotes = await hasColumn('servicerequest', 'additionalNotes');
    const hasPaymentMethod = await hasColumn('servicerequest', 'paymentMethod');
    const hasPaymentStatus = await hasColumn('servicerequest', 'paymentStatus');
    const hasCompletedAt = await hasColumn('servicerequest', 'completedAt');
    const hasProfileImageUrl = await hasColumn('user', 'profileImageUrl');
    const { ratingSelect, ratingJoin } = await appointmentRatingSqlFragments();

    const [rows] = await db.query(
      `SELECT
          sr.requestId AS appointmentId,
          sr.patientUserId,
          sr.serviceType,
          sr.status,
          sr.location,
          sr.notes,
          ${hasVisitLatitude ? 'sr.visitLatitude' : 'NULL AS visitLatitude'},
          ${hasVisitLongitude ? 'sr.visitLongitude' : 'NULL AS visitLongitude'},
          ${hasVisitAddress ? 'sr.visitAddress' : "'' AS visitAddress"},
          ${hasLocationNote ? 'sr.locationNote' : "'' AS locationNote"},
          ${hasSymptoms ? 'sr.symptoms' : "'' AS symptoms"},
          ${hasIsUrgent ? 'sr.isUrgent' : '0 AS isUrgent'},
          ${hasAdditionalNotes ? 'sr.additionalNotes' : "'' AS additionalNotes"},
          ${hasPaymentMethod ? 'sr.paymentMethod' : "'' AS paymentMethod"},
          ${hasPaymentStatus ? 'sr.paymentStatus' : "'' AS paymentStatus"},
          ${hasCompletedAt ? 'sr.completedAt' : 'NULL AS completedAt'},
          sr.scheduledAt,
          sr.providerUserId AS doctorUserId,
          u.fullName AS doctorName,
          u.role AS providerRole,
          ${hasProfileImageUrl ? 'u.profileImageUrl' : 'NULL AS profileImageUrl'},
          c.specialization,
          ${ratingSelect}
       FROM servicerequest sr
       ${ratingJoin}
       LEFT JOIN user u ON sr.providerUserId = u.userId
       LEFT JOIN careprovider c ON u.userId = c.userId
       WHERE TRIM(sr.patientUserId) = TRIM(?)
         AND ${normStatusSql} IN
           ('pending_provider_approval', 'pending', 'pending_payment', 'payment_pending', 'confirmed')
       ORDER BY sr.scheduledAt ASC`,
      [patientUserId]
    );

    scheduleDbg('upcoming result', {
      patientUserId,
      rowCount: rows.length,
      sampleStatuses: rows.slice(0, 5).map((r) => r.status),
    });

    res.json(rows);
  } catch (err) {
    scheduleDbg('upcoming error', { patientUserId, message: err.message });
    res.status(500).json({ error: err.message });
  }
});

router.get('/appointments/history/:patientUserId', async (req, res) => {
  const { patientUserId } = req.params;

  scheduleDbg('endpoint', {
    route: '/patient/appointments/history/:patientUserId',
    patientUserId,
  });

  try {
    const hasVisitLatitude = await hasColumn('servicerequest', 'visitLatitude');
    const hasVisitLongitude = await hasColumn('servicerequest', 'visitLongitude');
    const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');
    const hasLocationNote = await hasColumn('servicerequest', 'locationNote');
    const hasSymptoms = await hasColumn('servicerequest', 'symptoms');
    const hasIsUrgent = await hasColumn('servicerequest', 'isUrgent');
    const hasAdditionalNotes = await hasColumn('servicerequest', 'additionalNotes');
    const hasPaymentMethod = await hasColumn('servicerequest', 'paymentMethod');
    const hasPaymentStatus = await hasColumn('servicerequest', 'paymentStatus');
    const hasCompletedAt = await hasColumn('servicerequest', 'completedAt');
    const hasProfileImageUrl = await hasColumn('user', 'profileImageUrl');
    const { ratingSelect, ratingJoin } = await appointmentRatingSqlFragments();

    const [rows] = await db.query(
      `SELECT
          sr.requestId AS appointmentId,
          sr.patientUserId,
          sr.serviceType,
          sr.status,
          sr.location,
          sr.notes,
          ${hasVisitLatitude ? 'sr.visitLatitude' : 'NULL AS visitLatitude'},
          ${hasVisitLongitude ? 'sr.visitLongitude' : 'NULL AS visitLongitude'},
          ${hasVisitAddress ? 'sr.visitAddress' : "'' AS visitAddress"},
          ${hasLocationNote ? 'sr.locationNote' : "'' AS locationNote"},
          ${hasSymptoms ? 'sr.symptoms' : "'' AS symptoms"},
          ${hasIsUrgent ? 'sr.isUrgent' : '0 AS isUrgent'},
          ${hasAdditionalNotes ? 'sr.additionalNotes' : "'' AS additionalNotes"},
          ${hasPaymentMethod ? 'sr.paymentMethod' : "'' AS paymentMethod"},
          ${hasPaymentStatus ? 'sr.paymentStatus' : "'' AS paymentStatus"},
          ${hasCompletedAt ? 'sr.completedAt' : 'NULL AS completedAt'},
          sr.scheduledAt,
          sr.providerUserId AS doctorUserId,
          u.fullName AS doctorName,
          u.role AS providerRole,
          ${hasProfileImageUrl ? 'u.profileImageUrl' : 'NULL AS profileImageUrl'},
          c.specialization,
          ${ratingSelect}
       FROM servicerequest sr
       ${ratingJoin}
       LEFT JOIN user u ON sr.providerUserId = u.userId
       LEFT JOIN careprovider c ON u.userId = c.userId
       WHERE TRIM(sr.patientUserId) = TRIM(?)
         AND ${normStatusSql} IN ('completed', 'cancelled', 'canceled')
       ORDER BY COALESCE(sr.completedAt, sr.scheduledAt) DESC, sr.scheduledAt DESC`,
      [patientUserId]
    );

    const completedCt = rows.filter(
      (r) => `${r.status ?? ''}`.toLowerCase().trim() === 'completed',
    ).length;
    scheduleDbg('history result', {
      patientUserId,
      rowCount: rows.length,
      completedCount: completedCt,
      statuses: rows.map((r) => r.status),
    });

    res.json(rows);
  } catch (err) {
    scheduleDbg('history error', { patientUserId, message: err.message });
    res.status(500).json({ error: err.message });
  }
});

router.get('/appointments/:patientUserId', async (req, res) => {
  const { patientUserId } = req.params;
  const status = req.query.status ? req.query.status.toString().toLowerCase().trim() : null;
  const isValidStatus = status && BOOKING_STATUSES.includes(status);

  scheduleDbg('endpoint', {
    route: '/patient/appointments/:patientUserId',
    patientUserId,
    queryStatus: status || null,
  });

  try {
    const hasVisitLatitude = await hasColumn('servicerequest', 'visitLatitude');
    const hasVisitLongitude = await hasColumn('servicerequest', 'visitLongitude');
    const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');
    const hasLocationNote = await hasColumn('servicerequest', 'locationNote');
    const hasSymptoms = await hasColumn('servicerequest', 'symptoms');
    const hasIsUrgent = await hasColumn('servicerequest', 'isUrgent');
    const hasAdditionalNotes = await hasColumn('servicerequest', 'additionalNotes');
    const hasPaymentMethod = await hasColumn('servicerequest', 'paymentMethod');
    const hasPaymentStatus = await hasColumn('servicerequest', 'paymentStatus');
    const hasCompletedAt = await hasColumn('servicerequest', 'completedAt');
    const hasProfileImageUrl = await hasColumn('user', 'profileImageUrl');
    const { ratingSelect, ratingJoin } = await appointmentRatingSqlFragments();

    const params = [patientUserId];
    let whereStatus = '';
    if (isValidStatus) {
      whereStatus = ` AND ${normStatusSql} = ?`;
      params.push(status);
    }

    const [rows] = await db.query(
      `SELECT
          sr.requestId AS appointmentId,
          sr.patientUserId,
          sr.serviceType,
          sr.status,
          sr.location,
          sr.notes,
          ${hasVisitLatitude ? 'sr.visitLatitude' : 'NULL AS visitLatitude'},
          ${hasVisitLongitude ? 'sr.visitLongitude' : 'NULL AS visitLongitude'},
          ${hasVisitAddress ? 'sr.visitAddress' : "'' AS visitAddress"},
          ${hasLocationNote ? 'sr.locationNote' : "'' AS locationNote"},
          ${hasSymptoms ? 'sr.symptoms' : "'' AS symptoms"},
          ${hasIsUrgent ? 'sr.isUrgent' : '0 AS isUrgent'},
          ${hasAdditionalNotes ? 'sr.additionalNotes' : "'' AS additionalNotes"},
          ${hasPaymentMethod ? 'sr.paymentMethod' : "'' AS paymentMethod"},
          ${hasPaymentStatus ? 'sr.paymentStatus' : "'' AS paymentStatus"},
          ${hasCompletedAt ? 'sr.completedAt' : 'NULL AS completedAt'},
          sr.scheduledAt,
          sr.providerUserId AS doctorUserId,
          u.fullName AS doctorName,
          u.role AS providerRole,
          ${hasProfileImageUrl ? 'u.profileImageUrl' : 'NULL AS profileImageUrl'},
          c.specialization,
          ${ratingSelect}
       FROM servicerequest sr
       ${ratingJoin}
       LEFT JOIN user u ON sr.providerUserId = u.userId
       LEFT JOIN careprovider c ON u.userId = c.userId
       WHERE TRIM(sr.patientUserId) = TRIM(?)
         AND ${normStatusSql} <> 'draft'${whereStatus}
       ORDER BY COALESCE(sr.completedAt, sr.scheduledAt) DESC, sr.scheduledAt DESC`,
      params
    );

    const completedCt = rows.filter(
      (r) => `${r.status ?? ''}`.toLowerCase().trim() === 'completed',
    ).length;
    scheduleDbg('appointments list result', {
      patientUserId,
      rowCount: rows.length,
      completedCount: completedCt,
      queryStatus: status || 'all',
    });

    res.json(rows);
  } catch (err) {
    scheduleDbg('appointments list error', { patientUserId, message: err.message });
    res.status(500).json({ error: err.message });
  }
});

router.get('/appointments/details/:appointmentId', async (req, res) => {
  const { appointmentId } = req.params;

  try {
    const hasVisitLatitude = await hasColumn('servicerequest', 'visitLatitude');
    const hasVisitLongitude = await hasColumn('servicerequest', 'visitLongitude');
    const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');
    const hasLocationNote = await hasColumn('servicerequest', 'locationNote');
    const hasSymptoms = await hasColumn('servicerequest', 'symptoms');
    const hasIsUrgent = await hasColumn('servicerequest', 'isUrgent');
    const hasAdditionalNotes = await hasColumn('servicerequest', 'additionalNotes');
    const hasPaymentMethod = await hasColumn('servicerequest', 'paymentMethod');
    const hasPaymentStatus = await hasColumn('servicerequest', 'paymentStatus');
    const hasProviderCurrentLat = await hasColumn('servicerequest', 'providerCurrentLat');
    const hasProviderCurrentLng = await hasColumn('servicerequest', 'providerCurrentLng');
    const hasProviderLocationUpdatedAt = await hasColumn(
      'servicerequest',
      'providerLocationUpdatedAt'
    );
    const hasCompletedAt = await hasColumn('servicerequest', 'completedAt');

    const { ratingSelect, ratingJoin } = await appointmentRatingSqlFragments();

    const [rows] = await db.query(
      `SELECT
          sr.requestId AS appointmentId,
          sr.patientUserId,
          sr.providerUserId,
          sr.serviceType,
          sr.status,
          sr.location,
          sr.notes,
          ${hasVisitLatitude ? 'sr.visitLatitude' : 'NULL AS visitLatitude'},
          ${hasVisitLongitude ? 'sr.visitLongitude' : 'NULL AS visitLongitude'},
          ${hasVisitAddress ? 'sr.visitAddress' : "'' AS visitAddress"},
          ${hasLocationNote ? 'sr.locationNote' : "'' AS locationNote"},
          ${hasSymptoms ? 'sr.symptoms' : "'' AS symptoms"},
          ${hasIsUrgent ? 'sr.isUrgent' : '0 AS isUrgent'},
          ${hasAdditionalNotes ? 'sr.additionalNotes' : "'' AS additionalNotes"},
          ${hasPaymentMethod ? 'sr.paymentMethod' : "'' AS paymentMethod"},
          ${hasPaymentStatus ? 'sr.paymentStatus' : "'' AS paymentStatus"},
          ${hasProviderCurrentLat ? 'sr.providerCurrentLat' : 'NULL AS providerCurrentLat'},
          ${hasProviderCurrentLng ? 'sr.providerCurrentLng' : 'NULL AS providerCurrentLng'},
          ${
            hasProviderLocationUpdatedAt
              ? 'sr.providerLocationUpdatedAt'
              : 'NULL AS providerLocationUpdatedAt'
          },
          ${hasCompletedAt ? 'sr.completedAt' : 'NULL AS completedAt'},
          sr.scheduledAt,
          pu.fullName AS patientName,
          pr.fullName AS providerName,
          pr.role AS providerRole,
          c.specialization,
          ${ratingSelect}
       FROM servicerequest sr
       ${ratingJoin}
       LEFT JOIN user pu ON sr.patientUserId = pu.userId
       LEFT JOIN user pr ON sr.providerUserId = pr.userId
       LEFT JOIN careprovider c ON sr.providerUserId = c.userId
       WHERE sr.requestId = ?`,
      [appointmentId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/appointments/:appointmentId/rate', async (req, res) => {
  const { appointmentId } = req.params;
  const { patientUserId, stars, comment } = req.body;

  try {
    const result = await visitRatingService.submitPatientVisitRating({
      appointmentId,
      patientUserId,
      stars,
      comment,
    });
    res.status(201).json(result);
  } catch (err) {
    const code = err.status || 500;
    res.status(code).json({ error: err.message });
  }
});

router.post('/appointments', async (req, res) => {
  const {
    patientUserId,
    doctorUserId,
    providerUserId,
    appointmentDate,
    date,
    appointmentTime,
    time,
    location,
    status,
    notes,
    visitLatitude,
    visitLongitude,
    visitAddress,
    locationNote,
    symptoms,
    isUrgent,
    additionalNotes,
    paymentMethod,
    paymentStatus,
    serviceType: bookingServiceType,
    urgencyLevel,
  } = req.body;

  const finalServiceType = (bookingServiceType ?? 'appointment')
    .toString()
    .trim()
    || 'appointment';
  const normalizedUrgency = (urgencyLevel ?? (isUrgent ? 'urgent' : 'routine'))
    .toString()
    .trim()
    .toLowerCase();

  const finalDoctorUserId = doctorUserId || providerUserId;
  const finalDate = appointmentDate || date;
  const finalTime = appointmentTime || time;

  if (!patientUserId || patientUserId === 'guest' || !finalDoctorUserId || !finalDate || !finalTime) {
    return res.status(400).json({
      error: 'patientUserId, doctor/provider userId, date and time are required'
    });
  }

  try {
    const [patientUserCheck] = await db.query(
      'SELECT userId, role FROM user WHERE userId = ?',
      [patientUserId]
    );
    if (patientUserCheck.length === 0) {
      return res.status(400).json({
        error: 'Invalid patientUserId. User does not exist.'
      });
    }
    if ((patientUserCheck[0].role || '').toString().trim().toLowerCase() !== 'patient') {
      return res.status(403).json({
        error: 'The booking patientUserId must belong to a patient account.'
      });
    }

    const [providerUserCheck] = await db.query(
      `SELECT u.userId
       FROM user u
       INNER JOIN careprovider c ON c.userId = u.userId
       WHERE u.userId = ?
       LIMIT 1`,
      [finalDoctorUserId]
    );
    if (providerUserCheck.length === 0) {
      return res.status(400).json({
        error: 'Invalid providerUserId. Care provider does not exist.'
      });
    }
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }

  const scheduledAt = normalizeDateTime(finalDate, finalTime);
  if (!scheduledAt) {
    return res.status(400).json({ error: 'Invalid appointment date or time' });
  }

  try {
    const hasVisitLatitude = await hasColumn('servicerequest', 'visitLatitude');
    const hasVisitLongitude = await hasColumn('servicerequest', 'visitLongitude');
    const hasVisitAddress = await hasColumn('servicerequest', 'visitAddress');
    const hasLocationNote = await hasColumn('servicerequest', 'locationNote');
    const hasSymptoms = await hasColumn('servicerequest', 'symptoms');
    const hasIsUrgent = await hasColumn('servicerequest', 'isUrgent');
    const hasAdditionalNotes = await hasColumn('servicerequest', 'additionalNotes');
    const hasPaymentMethod = await hasColumn('servicerequest', 'paymentMethod');
    const hasPaymentStatus = await hasColumn('servicerequest', 'paymentStatus');

    const hasUrgencyLevel = await hasColumn('servicerequest', 'urgencyLevel');

    const [availableSlots] = await db.query(
      `SELECT 1
       FROM availabilityslot
       WHERE providerUserId = ?
         AND LOWER(TRIM(day)) = LOWER(DAYNAME(?))
         AND TIME(startTime) = TIME(?)
       LIMIT 1`,
      [finalDoctorUserId, scheduledAt, finalTime]
    );
    if (availableSlots.length === 0) {
      return res.status(409).json({
        error: 'This appointment time is no longer available.'
      });
    }

    const [providerConflicts] = await db.query(
      `SELECT requestId
       FROM servicerequest
       WHERE providerUserId = ?
         AND scheduledAt = ?
         AND LOWER(TRIM(CAST(status AS CHAR(64)))) IN
           ('confirmed', 'accepted', 'approved', 'scheduled', 'in_progress')
       LIMIT 1`,
      [finalDoctorUserId, scheduledAt]
    );
    if (providerConflicts.length > 0) {
      return res.status(409).json({
        error: 'This appointment time was already booked.'
      });
    }

    const [conflicts] = await db.query(
      `SELECT requestId
       FROM servicerequest
       WHERE patientUserId = ?
         AND providerUserId = ?
         AND serviceType = ?
         AND scheduledAt = ?
         AND LOWER(TRIM(CAST(status AS CHAR(64)))) IN
           ('pending_provider_approval', 'pending', 'pending_payment', 'payment_pending', 'confirmed')`,
      [patientUserId, finalDoctorUserId, finalServiceType, scheduledAt]
    );

    if (conflicts.length > 0) {
      return res.status(409).json({
        error: 'You already have a pending/confirmed appointment at this time.'
      });
    }

    const requestId = randomUUID();
    const requestLocation = (
      location ||
      visitAddress ||
      locationNote ||
      ''
    ).toString().trim();
    const requestedStatus = (status || '').toString().trim().toLowerCase();
    const finalStatus = ['draft', 'pending_provider_approval'].includes(requestedStatus) ? requestedStatus : 'pending';
    const parsedVisitLat = visitLatitude == null || visitLatitude === ''
      ? null
      : Number(visitLatitude);
    const parsedVisitLng = visitLongitude == null || visitLongitude === ''
      ? null
      : Number(visitLongitude);
    const normalizedPaymentMethod = paymentMethod
      ? paymentMethod.toString().trim().toLowerCase()
      : '';
    const normalizedPaymentStatus = 'unpaid';

    const columns = [
      'requestId',
      'serviceType',
      'status',
      'location',
      'notes',
      'scheduledAt',
      'patientUserId',
      'providerUserId'
    ];
    const values = [
      requestId,
      finalServiceType,
      finalStatus,
      requestLocation,
      notes ?? '',
      scheduledAt,
      patientUserId,
      finalDoctorUserId
    ];

    if (hasVisitLatitude) {
      columns.push('visitLatitude');
      values.push(Number.isFinite(parsedVisitLat) ? parsedVisitLat : null);
    }
    if (hasVisitLongitude) {
      columns.push('visitLongitude');
      values.push(Number.isFinite(parsedVisitLng) ? parsedVisitLng : null);
    }
    if (hasVisitAddress) {
      columns.push('visitAddress');
      values.push((visitAddress ?? '').toString().trim());
    }
    if (hasLocationNote) {
      columns.push('locationNote');
      values.push((locationNote ?? '').toString().trim());
    }
    if (hasSymptoms) {
      columns.push('symptoms');
      values.push((symptoms ?? '').toString().trim());
    }
    if (hasIsUrgent) {
      columns.push('isUrgent');
      values.push(isUrgent ? 1 : 0);
    }
    if (hasAdditionalNotes) {
      columns.push('additionalNotes');
      values.push((additionalNotes ?? '').toString().trim());
    }
    if (hasPaymentMethod) {
      columns.push('paymentMethod');
      values.push(normalizedPaymentMethod);
    }
    if (hasPaymentStatus) {
      columns.push('paymentStatus');
      values.push(normalizedPaymentStatus);
    }
    if (hasUrgencyLevel) {
      columns.push('urgencyLevel');
      values.push(normalizedUrgency);
    }
    await db.execute(
      `INSERT INTO servicerequest (${columns.join(', ')})
       VALUES (${columns.map(() => '?').join(', ')})`,
      values
    );

    if (finalStatus !== 'draft') {
      try {
      const [patientRows] = await db.query(
        'SELECT fullName FROM user WHERE userId = ?',
        [patientUserId]
      );
      const patientName = patientRows.length > 0
        ? patientRows[0].fullName.toString().trim()
        : 'المريض';
      const appointmentText = `${finalDate} ${finalTime}`;
      const providerPatientName =
        patientRows.length > 0 && patientRows[0].fullName.toString().trim()
          ? patientRows[0].fullName.toString().trim()
          : 'Patient';
      const patientBookingTitle = 'Booking request sent';
      const patientBookingBody =
        `Your booking request for ${appointmentText} was sent to the care provider.`;
      const providerBookingTitle = 'New booking request';
      const providerBookingBody =
        `${providerPatientName} booked ${finalServiceType} at ${appointmentText}. Review service requests to accept or decline.`;

      await insertNotification({
        userId: patientUserId,
        type: 'appointment',
        title: 'تم إرسال طلب الحجز',
        body: `طلبك للحجز في ${appointmentText} تم إرساله، وسيتابع مقدم الخدمة الرد عليه.`,
        relatedRequestId: requestId
      });
      await insertNotification({
        userId: finalDoctorUserId,
        type: 'appointment',
        title: 'طلب موعد جديد',
        body: `المريض ${patientName} حجز موعدًا في ${appointmentText}. راجع قسم طلبات الخدمة لتأكيد أو رفض الموعد.`,
        relatedRequestId: requestId
      });
      await db.execute(
        `UPDATE usernotification SET title = ?, body = ?
         WHERE relatedRequestId = ? AND userId = ?`,
        [patientBookingTitle, patientBookingBody, requestId, patientUserId]
      );
      await db.execute(
        `UPDATE usernotification SET title = ?, body = ?
         WHERE relatedRequestId = ? AND userId = ?`,
        [providerBookingTitle, providerBookingBody, requestId, finalDoctorUserId]
      );
    } catch (_) {
      // usernotification table may not be migrated yet
    }
    }

    res.status(201).json({
      message: 'Appointment created successfully',
      appointmentId: requestId,
      status: finalStatus
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// Final booking transition. New clients submit a paid hidden draft. The
// temporary `pending` allowance recovers rows created by older deployments
// that ignored the requested draft status before opening checkout.
router.post('/appointments/:appointmentId/submit', async (req, res) => {
  const { appointmentId } = req.params;
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [rows] = await connection.query(
      `SELECT sr.patientUserId, sr.providerUserId, sr.scheduledAt, sr.serviceType,
              sr.status,
              p.paymentId, p.paymentStatus, p.transactionId
       FROM servicerequest sr
       LEFT JOIN payment p ON p.requestId = sr.requestId
       WHERE sr.requestId = ?
       FOR UPDATE`,
      [appointmentId]
    );
    if (rows.length === 0) {
      await connection.rollback();
      return res.status(404).json({ error: 'Draft appointment not found' });
    }

    const appt = rows[0];
    const currentStatus = (appt.status || '').toString().trim().toLowerCase();
    if (
      currentStatus === 'pending_provider_approval' &&
      (appt.paymentStatus || '').toString().trim().toLowerCase() === 'paid'
    ) {
      await connection.commit();
      return res.json({
        success: true,
        alreadySubmitted: true,
        appointmentId,
        status: 'pending_provider_approval',
        paymentId: appt.paymentId,
        paymentReference: appt.transactionId || appt.paymentId
      });
    }
    const canSubmitPaidBooking =
      currentStatus === 'draft' || currentStatus === 'pending';
    if (!canSubmitPaidBooking) {
      await connection.rollback();
      return res.status(409).json({
        error: 'Only a paid booking draft can be submitted.'
      });
    }
    if ((appt.paymentStatus || '').toString().trim().toLowerCase() !== 'paid') {
      await connection.rollback();
      return res.status(409).json({
        error: 'Payment must be completed before submitting the booking request.'
      });
    }

    const [duplicates] = await connection.query(
      `SELECT requestId
       FROM servicerequest
       WHERE requestId <> ?
         AND patientUserId = ?
         AND providerUserId = ?
         AND LOWER(TRIM(serviceType)) = LOWER(TRIM(?))
         AND scheduledAt = ?
         AND LOWER(TRIM(CAST(status AS CHAR(64)))) IN
           ('pending_provider_approval', 'pending', 'pending_payment', 'payment_pending', 'confirmed')
       LIMIT 1
       FOR UPDATE`,
      [
        appointmentId,
        appt.patientUserId,
        appt.providerUserId,
        appt.serviceType,
        appt.scheduledAt
      ]
    );
    if (duplicates.length > 0) {
      await connection.rollback();
      return res.status(409).json({
        error: 'A booking request already exists for this patient and appointment.'
      });
    }

    const [providerConflicts] = await connection.query(
      `SELECT requestId
       FROM servicerequest
       WHERE requestId <> ?
         AND providerUserId = ?
         AND scheduledAt = ?
         AND LOWER(TRIM(CAST(status AS CHAR(64)))) IN
           ('confirmed', 'accepted', 'approved', 'scheduled', 'in_progress')
       LIMIT 1
       FOR UPDATE`,
      [appointmentId, appt.providerUserId, appt.scheduledAt]
    );
    if (providerConflicts.length > 0) {
      await connection.rollback();
      return res.status(409).json({
        error: 'This appointment time is no longer available.'
      });
    }

    await connection.execute(
      `UPDATE servicerequest SET status = 'pending_provider_approval' WHERE requestId = ?`,
      [appointmentId]
    );
    await connection.commit();

    try {
      const [patientRows] = await db.query(
        'SELECT fullName FROM user WHERE userId = ?',
        [appt.patientUserId]
      );
      const patientName = patientRows.length > 0
        ? patientRows[0].fullName.toString().trim()
        : 'المريض';

      const appointmentText = appt.scheduledAt;
      const providerPatientName =
        patientRows.length > 0 && patientRows[0].fullName.toString().trim()
          ? patientRows[0].fullName.toString().trim()
          : 'Patient';

      const patientBookingTitle = 'Booking request sent';
      const patientBookingBody =
        `Your booking request for ${appointmentText} was sent to the care provider.`;
      const providerBookingTitle = 'New booking request';
      const providerBookingBody =
        `${providerPatientName} booked ${appt.serviceType} at ${appointmentText}. Review service requests to accept or decline.`;

      await insertNotification({
        userId: appt.patientUserId,
        type: 'appointment',
        title: 'تم إرسال طلب الحجز',
        body: `طلبك للحجز في ${appointmentText} تم إرساله، وسيتابع مقدم الخدمة الرد عليه.`,
        relatedRequestId: appointmentId
      });
      await insertNotification({
        userId: appt.providerUserId,
        type: 'appointment',
        title: 'طلب موعد جديد',
        body: `المريض ${patientName} حجز موعدًا في ${appointmentText}. راجع قسم طلبات الخدمة لتأكيد أو رفض الموعد.`,
        relatedRequestId: appointmentId
      });
      await db.execute(
        `UPDATE usernotification SET title = ?, body = ?
         WHERE relatedRequestId = ? AND userId = ?`,
        [patientBookingTitle, patientBookingBody, appointmentId, appt.patientUserId]
      );
      await db.execute(
        `UPDATE usernotification SET title = ?, body = ?
         WHERE relatedRequestId = ? AND userId = ?`,
        [providerBookingTitle, providerBookingBody, appointmentId, appt.providerUserId]
      );
    } catch (_) {}

    res.json({
      success: true,
      appointmentId,
      status: 'pending_provider_approval',
      paymentId: appt.paymentId,
      paymentReference: appt.transactionId || appt.paymentId
    });
  } catch (err) {
    try {
      await connection.rollback();
    } catch (_) {}
    res.status(500).json({ error: err.message });
  } finally {
    connection.release();
  }
});

router.delete('/appointments/:appointmentId', async (req, res) => {
  const { appointmentId } = req.params;
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [rows] = await connection.query(
      `SELECT sr.requestId, p.paymentStatus
       FROM servicerequest sr
       LEFT JOIN payment p ON p.requestId = sr.requestId
       WHERE sr.requestId = ? AND sr.status = 'draft'
       FOR UPDATE`,
      [appointmentId]
    );
    if (rows.length > 0) {
      const paid =
        (rows[0].paymentStatus || '').toString().trim().toLowerCase() === 'paid';
      if (!paid) {
        await connection.execute(
          'DELETE FROM payment WHERE requestId = ?',
          [appointmentId]
        );
        await connection.execute(
          `DELETE FROM servicerequest WHERE requestId = ? AND status = 'draft'`,
          [appointmentId]
        );
      }
    }
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    try {
      await connection.rollback();
    } catch (_) {}
    res.status(500).json({ error: err.message });
  } finally {
    connection.release();
  }
});

router.put('/appointments/:appointmentId/cancel', async (req, res) => {
  const { appointmentId } = req.params;
  const { patientUserId, reason } = req.body;

  if (!patientUserId) {
    return res.status(400).json({ error: 'patientUserId is required' });
  }

  try {
    const [rows] = await db.query(
      `SELECT requestId, status
       FROM servicerequest
       WHERE requestId = ? AND patientUserId = ?`,
      [appointmentId, patientUserId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    const current = rows[0];
    if (!['pending', 'pending_payment', 'payment_pending', 'confirmed'].includes(current.status)) {
      return res.status(409).json({
        error: 'Only active appointments can be cancelled'
      });
    }

    await db.execute(
      `UPDATE servicerequest
       SET status = 'cancelled',
           notes = CONCAT(COALESCE(notes, ''), ?)
       WHERE requestId = ?`,
      [reason ? `\nCancelled: ${reason}` : '\nCancelled by patient', appointmentId]
    );

    res.json({ message: 'Appointment cancelled successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
router.put('/appointments/:appointmentId/change-provider', async (req, res) => {
  const { appointmentId } = req.params;
  const { patientUserId, newProviderId, reason } = req.body;

  if (!patientUserId || !newProviderId) {
    return res.status(400).json({ error: 'patientUserId and newProviderId are required' });
  }

  try {
    const [rows] = await db.query(
      `SELECT requestId, status, providerUserId, scheduledAt, serviceType
       FROM servicerequest
       WHERE requestId = ? AND patientUserId = ?`,
      [appointmentId, patientUserId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    const current = rows[0];
    const allowedStatuses = [
      'pending',
      'pending_payment',
      'payment_pending',
      'confirmed',
      'scheduled',
      'accepted',
    ];
    if (!allowedStatuses.includes(current.status)) {
      return res.status(409).json({
        error: 'Only active future appointments can have their provider changed'
      });
    }

    if (current.scheduledAt) {
      const now = new Date();
      const scheduledDate = new Date(current.scheduledAt);
      if (scheduledDate < now) {
        return res.status(409).json({ error: 'Cannot change provider for past appointments' });
      }
      
      const hoursDifference = (scheduledDate.getTime() - now.getTime()) / (1000 * 60 * 60);
      if (hoursDifference < 2) {
        return res.status(409).json({ error: 'Provider change is not available close to the appointment time (within 2 hours).' });
      }
    }

    if (current.providerUserId === newProviderId) {
      return res.status(400).json({ error: 'New provider must be different from current provider' });
    }

    // Check if new provider exists
    const [providerRows] = await db.query(
      `SELECT userId, serviceType FROM careprovider WHERE userId = ?`,
      [newProviderId]
    );

    if (providerRows.length === 0) {
      return res.status(404).json({ error: 'New provider not found' });
    }

    const changeId = randomUUID();
    const oldProviderId = current.providerUserId;

    // Track the change
    await db.execute(
      `INSERT INTO providerchange (change_id, reason, requestId, oldProviderId, newProviderId)
       VALUES (?, ?, ?, ?, ?)`,
      [changeId, reason || null, appointmentId, oldProviderId, newProviderId]
    );

    // Update appointment
    await db.execute(
      `UPDATE servicerequest
       SET providerUserId = ?, status = 'pending',
           notes = CONCAT(COALESCE(notes, ''), ?)
       WHERE requestId = ?`,
      [
        newProviderId,
        reason ? `\nProvider changed: ${reason}` : '\nProvider changed by patient',
        appointmentId
      ]
    );

    // Notify old provider
    try {
      await insertNotification({
        userId: oldProviderId,
        type: 'appointment_change',
        title: 'تم تغيير مقدم الخدمة',
        body: 'قام المريض بتغيير مقدم الخدمة لهذا الموعد.',
        relatedRequestId: appointmentId
      });
    } catch (_) {}

    // Notify new provider
    try {
      await insertNotification({
        userId: newProviderId,
        type: 'appointment',
        title: 'طلب موعد جديد',
        body: 'تم تحويل موعد إليك. يرجى مراجعة طلباتك.',
        relatedRequestId: appointmentId
      });
    } catch (_) {}

    // Notify patient
    try {
      await insertNotification({
        userId: patientUserId,
        type: 'appointment_change',
        title: 'تم تغيير مقدم الخدمة بنجاح',
        body: 'تم تحويل موعدك إلى مقدم خدمة جديد بنجاح.',
        relatedRequestId: appointmentId
      });
    } catch (_) {}

    res.json({ message: 'Provider changed successfully', changeId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/payments', async (req, res) => {
  try {
    const out =
      await bookingPaymentService.createLegacyPatientPayment(req.body);
    res.status(201).json(out);
  } catch (err) {
    const code = err.status || 500;
    res.status(code).json({ error: err.message });
  }
});

router.get('/payments/:patientUserId', async (req, res) => {
  const { patientUserId } = req.params;

  try {
    const rows = await bookingPaymentService.listPatientPayments(
      patientUserId,
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/chat/conversations/get-or-create', async (req, res) => {
  const patientId = normalizeChatId(req.body.patientId);
  const nurseId = normalizeChatId(req.body.nurseId || req.body.providerId);
  const requestId = normalizeChatId(req.body.requestId);
  const appointmentId = normalizeChatId(req.body.appointmentId || requestId);
  const visitId = normalizeChatId(req.body.visitId || requestId);

  if (!patientId || !nurseId || !requestId) {
    return res.status(400).json({
      error: 'patientId, nurseId and requestId are required',
    });
  }

  try {
    await ensureChatSchema();
    const [existing] = await db.query(
      `SELECT * FROM chatconversation
       WHERE nurseId = ? AND patientId = ? AND requestId = ?
       LIMIT 1`,
      [nurseId, patientId, requestId]
    );

    let conversation = existing[0];
    if (!conversation) {
      const conversationId = randomUUID();
      await db.query(
        `INSERT INTO chatconversation
         (conversationId, patientId, nurseId, requestId, appointmentId, visitId,
          createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())`,
        [conversationId, patientId, nurseId, requestId, appointmentId, visitId]
      );
      conversation = {
        conversationId,
        patientId,
        nurseId,
        requestId,
        appointmentId,
        visitId,
        createdAt: new Date(),
        updatedAt: new Date(),
        lastMessage: null,
        lastMessageAt: null,
        lastSenderId: null,
      };
    }

    const meta = await getConversationMeta(conversation);
    res.json({ ...conversation, patient: meta.patient, nurse: meta.nurse });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/chat/conversations', async (req, res) => {
  const userId = normalizeChatId(req.query.userId);
  if (!userId) return res.status(400).json({ error: 'userId is required' });

  try {
    await ensureChatSchema();
    const [rows] = await db.query(
      `SELECT
         c.*,
         patient.fullName AS patientName,
         nurse.fullName AS nurseName,
         (
           SELECT COUNT(*)
           FROM message m
           WHERE m.conversationId = c.conversationId
             AND m.receiverId = ?
             AND m.readAt IS NULL
         ) AS unreadCount
       FROM chatconversation c
       LEFT JOIN user patient ON patient.userId = c.patientId
       LEFT JOIN user nurse ON nurse.userId = c.nurseId
       WHERE c.patientId = ? OR c.nurseId = ?
       ORDER BY COALESCE(c.lastMessageAt, c.updatedAt) DESC`,
      [userId, userId, userId]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/chat/unread-count/:userId', async (req, res) => {
  const userId = normalizeChatId(req.params.userId);
  if (!userId) return res.status(400).json({ error: 'userId is required' });

  try {
    await ensureChatSchema();
    const [rows] = await db.query(
      `SELECT COUNT(*) AS unreadCount
       FROM message
       WHERE receiverId = ? AND readAt IS NULL`,
      [userId]
    );
    res.json({ unreadCount: Number(rows[0]?.unreadCount || 0) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/chat/conversations/:conversationId/messages', async (req, res) => {
  const { conversationId } = req.params;
  const viewerId = normalizeChatId(req.query.viewerId);
  const limit = Math.min(Math.max(Number(req.query.limit || 30), 1), 50);
  const before = normalizeChatId(req.query.before);

  if (!viewerId) return res.status(400).json({ error: 'viewerId is required' });

  try {
    await ensureChatSchema();
    const conversation = await getConversationForUser(conversationId, viewerId);
    if (!conversation) return res.status(403).json({ error: 'Forbidden' });

    await touchChatPresence(viewerId);
    await db.query(
      `UPDATE message
       SET deliveredAt = COALESCE(deliveredAt, NOW())
       WHERE conversationId = ? AND receiverId = ? AND deliveredAt IS NULL`,
      [conversationId, viewerId]
    );

    const params = [conversationId];
    let beforeSql = '';
    if (before) {
      beforeSql = 'AND createdAt < ?';
      params.push(before);
    }
    params.push(limit);

    const [rows] = await db.query(
      `SELECT * FROM (
         SELECT ${chatMessageSelect()}
         FROM message
         WHERE conversationId = ? ${beforeSql}
         ORDER BY createdAt DESC
         LIMIT ?
       ) latest
       ORDER BY createdAt ASC`,
      params
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/chat/conversations/:conversationId/messages', async (req, res) => {
  const { conversationId } = req.params;
  const senderId = normalizeChatId(req.body.senderId);
  const receiverId = normalizeChatId(req.body.receiverId);
  const senderRole = normalizeChatId(req.body.senderRole || 'nurse');
  const receiverRole = normalizeChatId(req.body.receiverRole || 'patient');
  const messageType = normalizeChatId(req.body.messageType || 'text');
  const text = (req.body.text ?? req.body.message ?? '').toString().trim();
  const clientMessageId = normalizeChatId(req.body.clientMessageId);

  if (!senderId || !receiverId || messageType !== 'text') {
    return res.status(400).json({
      error: 'senderId, receiverId and text messageType are required',
    });
  }
  if (!text) return res.status(400).json({ error: 'Message text is required' });

  try {
    await ensureChatSchema();
    const conversation = await getConversationForUser(conversationId, senderId);
    if (!conversation) return res.status(403).json({ error: 'Forbidden' });
    if (![conversation.patientId, conversation.nurseId].includes(receiverId)) {
      return res.status(403).json({ error: 'Receiver is not in conversation' });
    }

    if (clientMessageId) {
      const [dupes] = await db.query(
        `SELECT ${chatMessageSelect()}
         FROM message
         WHERE conversationId = ? AND clientMessageId = ?
         LIMIT 1`,
        [conversationId, clientMessageId]
      );
      if (dupes[0]) return res.status(200).json(dupes[0]);
    }

    await touchChatPresence(senderId);
    const messageId = randomUUID();
    await db.execute(
      `INSERT INTO message (
         messageId, conversationId, clientMessageId,
         senderId, senderRole, receiverId, receiverRole,
         message, messageType, status, createdAt, sentAt, isRead
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'sent', NOW(), NOW(), 0)`,
      [
        messageId,
        conversationId,
        clientMessageId || null,
        senderId,
        senderRole,
        receiverId,
        receiverRole,
        text,
        messageType,
      ]
    );
    await db.query(
      `UPDATE chatconversation
       SET lastMessage = ?, lastMessageAt = NOW(), lastSenderId = ?,
           updatedAt = NOW()
       WHERE conversationId = ?`,
      [text, senderId, conversationId]
    );

    try {
      await insertNotification({
        userId: receiverId,
        type: 'chat_message',
        title: 'New message',
        body: text.length > 80 ? `${text.slice(0, 77)}...` : text,
        relatedRequestId: conversation.requestId,
      });
    } catch (_) {}

    const [rows] = await db.query(
      `SELECT ${chatMessageSelect()} FROM message WHERE messageId = ? LIMIT 1`,
      [messageId]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/chat/conversations/:conversationId/read', async (req, res) => {
  const { conversationId } = req.params;
  const readerId = normalizeChatId(req.body.readerId);
  if (!readerId) return res.status(400).json({ error: 'readerId is required' });

  try {
    await ensureChatSchema();
    const conversation = await getConversationForUser(conversationId, readerId);
    if (!conversation) return res.status(403).json({ error: 'Forbidden' });
    const [result] = await db.query(
      `UPDATE message
       SET deliveredAt = COALESCE(deliveredAt, NOW()),
           readAt = COALESCE(readAt, NOW()),
           isRead = 1,
           status = 'read'
       WHERE conversationId = ? AND receiverId = ? AND readAt IS NULL`,
      [conversationId, readerId]
    );
    res.json({ updated: result.affectedRows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/messages/:userId', async (req, res) => {
  const { userId } = req.params;

  try {
    await ensureChatSchema();
    const [rows] = await db.query(
      `SELECT
          c.conversationId,
          CASE WHEN c.patientId = ? THEN c.nurseId ELSE c.patientId END AS doctorId,
          CASE WHEN c.patientId = ? THEN c.nurseId ELSE c.patientId END AS providerId,
          CASE WHEN c.patientId = ? THEN nurse.fullName ELSE patient.fullName END AS doctorName,
          CASE WHEN c.patientId = ? THEN nurse.fullName ELSE patient.fullName END AS name,
          cp.specialization,
          COALESCE(c.lastMessage, '') AS lastMessage,
          COALESCE(c.lastMessageAt, c.updatedAt) AS sentAt,
          (
            SELECT COUNT(*)
            FROM message m
            WHERE m.conversationId = c.conversationId
              AND m.receiverId = ?
              AND m.readAt IS NULL
          ) AS unreadCount
       FROM chatconversation c
       LEFT JOIN user patient ON patient.userId = c.patientId
       LEFT JOIN user nurse ON nurse.userId = c.nurseId
       LEFT JOIN careprovider cp
         ON cp.userId = CASE WHEN c.patientId = ? THEN c.nurseId ELSE c.patientId END
       WHERE c.patientId = ? OR c.nurseId = ?
       ORDER BY COALESCE(c.lastMessageAt, c.updatedAt) DESC`,
      [userId, userId, userId, userId, userId, userId, userId, userId]
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/chat/:userId/:doctorId', async (req, res) => {
  const { userId, doctorId } = req.params;
  const viewerId = (req.query.viewerId || userId).toString().trim();

  try {
    await ensureChatSchema();
    await touchChatPresence(viewerId);
    await db.query(
      `UPDATE message
       SET deliveredAt = COALESCE(deliveredAt, NOW()),
           readAt = COALESCE(readAt, NOW()),
           isRead = 1
       WHERE receiverId = ?
         AND senderId IN (?, ?)
         AND readAt IS NULL`,
      [viewerId, userId, doctorId]
    );

    const [rows] = await db.query(
      `
      SELECT ${chatMessageSelect()}
      FROM message
      WHERE
        (senderId = ? AND receiverId = ?)
        OR
        (senderId = ? AND receiverId = ?)
      ORDER BY createdAt ASC
      `,
      [userId, doctorId, doctorId, userId]
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/chat/send', async (req, res) => {
  const {
    senderId,
    receiverId,
    message = '',
    messageType = 'text',
    medicalRecordId,
    voiceDurationSeconds,
  } = req.body;
  const allowedTypes = ['text', 'medical_record', 'system'];

  if (!senderId || !receiverId || !allowedTypes.includes(messageType)) {
    return res.status(400).json({ error: 'Valid senderId, receiverId and messageType are required' });
  }
  if (messageType === 'text' && !message.toString().trim()) {
    return res.status(400).json({ error: 'Message text is required' });
  }

  try {
    await ensureChatSchema();
    await touchChatPresence(senderId);
    const messageId = randomUUID();
    let conversationId = null;
    let senderRole = null;
    let receiverRole = null;
    const [conversationRows] = await db.query(
      `SELECT conversationId, patientId, nurseId
       FROM chatconversation
       WHERE (patientId = ? AND nurseId = ?) OR (patientId = ? AND nurseId = ?)
       ORDER BY updatedAt DESC
       LIMIT 1`,
      [senderId, receiverId, receiverId, senderId]
    );
    if (conversationRows[0]) {
      conversationId = conversationRows[0].conversationId;
      senderRole =
        conversationRows[0].patientId === senderId ? 'patient' : 'nurse';
      receiverRole =
        conversationRows[0].patientId === receiverId ? 'patient' : 'nurse';
    }
    let attachmentUrl = null;
    let attachmentName = null;
    let attachmentSize = null;
    let attachmentMimeType = null;

    if (messageType === 'medical_record') {
      if (!medicalRecordId) {
        return res.status(400).json({ error: 'medicalRecordId is required' });
      }
      const [records] = await db.query(
        `SELECT
           id,
           title,
           filePath AS file_url,
           originalName AS file_name,
           fileSize AS file_size,
           mimeType AS mime_type
         FROM patientmedicalfile
         WHERE BINARY id = BINARY ? AND BINARY patientUserId = BINARY ?
         LIMIT 1`,
        [medicalRecordId, senderId]
      );
      if (!records.length) {
        return res.status(404).json({ error: 'Medical record not found' });
      }
      const record = records[0];
      attachmentUrl = record.file_url;
      attachmentName = record.file_name || record.title;
      attachmentSize = record.file_size;
      attachmentMimeType = record.mime_type || 'application/pdf';
    }

    await db.execute(
      `INSERT INTO message (
         messageId, conversationId, senderId, senderRole, receiverId, receiverRole,
         message, messageType, status,
         attachmentUrl, attachmentName, attachmentSize, attachmentMimeType,
         medicalRecordId, voiceDurationSeconds, createdAt, sentAt, isRead
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'sent', ?, ?, ?, ?, ?, ?, NOW(), NOW(), 0)`,
      [
        messageId,
        conversationId,
        senderId,
        senderRole,
        receiverId,
        receiverRole,
        message.toString().trim(),
        messageType,
        attachmentUrl,
        attachmentName,
        attachmentSize,
        attachmentMimeType,
        medicalRecordId || null,
        voiceDurationSeconds || null,
      ]
    );
    if (conversationId) {
      await db.query(
        `UPDATE chatconversation
         SET lastMessage = ?, lastMessageAt = NOW(), lastSenderId = ?,
             updatedAt = NOW()
         WHERE conversationId = ?`,
        [message.toString().trim(), senderId, conversationId]
      );
    }

    res.status(201).json({
      message: 'Message sent successfully',
      messageId,
      messageType,
      sentAt: new Date().toISOString(),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/chat/send-attachment', chatUpload.single('file'), async (req, res) => {
  const { senderId, receiverId, message = '', voiceDurationSeconds } = req.body;
  if (!senderId || !receiverId || !req.file) {
    return res.status(400).json({ error: 'senderId, receiverId and file are required' });
  }

  try {
    await ensureChatSchema();
    await touchChatPresence(senderId);
    const messageId = randomUUID();
    const originalName = Buffer.from(req.file.originalname, 'latin1').toString('utf8');
    const relativeUrl = `/uploads/chat/${req.file.filename}`;
    const messageType = req.file.mimetype.startsWith('image/')
      ? 'image'
      : req.file.mimetype.startsWith('audio/')
        ? 'voice'
        : 'pdf';

    await db.execute(
      `INSERT INTO message (
         messageId, senderId, receiverId, message, messageType,
         attachmentUrl, attachmentName, attachmentSize, attachmentMimeType,
         voiceDurationSeconds, createdAt, sentAt, isRead
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW(), 0)`,
      [
        messageId,
        senderId,
        receiverId,
        message.toString().trim(),
        messageType,
        relativeUrl,
        originalName,
        req.file.size,
        req.file.mimetype,
        voiceDurationSeconds ? Number(voiceDurationSeconds) : null,
      ]
    );

    res.status(201).json({
      messageId,
      messageType,
      attachmentUrl: relativeUrl,
      attachmentName: originalName,
      attachmentSize: req.file.size,
      attachmentMimeType: req.file.mimetype,
      voiceDurationSeconds: voiceDurationSeconds ? Number(voiceDurationSeconds) : null,
      sentAt: new Date().toISOString(),
    });
  } catch (err) {
    if (req.file?.path) fs.unlink(req.file.path, () => {});
    res.status(500).json({ error: err.message });
  }
});

router.post('/chat/read', async (req, res) => {
  const { readerId, otherUserId } = req.body;
  if (!readerId || !otherUserId) {
    return res.status(400).json({ error: 'readerId and otherUserId are required' });
  }
  try {
    await ensureChatSchema();
    await touchChatPresence(readerId);
    const [result] = await db.query(
      `UPDATE message
       SET deliveredAt = COALESCE(deliveredAt, NOW()),
           readAt = COALESCE(readAt, NOW()),
           isRead = 1
       WHERE receiverId = ? AND senderId = ? AND readAt IS NULL`,
      [readerId, otherUserId]
    );
    res.json({ updated: result.affectedRows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/chat/presence', async (req, res) => {
  const { userId } = req.body;
  if (!userId) return res.status(400).json({ error: 'userId is required' });
  try {
    await ensureChatSchema();
    await touchChatPresence(userId);
    await db.query(
      `UPDATE message
       SET deliveredAt = COALESCE(deliveredAt, NOW())
       WHERE receiverId = ? AND deliveredAt IS NULL`,
      [userId]
    );
    res.json({ lastActive: new Date().toISOString() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/chat/status/presence/:userId', async (req, res) => {
  try {
    await ensureChatSchema();
    const [rows] = await db.query(
      'SELECT lastActive FROM chat_presence WHERE userId = ? LIMIT 1',
      [req.params.userId]
    );
    const lastActive = rows[0]?.lastActive || null;
    const isOnline = lastActive
      ? Date.now() - new Date(lastActive).getTime() < 60 * 1000
      : false;
    res.json({ userId: req.params.userId, isOnline, lastActive });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/chat/typing', async (req, res) => {
  const { senderId, receiverId, isTyping } = req.body;
  if (!senderId || !receiverId) {
    return res.status(400).json({ error: 'senderId and receiverId are required' });
  }
  const key = `${senderId}:${receiverId}`;
  if (isTyping) {
    chatTyping.set(key, Date.now() + 6000);
  } else {
    chatTyping.delete(key);
  }
  res.json({ isTyping: Boolean(isTyping) });
});

router.get('/chat/typing/:senderId/:receiverId', (req, res) => {
  const key = `${req.params.senderId}:${req.params.receiverId}`;
  const expiresAt = chatTyping.get(key) || 0;
  const isTyping = expiresAt > Date.now();
  if (!isTyping) chatTyping.delete(key);
  res.json({ isTyping });
});

router.get('/notifications/:userId', async (req, res) => {
  const { userId } = req.params;
  if (!userId) {
    return res.status(400).json({ error: 'userId is required' });
  }

  try {
    const [rows] = await db.query(
      `SELECT
          notificationId AS id,
          notificationId AS notificationId,
          type,
          title,
          body AS message,
          isRead,
          createdAt,
          relatedRequestId
       FROM usernotification
       WHERE userId = ?
       ORDER BY createdAt DESC
       LIMIT 200`,
      [userId]
    );
    res.json(rows);
  } catch (err) {
    if (err && err.code === 'ER_NO_SUCH_TABLE') {
      return res.json([]);
    }
    res.status(500).json({ error: err.message });
  }
});

router.put('/appointments/:appointmentId/reschedule', async (req, res) => {
  const { appointmentId } = req.params;
  const { date, time } = req.body;

  if (!date || !time) {
    return res.status(400).json({ error: 'Date and time are required' });
  }

  const scheduledAt = normalizeDateTime(date, time);
  if (!scheduledAt) {
    return res.status(400).json({ error: 'Invalid appointment date or time' });
  }

  try {
    const [rows] = await db.query(
      `SELECT status FROM servicerequest WHERE requestId = ?`,
      [appointmentId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    const currentStatus = (rows[0].status || '').toString().toLowerCase().trim();
    const allowed = [
      'pending',
      'pending_payment',
      'payment_pending',
      'request_sent',
      'requested',
      'waiting_provider_response',
      'waiting response',
    ];
    if (!allowed.includes(currentStatus)) {
      return res.status(400).json({
        error: 'Rescheduling is only allowed before the provider accepts or rejects the appointment.'
      });
    }

    await db.execute(
      `UPDATE servicerequest SET scheduledAt = ? WHERE requestId = ?`,
      [scheduledAt, appointmentId]
    );

    res.json({ message: 'Appointment rescheduled successfully', scheduledAt });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Favorites (Canonical Table: patientfavoriteprovider) ---

router.get('/favorites/:patientUserId', async (req, res) => {
  const { patientUserId } = req.params;
  try {
    const [rows] = await db.query(
      `SELECT pfp.providerUserId, u.fullName AS displayName, cp.specialization AS specialty,
              u.profileImageUrl AS profilePictureUrl, cp.overallRating AS rating
       FROM patientfavoriteprovider pfp
       JOIN user u ON pfp.providerUserId = u.userId
       LEFT JOIN careprovider cp ON pfp.providerUserId = cp.userId
       WHERE pfp.patientUserId = ?
       ORDER BY pfp.createdAt DESC`,
      [patientUserId]
    );
    // Format to match old UI expectations
    const favorites = rows.map(r => ({
      providerId: r.providerUserId,
      displayName: r.displayName || 'Unknown',
      specialty: r.specialty || '',
      profilePictureUrl: r.profilePictureUrl || null,
      rating: r.rating || 0.0
    }));
    res.json(favorites);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

router.post('/favorites', async (req, res) => {
  const { patientUserId, providerUserId } = req.body;
  if (!patientUserId || !providerUserId) {
    return res.status(400).json({ error: 'patientUserId and providerUserId are required' });
  }
  try {
    const favoriteId = randomUUID();
    await db.execute(
      `INSERT INTO patientfavoriteprovider (favoriteId, patientUserId, providerUserId, createdAt)
       VALUES (?, ?, ?, NOW())
       ON DUPLICATE KEY UPDATE createdAt = NOW()`,
      [favoriteId, patientUserId, providerUserId]
    );
    res.json({ message: 'Favorite added successfully', favoriteId });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

router.delete('/favorites/:patientUserId/:providerUserId', async (req, res) => {
  const { patientUserId, providerUserId } = req.params;
  try {
    await db.execute(
      `DELETE FROM patientfavoriteprovider WHERE patientUserId = ? AND providerUserId = ?`,
      [patientUserId, providerUserId]
    );
    res.json({ message: 'Favorite removed successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

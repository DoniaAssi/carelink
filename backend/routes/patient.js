const express = require('express');
const { randomUUID } = require('crypto');
const db = require('../db');
const { insertNotification } = require('../notifications');

const router = express.Router();

const BOOKING_STATUSES = ['pending', 'confirmed', 'completed', 'cancelled'];
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

async function recomputeProviderOverallRating(providerUserId) {
  const [agg] = await db.query(
    `SELECT AVG(stars) AS a, COUNT(*) AS c
     FROM providervisitrating
     WHERE providerUserId = ?`,
    [providerUserId]
  );
  const cnt = Number(agg[0]?.c || 0);
  const raw = agg[0]?.a;
  const value = cnt === 0 ? 0 : Math.round(Number(raw) * 100) / 100;
  await db.execute(
    `UPDATE careprovider SET overallRating = ? WHERE userId = ?`,
    [value, providerUserId]
  );
}

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
         ${hasMeds ? 'p.currentMedications' : 'NULL AS currentMedications'}
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

router.put('/profile/:userId', async (req, res) => {
  const { userId } = req.params;
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
    currentMedications
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

    let userResult;
    if (hasProfileImageUrl) {
      [userResult] = await db.execute(
        `UPDATE user
         SET fullName = ?,
             email = ?,
             phone = ?,
             profileImageUrl = COALESCE(?, profileImageUrl)
         WHERE userId = ?`,
        [fullName, email, phone, profileImageUrl ?? null, userId]
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

router.get('/appointments/:patientUserId', async (req, res) => {
  const { patientUserId } = req.params;
  const status = req.query.status ? req.query.status.toString().toLowerCase().trim() : null;
  const isValidStatus = status && BOOKING_STATUSES.includes(status);

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

    const params = [patientUserId];
    let whereStatus = '';
    if (isValidStatus) {
      whereStatus = ' AND sr.status = ?';
      params.push(status);
    }

    const [rows] = await db.query(
      `SELECT
          sr.requestId AS appointmentId,
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
          sr.scheduledAt,
          sr.providerUserId AS doctorUserId,
          u.fullName AS doctorName,
          u.role AS providerRole,
          c.specialization
       FROM servicerequest sr
       LEFT JOIN user u ON sr.providerUserId = u.userId
       LEFT JOIN careprovider c ON u.userId = c.userId
       WHERE sr.patientUserId = ?${whereStatus}
       ORDER BY sr.scheduledAt DESC`,
      params
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/appointments/upcoming/:patientUserId', async (req, res) => {
  const { patientUserId } = req.params;

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

    const [rows] = await db.query(
      `SELECT
          sr.requestId AS appointmentId,
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
          sr.scheduledAt,
          sr.providerUserId AS doctorUserId,
          u.fullName AS doctorName,
          u.role AS providerRole,
          c.specialization
       FROM servicerequest sr
       LEFT JOIN user u ON sr.providerUserId = u.userId
       LEFT JOIN careprovider c ON u.userId = c.userId
       WHERE sr.patientUserId = ?
         AND sr.status IN ('pending', 'confirmed')
       ORDER BY sr.scheduledAt ASC`,
      [patientUserId]
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/appointments/history/:patientUserId', async (req, res) => {
  const { patientUserId } = req.params;

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

    const [rows] = await db.query(
      `SELECT
          sr.requestId AS appointmentId,
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
          sr.scheduledAt,
          sr.providerUserId AS doctorUserId,
          u.fullName AS doctorName,
          u.role AS providerRole,
          c.specialization
       FROM servicerequest sr
       LEFT JOIN user u ON sr.providerUserId = u.userId
       LEFT JOIN careprovider c ON u.userId = c.userId
       WHERE sr.patientUserId = ?
         AND sr.status IN ('completed', 'cancelled')
       ORDER BY sr.scheduledAt DESC`,
      [patientUserId]
    );

    res.json(rows);
  } catch (err) {
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

    const hasRatings = await hasTable('providervisitrating');
    const ratingSelect = hasRatings
      ? 'pvr.stars AS patientRatingStars, pvr.comment AS patientRatingComment'
      : 'NULL AS patientRatingStars, NULL AS patientRatingComment';
    const ratingJoin = hasRatings
      ? 'LEFT JOIN providervisitrating pvr ON pvr.requestId = sr.requestId'
      : '';

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

  if (!patientUserId) {
    return res.status(400).json({ error: 'patientUserId is required' });
  }

  const s = Math.round(Number(stars));
  if (!Number.isFinite(s) || s < 1 || s > 5) {
    return res.status(400).json({ error: 'stars must be between 1 and 5' });
  }

  if (!(await hasTable('providervisitrating'))) {
    return res.status(501).json({
      error: 'Ratings are not available; run the providervisitrating migration.'
    });
  }

  const commentText =
    comment != null ? String(comment).trim().slice(0, 2000) : '';

  try {
    const [rows] = await db.query(
      `SELECT requestId, patientUserId, providerUserId, status
       FROM servicerequest
       WHERE requestId = ?`,
      [appointmentId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    const row = rows[0];
    if (row.patientUserId !== patientUserId) {
      return res.status(403).json({ error: 'Not allowed' });
    }

    if ((row.status || '').toString().toLowerCase() !== 'completed') {
      return res.status(409).json({
        error: 'You can only rate after the visit is completed'
      });
    }

    const [existing] = await db.query(
      'SELECT ratingId FROM providervisitrating WHERE requestId = ?',
      [appointmentId]
    );

    if (existing.length > 0) {
      return res.status(409).json({ error: 'This visit is already rated' });
    }

    const ratingId = randomUUID();
    await db.execute(
      `INSERT INTO providervisitrating
       (ratingId, requestId, patientUserId, providerUserId, stars, comment, createdAt)
       VALUES (?, ?, ?, ?, ?, ?, NOW())`,
      [
        ratingId,
        appointmentId,
        row.patientUserId,
        row.providerUserId,
        s,
        commentText || null
      ]
    );

    await recomputeProviderOverallRating(row.providerUserId);

    res.status(201).json({
      success: true,
      ratingId,
      message: 'Thank you. Your rating helps improve CareLink recommendations.'
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
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

  if (!patientUserId || !finalDoctorUserId || !finalDate || !finalTime) {
    return res.status(400).json({
      error: 'patientUserId, doctor/provider userId, date and time are required'
    });
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

    const [conflicts] = await db.query(
      `SELECT requestId
       FROM servicerequest
       WHERE patientUserId = ?
         AND providerUserId = ?
         AND serviceType = ?
         AND scheduledAt = ?
         AND status IN ('pending', 'confirmed')`,
      [patientUserId, finalDoctorUserId, finalServiceType, scheduledAt]
    );

    if (conflicts.length > 0) {
      return res.status(409).json({
        error: 'You already have a pending/confirmed appointment at this time.'
      });
    }

    const requestId = randomUUID();
    const requestLocation = location ?? '';
    const finalStatus = toStatus(status, BOOKING_STATUSES, 'pending');
    const parsedVisitLat = visitLatitude == null || visitLatitude === ''
      ? null
      : Number(visitLatitude);
    const parsedVisitLng = visitLongitude == null || visitLongitude === ''
      ? null
      : Number(visitLongitude);
    const normalizedPaymentMethod = paymentMethod
      ? paymentMethod.toString().trim().toLowerCase()
      : '';
    const normalizedPaymentStatus = paymentStatus
      ? toStatus(paymentStatus, PAYMENT_STATUSES, 'unpaid')
      : '';

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

    res.status(201).json({
      message: 'Appointment created successfully',
      appointmentId: requestId,
      status: finalStatus
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
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
    if (!['pending', 'confirmed'].includes(current.status)) {
      return res.status(409).json({
        error: 'Only pending or confirmed appointments can be cancelled'
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

router.post('/payments', async (req, res) => {
  const {
    appointmentId,
    patientUserId,
    providerUserId,
    amount,
    paymentMethod,
    status
  } = req.body;

  // Never accept raw card / CVV / track fields — in production, use a gateway (token) only.
  const disallowedKeyNorm = new Set([
    'cardnumber',
    'ccnumber',
    'ccnum',
    'cvv',
    'cvc',
    'cvc2',
    'pan',
    'trackdata',
    'track1',
    'track2',
    'magstripe',
    'debitcardnumber',
    'creditcardnumber',
    'cardholdername',
    'expirymonth',
    'expiryyear',
    'expirydate'
  ]);
  for (const k of Object.keys(req.body || {})) {
    const n = k.toString().toLowerCase().replace(/[^a-z0-9]/g, '');
    if (disallowedKeyNorm.has(n)) {
      return res.status(400).json({
        error:
          'Sensitive payment data must not be sent to this API. Use TLS and a PCI-compliant provider; only method and amount are stored here.'
      });
    }
  }

  if (!appointmentId || !patientUserId || !providerUserId || amount == null || !paymentMethod) {
    return res.status(400).json({
      error: 'appointmentId, patientUserId, providerUserId, amount and paymentMethod are required'
    });
  }

  const parsedAmount = Number(amount);
  if (!Number.isFinite(parsedAmount) || parsedAmount < 0) {
    return res.status(400).json({ error: 'amount must be a valid number' });
  }

  const normalizedMethod = paymentMethod.toString().trim().toLowerCase();
  const allowZero =
    normalizedMethod === 'cash' ||
    normalizedMethod === 'card' ||
    normalizedMethod === 'cash_on_visit';
  if (!allowZero && parsedAmount <= 0) {
    return res.status(400).json({ error: 'amount must be a positive number' });
  }

  try {
    const hasPaymentMethod = await hasColumn('servicerequest', 'paymentMethod');
    const hasPaymentStatus = await hasColumn('servicerequest', 'paymentStatus');
    const hasTransactionId = await hasColumn('payment', 'transactionId');
    const hasPaidAt = await hasColumn('payment', 'paidAt');

    const [appointments] = await db.query(
      `SELECT requestId
       FROM servicerequest
       WHERE requestId = ? AND patientUserId = ? AND providerUserId = ?`,
      [appointmentId, patientUserId, providerUserId]
    );

    if (appointments.length === 0) {
      return res.status(404).json({ error: 'Related appointment not found' });
    }

    const [existingPayment] = await db.query(
      'SELECT paymentId FROM payment WHERE requestId = ?',
      [appointmentId]
    );

    if (existingPayment.length > 0) {
      return res.status(409).json({ error: 'Payment already exists for this appointment' });
    }

    const paymentId = randomUUID();
    const computedStatus = status
      ? toStatus(status, PAYMENT_STATUSES, 'unpaid')
      : normalizedMethod === 'cash' || normalizedMethod === 'cash_on_visit'
        ? 'unpaid'
        : normalizedMethod === 'card'
          ? 'pending'
          : 'paid';

    const baseParams = [
      paymentId,
      appointmentId,
      patientUserId,
      providerUserId,
      parsedAmount,
      normalizedMethod,
      computedStatus
    ];

    if (hasTransactionId && hasPaidAt) {
      await db.execute(
        `INSERT INTO payment
         (paymentId, requestId, patientUserId, providerUserId, amount, paymentMethod, paymentStatus, transactionId, paidAt, createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL, NOW(), NOW())`,
        baseParams
      );
    } else {
      await db.execute(
        `INSERT INTO payment
         (paymentId, requestId, patientUserId, providerUserId, amount, paymentMethod, paymentStatus, createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
        baseParams
      );
    }

    if (hasPaymentMethod || hasPaymentStatus) {
      const updates = [];
      const updateValues = [];
      if (hasPaymentMethod) {
        updates.push('paymentMethod = ?');
        updateValues.push(normalizedMethod);
      }
      if (hasPaymentStatus) {
        updates.push('paymentStatus = ?');
        updateValues.push(computedStatus);
      }
      if (updates.length) {
        updateValues.push(appointmentId);
        await db.execute(
          `UPDATE servicerequest SET ${updates.join(', ')} WHERE requestId = ?`,
          updateValues
        );
      }
    }

    res.status(201).json({
      message: 'Payment stored successfully',
      paymentId,
      appointmentId,
      bookingId: appointmentId,
      paymentStatus: computedStatus
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/payments/:patientUserId', async (req, res) => {
  const { patientUserId } = req.params;

  try {
    const [rows] = await db.query(
      `SELECT
          p.paymentId,
          p.requestId AS appointmentId,
          p.requestId AS bookingId,
          p.amount,
          p.paymentMethod,
          p.paymentStatus,
          p.transactionId,
          p.paidAt,
          p.createdAt,
          sr.scheduledAt,
          u.fullName AS providerName
       FROM payment p
       LEFT JOIN servicerequest sr ON p.requestId = sr.requestId
       LEFT JOIN user u ON p.providerUserId = u.userId
       WHERE p.patientUserId = ?
       ORDER BY p.createdAt DESC`,
      [patientUserId]
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/messages/:userId', async (req, res) => {
  const { userId } = req.params;

  try {
    const [rows] = await db.query(
      `SELECT
          u.userId AS doctorId,
          u.fullName AS doctorName,
          c.specialization,
          'No messages yet' AS lastMessage,
          '' AS sentAt
       FROM user u
       JOIN careprovider c ON u.userId = c.userId
       WHERE u.role = 'doctor'
       ORDER BY u.fullName ASC`,
      [userId]
    );

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/chat/:userId/:doctorId', async (req, res) => {
  const { userId, doctorId } = req.params;

  try {
    const [rows] = await db.query(
      `
      SELECT senderId, receiverId, message, createdAt
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
  const { senderId, receiverId, message } = req.body;

  if (!senderId || !receiverId || !message || !message.toString().trim()) {
    return res.status(400).json({ error: 'senderId, receiverId and message are required' });
  }

  try {
    const messageId = randomUUID();
    await db.execute(
      `INSERT INTO message (messageId, senderId, receiverId, message, createdAt)
       VALUES (?, ?, ?, ?, NOW())`,
      [messageId, senderId, receiverId, message.toString().trim()]
    );

    res.status(201).json({
      message: 'Message sent successfully',
      messageId
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
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

module.exports = router;

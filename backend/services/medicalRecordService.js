const { randomUUID } = require('crypto');
const db = require('../db');

async function tableExists(name) {
  const [rows] = await db.query('SHOW TABLES LIKE ?', [name]);
  return rows.length > 0;
}

async function hasColumn(tableName, columnName) {
  try {
    const [rows] = await db.query(
      `SHOW COLUMNS FROM ${tableName} LIKE ?`,
      [columnName]
    );
    return rows.length > 0;
  } catch (_) {
    return false;
  }
}

function toDateOnly(value) {
  if (value === null || value === undefined || value === '') return null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }
  const s = value.toString().trim();
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().slice(0, 10);
}

/**
 * Patient-facing list: official provider-authored visit reports only.
 */
async function listVisitReportsForPatient(patientId) {
  if (!(await tableExists('visit_reports'))) return [];
  const hasVisitDate = await hasColumn('visit_reports', 'visit_date');
  const hasMed = await hasColumn('visit_reports', 'medications_prescribed');
  const hasAll = await hasColumn('visit_reports', 'allergies_noted');

  const visitDateExpr = hasVisitDate
    ? 'COALESCE(vr.visit_date, DATE(vr.created_at))'
    : 'DATE(vr.created_at)';

  const [rows] = await db.query(
    `SELECT
       vr.id,
       vr.patient_id AS patient_id,
       vr.provider_id,
       'visit_report' AS record_type,
       COALESCE(NULLIF(TRIM(vr.diagnosis), ''), 'Visit report') AS title,
       vr.diagnosis,
       '' AS symptoms,
       TRIM(BOTH ' ' FROM CONCAT(
         IFNULL(NULLIF(TRIM(vr.treatment_plan), ''), ''),
         IF(
           IFNULL(TRIM(vr.recommendations), '') <> '',
           CONCAT(CHAR(10), CHAR(10), 'Recommendations:', CHAR(10), vr.recommendations),
           ''
         )
       )) AS notes,
       ${hasMed ? 'NULLIF(TRIM(vr.medications_prescribed), \'\')' : 'NULL'} AS medications,
       ${hasAll ? 'NULLIF(TRIM(vr.allergies_noted), \'\')' : 'NULL'} AS allergies,
       vr.treatment_plan,
       vr.recommendations,
       vr.vital_signs,
       vr.follow_up_required,
       vr.follow_up_date,
       vr.appointment_id,
       ${visitDateExpr} AS visit_date,
       vr.created_at,
       u.fullName AS providerName
     FROM visit_reports vr
     LEFT JOIN user u ON BINARY u.userId = BINARY vr.provider_id
     WHERE BINARY vr.patient_id = BINARY ?
     ORDER BY ${visitDateExpr} DESC, vr.created_at DESC`,
    [patientId]
  );
  return rows;
}

async function getVisitReportById(recordId) {
  if (!(await tableExists('visit_reports'))) return null;
  const hasVisitDate = await hasColumn('visit_reports', 'visit_date');
  const hasMed = await hasColumn('visit_reports', 'medications_prescribed');
  const hasAll = await hasColumn('visit_reports', 'allergies_noted');
  const visitDateExpr = hasVisitDate
    ? 'COALESCE(vr.visit_date, DATE(vr.created_at))'
    : 'DATE(vr.created_at)';

  const [rows] = await db.query(
    `SELECT
       vr.id,
       vr.patient_id AS patient_id,
       vr.provider_id,
       'visit_report' AS record_type,
       COALESCE(NULLIF(TRIM(vr.diagnosis), ''), 'Visit report') AS title,
       vr.diagnosis,
       '' AS symptoms,
       TRIM(BOTH ' ' FROM CONCAT(
         IFNULL(NULLIF(TRIM(vr.treatment_plan), ''), ''),
         IF(
           IFNULL(TRIM(vr.recommendations), '') <> '',
           CONCAT(CHAR(10), CHAR(10), 'Recommendations:', CHAR(10), vr.recommendations),
           ''
         )
       )) AS notes,
       ${hasMed ? 'NULLIF(TRIM(vr.medications_prescribed), \'\')' : 'NULL'} AS medications,
       ${hasAll ? 'NULLIF(TRIM(vr.allergies_noted), \'\')' : 'NULL'} AS allergies,
       vr.treatment_plan,
       vr.recommendations,
       vr.vital_signs,
       vr.follow_up_required,
       vr.follow_up_date,
       vr.appointment_id,
       ${visitDateExpr} AS visit_date,
       vr.created_at,
       u.fullName AS providerName
     FROM visit_reports vr
     LEFT JOIN user u ON BINARY u.userId = BINARY vr.provider_id
     WHERE BINARY vr.id = BINARY ?
     LIMIT 1`,
    [recordId]
  );
  return rows[0] ?? null;
}

async function insertVisitReport(payload) {
  const id = randomUUID();
  const vital =
    typeof payload.vital_signs === 'string'
      ? payload.vital_signs
      : JSON.stringify(payload.vital_signs ?? {});

  const hasVisitDate = await hasColumn('visit_reports', 'visit_date');
  const hasMed = await hasColumn('visit_reports', 'medications_prescribed');
  const hasAll = await hasColumn('visit_reports', 'allergies_noted');

  const visitDate =
    toDateOnly(payload.visit_date ?? payload.visitDate) ||
    toDateOnly(new Date());

  const baseCols = [
    'id',
    'patient_id',
    'provider_id',
    'appointment_id',
    'vital_signs',
    'diagnosis',
    'treatment_plan',
    'recommendations',
    'follow_up_required',
    'follow_up_date',
  ];
  const baseVals = [
    id,
    payload.patient_id,
    payload.provider_id,
    payload.appointment_id ?? null,
    vital,
    payload.diagnosis ?? '',
    payload.treatment_plan ?? '',
    payload.recommendations ?? '',
    payload.follow_up_required ? 1 : 0,
    payload.follow_up_date ?? null,
  ];

  if (hasVisitDate) {
    baseCols.push('visit_date');
    baseVals.push(visitDate);
  }
  if (hasMed) {
    baseCols.push('medications_prescribed');
    baseVals.push(
      (payload.medications_prescribed ?? payload.medicationsPrescribed ?? '')
        .toString()
    );
  }
  if (hasAll) {
    baseCols.push('allergies_noted');
    baseVals.push(
      (payload.allergies_noted ?? payload.allergiesNoted ?? '').toString()
    );
  }

  await db.execute(
    `INSERT INTO visit_reports (${baseCols.join(', ')})
     VALUES (${baseCols.map(() => '?').join(', ')})`,
    baseVals
  );

  return getVisitReportById(id);
}

async function appointmentLinksPatientProvider(appointmentId, patientId, providerId) {
  if (!appointmentId) return true;
  const [rows] = await db.query(
    `SELECT requestId FROM servicerequest
     WHERE BINARY requestId = BINARY ?
       AND BINARY patientUserId = BINARY ?
       AND BINARY providerUserId = BINARY ?`,
    [appointmentId, patientId, providerId]
  );
  return rows.length > 0;
}

async function listPatientMedicalRecordsForPatient(patientId) {
  if (!(await tableExists('patientmedicalfile'))) return [];
  const [rows] = await db.query(
    `SELECT
       id,
       patientUserId AS patient_id,
       uploadedByRole AS uploaded_by,
       'attachment' AS record_type,
       title,
       description,
       category,
       filePath AS file_url,
       originalName AS file_name,
       fileSize AS file_size,
       mimeType AS file_extension,
       mimeType AS mime_type,
       uploadDate AS created_at,
       createdAt,
       aiProcessed AS ai_ready,
       aiStatus AS extracted_text_status,
       aiSummary AS medical_summary,
       aiSummary,
       ocrText AS extracted_text,
       ocrText,
       analysisTags AS tags,
       analysisTags,
       'patient_upload' AS source
     FROM patientmedicalfile
     WHERE BINARY patientUserId = BINARY ?
     ORDER BY uploadDate DESC`,
    [patientId]
  );
  return rows.map((r) => {
    try {
      r.tags = typeof r.tags === 'string' && r.tags.trim() ? JSON.parse(r.tags) : (r.tags || []);
    } catch (_) {
      r.tags = [];
    }
    return r;
  });
}

async function getPatientMedicalRecordById(recordId) {
  if (!(await tableExists('patientmedicalfile'))) return null;
  const [rows] = await db.query(
    `SELECT
       id,
       patientUserId AS patient_id,
       uploadedByRole AS uploaded_by,
       'attachment' AS record_type,
       title,
       description,
       category,
       filePath AS file_url,
       originalName AS file_name,
       fileSize AS file_size,
       mimeType AS file_extension,
       mimeType AS mime_type,
       uploadDate AS created_at,
       createdAt,
       aiProcessed AS ai_ready,
       aiStatus AS extracted_text_status,
       aiSummary AS medical_summary,
       aiSummary,
       ocrText AS extracted_text,
       ocrText,
       analysisTags AS tags,
       analysisTags,
       'patient_upload' AS source
     FROM patientmedicalfile
     WHERE BINARY id = BINARY ?
     LIMIT 1`,
    [recordId]
  );
  const r = rows[0];
  if (!r) return null;
  try {
    r.tags = typeof r.tags === 'string' && r.tags.trim() ? JSON.parse(r.tags) : (r.tags || []);
  } catch (_) {
    r.tags = [];
  }
  return r;
}

async function insertPatientMedicalRecord(data) {
  const { randomUUID } = require('crypto');
  const id = randomUUID();
  const title = (data.title || 'Untitled').substring(0, 180);
  const category = (data.category || 'other').substring(0, 40);
  const patientId = data.patient_id;
  const description = data.description || null;
  const fileUrl = data.file_url || '';
  const originalName = data.file_name || null;
  const fileSize = data.file_size || 0;
  
  let relativePath = fileUrl;
  if (relativePath.includes('/uploads/')) {
    relativePath = relativePath.substring(relativePath.indexOf('uploads/'));
  }
  
  const mimeType = (data.mime_type || 'application/octet-stream').toString();

  // Handle tags mapping securely
  let analysisTags = "[]";
  if (data.tags) {
    try {
      analysisTags = JSON.stringify(typeof data.tags === 'string' ? JSON.parse(data.tags) : data.tags);
    } catch (e) {
      // Ignore parsing errors and keep default
    }
  }

  await db.execute(
    `INSERT INTO patientmedicalfile (
       id, patientUserId, title, category, description, uploadDate,
       fileUrl, filePath, originalName, mimeType, fileSize,
       uploadedBy, uploadedByRole, aiProcessed, aiStatus, analysisTags, createdAt
    ) VALUES (?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
    [
      id,
      patientId,
      title,
      category,
      description,
      '', // fileUrl column isn't used absolutely anymore, leaving blank or relative
      relativePath,
      originalName,
      mimeType,
      fileSize,
      patientId,
      'patient',
      data.ai_ready || 0,
      data.extracted_text_status || 'pending',
      analysisTags
    ]
  );

  return await getPatientMedicalRecordById(id);
}

async function deletePatientMedicalRecord(recordId) {
  if (!(await tableExists('patientmedicalfile'))) return;
  await db.execute(
    `DELETE FROM patientmedicalfile WHERE BINARY id = BINARY ?`,
    [recordId]
  );
}

async function updatePatientMedicalRecordAi(recordId, aiData) {
  if (!(await tableExists('patientmedicalfile'))) return;
  let analysisTags = '[]';
  if (aiData.analysisTags !== undefined) {
    try {
      analysisTags = JSON.stringify(
        typeof aiData.analysisTags === 'string'
          ? JSON.parse(aiData.analysisTags)
          : aiData.analysisTags
      );
    } catch (_) {
      analysisTags = '[]';
    }
  }
  await db.execute(
    `UPDATE patientmedicalfile 
     SET aiStatus = ?, aiProcessed = ?, ocrText = ?, aiSummary = ?, analysisTags = ?
     WHERE BINARY id = BINARY ?`,
    [
      aiData.aiStatus || 'pending',
      aiData.aiProcessed || 0,
      aiData.ocrText || null,
      aiData.aiSummary || null,
      analysisTags,
      recordId
    ]
  );
  return await getPatientMedicalRecordById(recordId);
}

module.exports = {
  tableExists,
  hasColumn,
  toDateOnly,
  listVisitReportsForPatient,
  getVisitReportById,
  insertVisitReport,
  listPatientMedicalRecordsForPatient,
  getPatientMedicalRecordById,
  insertPatientMedicalRecord,
  deletePatientMedicalRecord,
  updatePatientMedicalRecordAi,
  appointmentLinksPatientProvider,
};

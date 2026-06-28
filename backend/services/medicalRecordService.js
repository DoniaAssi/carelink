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
  const hasReportKind = await hasColumn('visit_reports', 'report_kind');
  const hasSymptoms = await hasColumn('visit_reports', 'symptoms');
  const hasChiefComplaint = await hasColumn(
    'visit_reports',
    'chief_complaint'
  );
  const hasMedicalHistory = await hasColumn(
    'visit_reports',
    'medical_history'
  );
  const hasRequiredVisits = await hasColumn(
    'visit_reports',
    'required_visits'
  );

  const visitDateExpr = hasVisitDate
    ? 'COALESCE(vr.visit_date, DATE(vr.created_at))'
    : 'DATE(vr.created_at)';

  const [rows] = await db.query(
    `SELECT
       vr.id,
       vr.patient_id AS patient_id,
       vr.provider_id,
       ${hasReportKind ? 'vr.report_kind' : "'visit_report'"} AS record_type,
       CASE
         WHEN ${hasReportKind ? "vr.report_kind = 'initial_diagnosis'" : '0'}
           THEN 'Initial Diagnosis Report'
         ELSE COALESCE(NULLIF(TRIM(vr.diagnosis), ''), 'Visit report')
       END AS title,
       vr.diagnosis,
       ${hasSymptoms ? 'NULLIF(TRIM(vr.symptoms), \'\')' : "''"} AS symptoms,
       ${hasChiefComplaint ? 'NULLIF(TRIM(vr.chief_complaint), \'\')' : 'NULL'} AS chiefComplaint,
       ${hasMedicalHistory ? 'NULLIF(TRIM(vr.medical_history), \'\')' : 'NULL'} AS medicalHistory,
       ${hasRequiredVisits ? 'NULLIF(TRIM(vr.required_visits), \'\')' : 'NULL'} AS requiredVisits,
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
       u.fullName AS providerName,
       u.role AS providerRole
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
  const hasReportKind = await hasColumn('visit_reports', 'report_kind');
  const hasChiefComplaint = await hasColumn(
    'visit_reports',
    'chief_complaint'
  );
  const hasSymptoms = await hasColumn('visit_reports', 'symptoms');
  const hasMedicalHistory = await hasColumn(
    'visit_reports',
    'medical_history'
  );
  const hasRequiredVisits = await hasColumn(
    'visit_reports',
    'required_visits'
  );

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
  if (hasReportKind) {
    baseCols.push('report_kind');
    baseVals.push((payload.report_kind ?? 'visit_report').toString());
  }
  if (hasChiefComplaint) {
    baseCols.push('chief_complaint');
    baseVals.push((payload.chief_complaint ?? '').toString());
  }
  if (hasSymptoms) {
    baseCols.push('symptoms');
    baseVals.push((payload.symptoms ?? '').toString());
  }
  if (hasMedicalHistory) {
    baseCols.push('medical_history');
    baseVals.push((payload.medical_history ?? '').toString());
  }
  if (hasRequiredVisits) {
    baseCols.push('required_visits');
    baseVals.push((payload.required_visits ?? '').toString());
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

function cleanText(value) {
  if (value === null || value === undefined) return '';
  const text = value.toString().trim();
  return text.toLowerCase() === 'null' ? '' : text;
}

function creatorRole(value, fallback = 'doctor') {
  const role = cleanText(value).toLowerCase();
  if (role === 'nurse') return 'nurse';
  if (role === 'patient') return 'patient';
  return fallback;
}

function descriptionFromSections(sections) {
  return sections
    .map(([label, value]) => [label, cleanText(value)])
    .filter(([, value]) => value.length > 0)
    .map(([label, value]) => `${label}:\n${value}`)
    .join('\n\n');
}

function normalizedRecord({
  id,
  recordType,
  title,
  description,
  role,
  name,
  source,
  createdAt,
  appointmentId,
  fileUrl,
  aiSummary,
}) {
  return {
    id: cleanText(id),
    recordType: cleanText(recordType) || 'medical_record',
    title: cleanText(title) || 'Medical record',
    description: cleanText(description),
    creatorRole: creatorRole(role),
    creatorName: cleanText(name),
    source: cleanText(source),
    createdAt: createdAt || null,
    appointmentId: cleanText(appointmentId) || null,
    fileUrl: cleanText(fileUrl) || null,
    aiSummary: cleanText(aiSummary) || null,
  };
}

async function listNormalizedVisitReportsForPatient(patientId) {
  const rows = await listVisitReportsForPatient(patientId);
  return rows.map((row) => {
    const recordType = cleanText(row.record_type) || 'visit_report';
    const isInitial = recordType === 'initial_diagnosis';
    return normalizedRecord({
      id: row.id,
      recordType,
      title: isInitial
        ? 'Initial Diagnosis Report'
        : cleanText(row.title) || 'Visit report',
      description: descriptionFromSections([
        ['Chief complaint', row.chiefComplaint],
        ['Symptoms', row.symptoms],
        ['Medical history', row.medicalHistory],
        ['Diagnosis', row.diagnosis],
        ['Treatment plan', row.treatment_plan],
        ['Recommendations', row.recommendations],
        ['Medications', row.medications],
        ['Allergies noted', row.allergies],
        ['Vital signs', row.vital_signs],
        ['Required visits', row.requiredVisits],
      ]),
      role: row.providerRole,
      name: row.providerName,
      source: 'visit_reports',
      createdAt: row.created_at || row.visit_date,
      appointmentId: row.appointment_id,
      fileUrl: null,
      aiSummary: null,
    });
  });
}

async function listInitialDiagnosisReportsForPatient(patientId) {
  if (!(await tableExists('initial_diagnosis_report'))) return [];
  const [rows] = await db.query(
    `SELECT idr.*, sr.patientUserId, sr.scheduledAt, sr.completedAt,
            u.fullName AS creatorName
     FROM initial_diagnosis_report idr
     JOIN servicerequest sr
       ON BINARY sr.requestId = BINARY idr.serviceRequestId
     LEFT JOIN user u
       ON BINARY u.userId = BINARY idr.doctorUserId
     WHERE BINARY sr.patientUserId = BINARY ?
     ORDER BY COALESCE(idr.createdAt, sr.completedAt, sr.scheduledAt) DESC`,
    [patientId]
  );
  return rows.map((row) => normalizedRecord({
    id: row.reportId,
    recordType: 'initial_diagnosis',
    title: 'Initial Diagnosis Report',
    description: descriptionFromSections([
      ['Chief complaint', row.chiefComplaint],
      ['Symptoms', row.symptoms],
      ['Diagnosis', row.diagnosis],
      ['Treatment plan', row.treatmentPlan],
      ['Nursing instructions', row.nursingInstructions],
      ['Required visits', row.requiredVisits],
    ]),
    role: 'doctor',
    name: row.creatorName,
    source: 'initial_diagnosis_report',
    createdAt: row.createdAt || row.completedAt || row.scheduledAt,
    appointmentId: row.serviceRequestId,
    fileUrl: null,
    aiSummary: null,
  }));
}

async function listLegacyVisitReportsForPatient(patientId) {
  const requiredTables = ['visitreport', 'visit', 'servicerequest'];
  for (const table of requiredTables) {
    if (!(await tableExists(table))) return [];
  }
  const [rows] = await db.query(
    `SELECT r.reportId, r.notes, r.diagnosis,
            sr.requestId, sr.patientUserId, sr.scheduledAt, sr.completedAt,
            u.fullName AS creatorName, u.role AS creatorRole
     FROM visitreport r
     JOIN visit v ON BINARY v.visitId = BINARY r.visitId
     JOIN servicerequest sr ON BINARY sr.requestId = BINARY v.requestId
     LEFT JOIN user u ON BINARY u.userId = BINARY sr.providerUserId
     WHERE BINARY sr.patientUserId = BINARY ?
     ORDER BY COALESCE(sr.completedAt, sr.scheduledAt) DESC`,
    [patientId]
  );
  return rows.map((row) => normalizedRecord({
    id: row.reportId,
    recordType: 'visit_report',
    title: cleanText(row.diagnosis) || 'Visit report',
    description: descriptionFromSections([
      ['Diagnosis', row.diagnosis],
      ['Notes', row.notes],
    ]),
    role: row.creatorRole,
    name: row.creatorName,
    source: 'legacy_visitreport',
    createdAt: row.completedAt || row.scheduledAt,
    appointmentId: row.requestId,
    fileUrl: null,
    aiSummary: null,
  }));
}

async function listNormalizedUploadsForPatient(patientId) {
  const rows = await listPatientMedicalRecordsForPatient(patientId);
  return rows.map((row) => normalizedRecord({
    id: row.id,
    recordType: row.category || 'patient_upload',
    title: row.title || row.file_name || 'Patient upload',
    description: row.description,
    role: 'patient',
    name: 'Patient',
    source: 'patientmedicalfile',
    createdAt: row.created_at || row.createdAt,
    appointmentId: null,
    fileUrl: row.file_url,
    aiSummary: row.aiSummary || row.medical_summary,
  }));
}

async function listPatientVisibleRecords(patientId) {
  const [structured, initial, legacy, uploads] = await Promise.all([
    listNormalizedVisitReportsForPatient(patientId),
    listInitialDiagnosisReportsForPatient(patientId),
    listLegacyVisitReportsForPatient(patientId),
    listNormalizedUploadsForPatient(patientId),
  ]);

  const structuredAppointments = new Set(
    structured
      .filter((record) => record.appointmentId)
      .map((record) => record.appointmentId)
  );
  const structuredInitialAppointments = new Set(
    structured
      .filter(
        (record) =>
          record.appointmentId && record.recordType === 'initial_diagnosis'
      )
      .map((record) => record.appointmentId)
  );
  const compatibleInitial = initial.filter(
    (record) => !structuredInitialAppointments.has(record.appointmentId)
  );
  const compatibleLegacy = legacy.filter(
    (record) => !structuredAppointments.has(record.appointmentId)
  );

  return [...structured, ...compatibleInitial, ...compatibleLegacy, ...uploads]
    .sort((a, b) => {
      const aTime = new Date(a.createdAt || 0).getTime();
      const bTime = new Date(b.createdAt || 0).getTime();
      return bTime - aTime;
    });
}

async function getPatientVisibleRecordById(recordId) {
  let patientId = '';
  if (await tableExists('visit_reports')) {
    const [rows] = await db.query(
      'SELECT patient_id AS patientId FROM visit_reports WHERE BINARY id = BINARY ? LIMIT 1',
      [recordId]
    );
    patientId = cleanText(rows[0]?.patientId);
  }
  if (!patientId && (await tableExists('initial_diagnosis_report'))) {
    const [rows] = await db.query(
      `SELECT sr.patientUserId AS patientId
       FROM initial_diagnosis_report idr
       JOIN servicerequest sr
         ON BINARY sr.requestId = BINARY idr.serviceRequestId
       WHERE BINARY idr.reportId = BINARY ? LIMIT 1`,
      [recordId]
    );
    patientId = cleanText(rows[0]?.patientId);
  }
  if (!patientId && (await tableExists('visitreport'))) {
    const [rows] = await db.query(
      `SELECT sr.patientUserId AS patientId
       FROM visitreport r
       JOIN visit v ON BINARY v.visitId = BINARY r.visitId
       JOIN servicerequest sr ON BINARY sr.requestId = BINARY v.requestId
       WHERE BINARY r.reportId = BINARY ? LIMIT 1`,
      [recordId]
    );
    patientId = cleanText(rows[0]?.patientId);
  }
  if (!patientId && (await tableExists('patientmedicalfile'))) {
    const [rows] = await db.query(
      `SELECT patientUserId AS patientId
       FROM patientmedicalfile
       WHERE BINARY id = BINARY ? LIMIT 1`,
      [recordId]
    );
    patientId = cleanText(rows[0]?.patientId);
  }
  if (!patientId) return null;
  const records = await listPatientVisibleRecords(patientId);
  const record = records.find((item) => item.id === recordId);
  return record ? { patientId, record } : null;
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
  listPatientVisibleRecords,
  getPatientVisibleRecordById,
  getPatientMedicalRecordById,
  insertPatientMedicalRecord,
  deletePatientMedicalRecord,
  updatePatientMedicalRecordAi,
  appointmentLinksPatientProvider,
};

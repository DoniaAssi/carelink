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

module.exports = {
  tableExists,
  hasColumn,
  toDateOnly,
  listVisitReportsForPatient,
  getVisitReportById,
  insertVisitReport,
  appointmentLinksPatientProvider,
};

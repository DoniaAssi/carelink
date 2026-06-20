const { randomUUID } = require('crypto');
const db = require('../db');
const InitialDiagnosisReport = require('../models/initialDiagnosisReportModel');

async function findByServiceRequestId(serviceRequestId, doctorUserId) {
  const params = [serviceRequestId];
  let doctorWhere = '';

  if (doctorUserId) {
    doctorWhere = ' AND BINARY doctorUserId = BINARY ?';
    params.push(doctorUserId);
  }

  const [rows] = await db.query(
    `SELECT *
     FROM initial_diagnosis_report
     WHERE BINARY serviceRequestId = BINARY ?
       ${doctorWhere}
     LIMIT 1`,
    params
  );

  return InitialDiagnosisReport.fromRow(rows[0]);
}

async function create(payload) {
  const reportId = randomUUID();
  const requiredVisits = Number.parseInt(payload.requiredVisits, 10);

  await db.execute(
    `INSERT INTO initial_diagnosis_report
      (reportId, serviceRequestId, doctorUserId, chiefComplaint, symptoms,
       diagnosis, treatmentPlan, nursingInstructions, requiredVisits)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      reportId,
      payload.serviceRequestId,
      payload.doctorUserId,
      payload.chiefComplaint || '',
      payload.symptoms || '',
      payload.diagnosis || '',
      payload.treatmentPlan || '',
      payload.nursingInstructions || '',
      Number.isNaN(requiredVisits) ? 1 : requiredVisits,
    ]
  );

  return findByServiceRequestId(payload.serviceRequestId, payload.doctorUserId);
}

async function listByPatientAndDoctor(patientId, doctorUserId) {
  const [rows] = await db.query(
    `SELECT
       idr.*,
       sr.patientUserId,
       sr.serviceType,
       sr.scheduledAt,
       sr.completedAt,
       u.fullName AS doctorName
     FROM initial_diagnosis_report idr
     JOIN servicerequest sr
       ON BINARY sr.requestId = BINARY idr.serviceRequestId
     LEFT JOIN user u
       ON BINARY u.userId = BINARY idr.doctorUserId
     WHERE BINARY sr.patientUserId = BINARY ?
       AND BINARY sr.providerUserId = BINARY ?
     ORDER BY COALESCE(idr.createdAt, sr.completedAt, sr.scheduledAt) DESC`,
    [patientId, doctorUserId]
  );

  return rows.map((row) => ({
    ...InitialDiagnosisReport.fromRow(row).toJSON(),
    patientUserId: row.patientUserId,
    serviceType: row.serviceType,
    doctorName: row.doctorName,
    reportType: 'Initial Diagnosis',
    reportDate: row.createdAt || row.completedAt || row.scheduledAt,
  }));
}

module.exports = {
  findByServiceRequestId,
  create,
  listByPatientAndDoctor,
};

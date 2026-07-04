-- CareLink Patient Medical Records screenshot fixtures (MySQL/MariaDB).
--
-- Safety properties:
--   * inserts only fixed, clearly identifiable demo IDs;
--   * never updates or deletes existing rows;
--   * uses existing provider accounts;
--   * can be re-run without creating duplicates;
--   * is fully reversible with rollback_patient_medical_records_demo.sql.
--
-- The default below is the active local patient account discovered on
-- 2026-06-29. To target another logged-in patient, replace only this value
-- with session_user_id from the Flutter login session.

SET @demo_patient_id := '6697923c-3c1b-4fab-b4ff-114be1b68fdb';

SET @demo_doctor_id := (
  SELECT userId
  FROM user
  WHERE LOWER(role) = 'doctor'
  ORDER BY
    CASE WHEN fullName = 'Demo Doctor' THEN 0 ELSE 1 END,
    userId
  LIMIT 1
);

SET @demo_nurse_id := (
  SELECT userId
  FROM user
  WHERE LOWER(role) = 'nurse'
  ORDER BY
    CASE WHEN fullName = 'Nurse' THEN 0 ELSE 1 END,
    userId
  LIMIT 1
);

SET @demo_doctor_request_id := 'de000000-0000-4000-8000-000000000001';
SET @demo_initial_id        := 'de100000-0000-4000-8000-000000000001';
SET @demo_doctor_report_id  := 'de200000-0000-4000-8000-000000000001';
SET @demo_nurse_report_id   := 'de300000-0000-4000-8000-000000000001';
SET @demo_upload_id         := 'de400000-0000-4000-8000-000000000001';

START TRANSACTION;

-- A dedicated completed request is required by the existing
-- initial_diagnosis_report -> servicerequest relationship. It is marked as a
-- demo and is removed by the rollback script.
INSERT INTO servicerequest (
  requestId,
  serviceType,
  status,
  notes,
  reasonForVisit,
  scheduledAt,
  confirmedAt,
  completedAt,
  patientUserId,
  providerUserId,
  paymentStatus
)
SELECT
  @demo_doctor_request_id,
  'General Medicine',
  'completed',
  '[CARELINK_MEDREC_DEMO] Screenshot fixture only',
  'Routine wellness assessment and blood pressure review',
  DATE_SUB(NOW(), INTERVAL 12 DAY),
  DATE_SUB(NOW(), INTERVAL 12 DAY),
  DATE_SUB(NOW(), INTERVAL 12 DAY),
  @demo_patient_id,
  @demo_doctor_id,
  'paid'
WHERE EXISTS (
    SELECT 1 FROM patient p
    JOIN user u ON BINARY u.userId = BINARY p.userId
    WHERE BINARY p.userId = BINARY @demo_patient_id
      AND LOWER(u.role) = 'patient'
  )
  AND @demo_doctor_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM servicerequest
    WHERE BINARY requestId = BINARY @demo_doctor_request_id
  );

-- 1. Doctor initial diagnosis.
INSERT INTO initial_diagnosis_report (
  reportId,
  serviceRequestId,
  doctorUserId,
  chiefComplaint,
  symptoms,
  diagnosis,
  treatmentPlan,
  nursingInstructions,
  requiredVisits,
  createdAt,
  updatedAt
)
SELECT
  @demo_initial_id,
  @demo_doctor_request_id,
  @demo_doctor_id,
  'Occasional mild headache after a busy day',
  'Intermittent headache without dizziness, chest pain, or shortness of breath',
  'Mild tension-type headache; no warning signs identified during the assessment',
  'Maintain hydration, regular meals, adequate sleep, and monitor blood pressure twice weekly',
  'Record blood pressure readings and contact the care team if symptoms become persistent or severe',
  2,
  DATE_SUB(NOW(), INTERVAL 12 DAY),
  DATE_SUB(NOW(), INTERVAL 12 DAY)
WHERE EXISTS (
    SELECT 1 FROM servicerequest
    WHERE BINARY requestId = BINARY @demo_doctor_request_id
      AND BINARY patientUserId = BINARY @demo_patient_id
      AND BINARY providerUserId = BINARY @demo_doctor_id
  )
  AND NOT EXISTS (
    SELECT 1 FROM initial_diagnosis_report
    WHERE BINARY reportId = BINARY @demo_initial_id
       OR BINARY serviceRequestId = BINARY @demo_doctor_request_id
  );

-- 2. Doctor visit report. The normalized API uses diagnosis as the title.
INSERT INTO visit_reports (
  id,
  patient_id,
  provider_id,
  appointment_id,
  vital_signs,
  diagnosis,
  treatment_plan,
  recommendations,
  follow_up_required,
  follow_up_date,
  created_at,
  visit_date,
  medications_prescribed,
  allergies_noted
)
SELECT
  @demo_doctor_report_id,
  @demo_patient_id,
  @demo_doctor_id,
  @demo_doctor_request_id,
  '{"bloodPressure":"124/78 mmHg","heartRate":"72 bpm","temperature":"36.7 C","oxygenSaturation":"98%"}',
  'Blood Pressure Follow-up',
  'Home readings were reviewed and remain within the expected range. Continue lifestyle measures and periodic monitoring.',
  'Check blood pressure twice weekly, reduce excess salt, remain active, and arrange routine follow-up in four weeks.',
  1,
  DATE_ADD(CURDATE(), INTERVAL 28 DAY),
  DATE_SUB(NOW(), INTERVAL 6 DAY),
  DATE_SUB(CURDATE(), INTERVAL 6 DAY),
  'No new medication prescribed',
  'No known medication allergies reported'
WHERE EXISTS (
    SELECT 1 FROM patient WHERE BINARY userId = BINARY @demo_patient_id
  )
  AND @demo_doctor_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM visit_reports
    WHERE BINARY id = BINARY @demo_doctor_report_id
  );

-- 3. Nurse care note/report.
INSERT INTO visit_reports (
  id,
  patient_id,
  provider_id,
  appointment_id,
  vital_signs,
  diagnosis,
  treatment_plan,
  recommendations,
  follow_up_required,
  follow_up_date,
  created_at,
  visit_date,
  medications_prescribed,
  allergies_noted
)
SELECT
  @demo_nurse_report_id,
  @demo_patient_id,
  @demo_nurse_id,
  NULL,
  '{"bloodPressure":"122/76 mmHg","heartRate":"70 bpm","temperature":"36.6 C","oxygenSaturation":"99%"}',
  'Home Nursing Care Note',
  'Routine home assessment completed. Vital signs were stable, mobility was independent, and medication organization was reviewed.',
  'Continue hydration, follow the documented medication schedule, and report dizziness, fever, or unusual fatigue.',
  0,
  NULL,
  DATE_SUB(NOW(), INTERVAL 3 DAY),
  DATE_SUB(CURDATE(), INTERVAL 3 DAY),
  'Medication list reviewed; no changes made',
  'No new allergies noted'
WHERE EXISTS (
    SELECT 1 FROM patient WHERE BINARY userId = BINARY @demo_patient_id
  )
  AND @demo_nurse_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM visit_reports
    WHERE BINARY id = BINARY @demo_nurse_report_id
  );

-- 4. Patient-uploaded medical file metadata. This reuses an existing harmless
-- CareLink test PDF in backend/uploads; it contains no real patient document.
INSERT INTO patientmedicalfile (
  id,
  patientUserId,
  title,
  category,
  description,
  uploadDate,
  fileUrl,
  filePath,
  originalName,
  mimeType,
  fileSize,
  uploadedBy,
  uploadedByRole,
  aiProcessed,
  aiStatus,
  aiSummary,
  ocrText,
  analysisTags,
  createdAt,
  updatedAt
)
SELECT
  @demo_upload_id,
  @demo_patient_id,
  'Uploaded Lab Result',
  'lab_result',
  'Demo complete blood count result uploaded by the patient for care-team review.',
  DATE_SUB(NOW(), INTERVAL 1 DAY),
  '/uploads/1780591285028-kj09dda9pqf-ai-verify-real.pdf',
  '/uploads/1780591285028-kj09dda9pqf-ai-verify-real.pdf',
  'demo-lab-result.pdf',
  'application/pdf',
  606,
  @demo_patient_id,
  'patient',
  1,
  'processed',
  'Demo laboratory summary: blood counts are within typical reference ranges. This fixture is not medical advice and contains no real patient data.',
  'DEMO LAB RESULT. Hemoglobin 13.8 g/dL; WBC 6.4 x10^9/L; Platelets 248 x10^9/L. Screenshot fixture only.',
  '["lab result","complete blood count","routine follow-up","demo"]',
  DATE_SUB(NOW(), INTERVAL 1 DAY),
  DATE_SUB(NOW(), INTERVAL 1 DAY)
WHERE EXISTS (
    SELECT 1 FROM patient WHERE BINARY userId = BINARY @demo_patient_id
  )
  AND NOT EXISTS (
    SELECT 1 FROM patientmedicalfile
    WHERE BINARY id = BINARY @demo_upload_id
  );

COMMIT;

-- Database verification in the same normalized shape returned by
-- GET /medical-records/patient/:patientId.
SELECT
  idr.reportId AS id,
  'initial_diagnosis' AS recordType,
  'Initial Diagnosis Report' AS title,
  idr.diagnosis AS description,
  'doctor' AS creatorRole,
  u.fullName AS creatorName,
  'initial_diagnosis_report' AS source,
  idr.createdAt AS createdAt,
  idr.serviceRequestId AS appointmentId,
  NULL AS fileUrl,
  NULL AS aiSummary
FROM initial_diagnosis_report idr
LEFT JOIN user u ON BINARY u.userId = BINARY idr.doctorUserId
WHERE BINARY idr.reportId = BINARY @demo_initial_id;

SELECT
  vr.id,
  'visit_report' AS recordType,
  vr.diagnosis AS title,
  vr.treatment_plan AS description,
  LOWER(u.role) AS creatorRole,
  u.fullName AS creatorName,
  'visit_reports' AS source,
  vr.created_at AS createdAt,
  vr.appointment_id AS appointmentId,
  NULL AS fileUrl,
  NULL AS aiSummary
FROM visit_reports vr
LEFT JOIN user u ON BINARY u.userId = BINARY vr.provider_id
WHERE BINARY vr.id = BINARY @demo_doctor_report_id
   OR BINARY vr.id = BINARY @demo_nurse_report_id;

SELECT
  pmf.id,
  pmf.category AS recordType,
  pmf.title,
  pmf.description,
  'patient' AS creatorRole,
  'Patient' AS creatorName,
  'patientmedicalfile' AS source,
  pmf.uploadDate AS createdAt,
  NULL AS appointmentId,
  pmf.filePath AS fileUrl,
  pmf.aiSummary
FROM patientmedicalfile pmf
WHERE BINARY pmf.id = BINARY @demo_upload_id;

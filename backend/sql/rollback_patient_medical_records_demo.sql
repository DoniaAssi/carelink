-- Removes only rows created by seed_patient_medical_records_demo.sql.
-- It does not delete or modify users, providers, or pre-existing records.

SET @demo_doctor_request_id := 'de000000-0000-4000-8000-000000000001';
SET @demo_initial_id        := 'de100000-0000-4000-8000-000000000001';
SET @demo_doctor_report_id  := 'de200000-0000-4000-8000-000000000001';
SET @demo_nurse_report_id   := 'de300000-0000-4000-8000-000000000001';
SET @demo_upload_id         := 'de400000-0000-4000-8000-000000000001';

START TRANSACTION;

DELETE FROM patientmedicalfile
WHERE BINARY id = BINARY @demo_upload_id;

DELETE FROM visit_reports
WHERE BINARY id = BINARY @demo_doctor_report_id
   OR BINARY id = BINARY @demo_nurse_report_id;

DELETE FROM initial_diagnosis_report
WHERE BINARY reportId = BINARY @demo_initial_id;

DELETE FROM servicerequest
WHERE BINARY requestId = BINARY @demo_doctor_request_id
  AND notes = '[CARELINK_MEDREC_DEMO] Screenshot fixture only';

COMMIT;

-- A successful rollback returns remainingDemoRows = 0.
SELECT
  (SELECT COUNT(*) FROM initial_diagnosis_report
   WHERE BINARY reportId = BINARY @demo_initial_id)
  +
  (SELECT COUNT(*) FROM visit_reports
   WHERE BINARY id = BINARY @demo_doctor_report_id
      OR BINARY id = BINARY @demo_nurse_report_id)
  +
  (SELECT COUNT(*) FROM patientmedicalfile
   WHERE BINARY id = BINARY @demo_upload_id)
  +
  (SELECT COUNT(*) FROM servicerequest
   WHERE BINARY requestId = BINARY @demo_doctor_request_id)
  AS remainingDemoRows;

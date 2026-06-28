-- Phase 2 patient-visible doctor/nurse report fixtures.
-- Re-runnable: fixed IDs and NOT EXISTS guards prevent duplicates.
-- Uses existing users only and does not change appointment status or old data.

SET @phase2_patient_id := (
  SELECT userId FROM patient ORDER BY userId LIMIT 1
);
SET @phase2_doctor_id := (
  SELECT userId FROM user WHERE LOWER(role) = 'doctor' ORDER BY userId LIMIT 1
);
SET @phase2_nurse_id := (
  SELECT userId FROM user WHERE LOWER(role) = 'nurse' ORDER BY userId LIMIT 1
);
SET @phase2_doctor_appointment_id := (
  SELECT requestId
  FROM servicerequest
  WHERE patientUserId = @phase2_patient_id
    AND providerUserId = @phase2_doctor_id
  ORDER BY COALESCE(completedAt, confirmedAt, scheduledAt) DESC
  LIMIT 1
);
SET @phase2_nurse_appointment_id := (
  SELECT requestId
  FROM servicerequest
  WHERE patientUserId = @phase2_patient_id
    AND providerUserId = @phase2_nurse_id
  ORDER BY COALESCE(completedAt, confirmedAt, scheduledAt) DESC
  LIMIT 1
);

INSERT INTO visit_reports (
  id, patient_id, provider_id, appointment_id, vital_signs,
  diagnosis, treatment_plan, recommendations,
  follow_up_required, follow_up_date, created_at
)
SELECT
  'f2000000-0000-4000-8000-000000000001',
  @phase2_patient_id,
  @phase2_doctor_id,
  @phase2_doctor_appointment_id,
  '{"bp":"120/80","hr":72}',
  'Phase 2 doctor follow-up report',
  'Continue the documented care plan and follow up as scheduled.',
  'Contact the care team if symptoms change.',
  0,
  NULL,
  NOW()
WHERE @phase2_patient_id IS NOT NULL
  AND @phase2_doctor_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM visit_reports
    WHERE id = 'f2000000-0000-4000-8000-000000000001'
  );

INSERT INTO visit_reports (
  id, patient_id, provider_id, appointment_id, vital_signs,
  diagnosis, treatment_plan, recommendations,
  follow_up_required, follow_up_date, created_at
)
SELECT
  'f2000000-0000-4000-8000-000000000002',
  @phase2_patient_id,
  @phase2_nurse_id,
  @phase2_nurse_appointment_id,
  '{"temperatureC":36.7,"oxygenPercent":98}',
  'Phase 2 nursing visit report',
  'Routine nursing observations and care were documented.',
  'Continue provider instructions and scheduled follow-up.',
  0,
  NULL,
  NOW()
WHERE @phase2_patient_id IS NOT NULL
  AND @phase2_nurse_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM visit_reports
    WHERE id = 'f2000000-0000-4000-8000-000000000002'
  );

SELECT id, patient_id, provider_id, appointment_id, diagnosis, created_at
FROM visit_reports
WHERE id IN (
  'f2000000-0000-4000-8000-000000000001',
  'f2000000-0000-4000-8000-000000000002'
)
ORDER BY id;

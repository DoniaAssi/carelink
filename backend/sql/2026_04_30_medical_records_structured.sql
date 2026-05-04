-- Official visit reports (provider-authored). Run once per environment.

CREATE TABLE IF NOT EXISTS visit_reports (
  id CHAR(36) NOT NULL PRIMARY KEY,
  patient_id CHAR(36) NOT NULL,
  provider_id CHAR(36) NOT NULL,
  appointment_id CHAR(36) NULL,
  vital_signs TEXT NULL,
  diagnosis TEXT NULL,
  treatment_plan TEXT NULL,
  recommendations TEXT NULL,
  follow_up_required TINYINT(1) NOT NULL DEFAULT 0,
  follow_up_date DATE NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_vr_patient (patient_id),
  KEY idx_vr_provider (provider_id),
  KEY idx_vr_appt (appointment_id)
);

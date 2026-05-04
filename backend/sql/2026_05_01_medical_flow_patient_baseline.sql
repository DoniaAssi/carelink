-- Patient baseline columns (run once; ignore "Duplicate column" errors if re-run).

ALTER TABLE patient ADD COLUMN chronicDiseases TEXT NULL;
ALTER TABLE patient ADD COLUMN allergies TEXT NULL;
ALTER TABLE patient ADD COLUMN currentMedications TEXT NULL;

-- Visit report extensions
ALTER TABLE visit_reports ADD COLUMN visit_date DATE NULL;
ALTER TABLE visit_reports ADD COLUMN medications_prescribed TEXT NULL;
ALTER TABLE visit_reports ADD COLUMN allergies_noted TEXT NULL;

-- Booking urgency label
ALTER TABLE servicerequest ADD COLUMN urgencyLevel VARCHAR(32) NULL;

-- Removes only the Phase 2 fixtures created by seed_phase2_medical_records.sql.

DELETE FROM visit_reports
WHERE id IN (
  'f2000000-0000-4000-8000-000000000001',
  'f2000000-0000-4000-8000-000000000002'
);

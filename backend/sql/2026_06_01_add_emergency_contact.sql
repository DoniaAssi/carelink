-- Add emergencyContact column to patient table if it does not exist.
ALTER TABLE patient ADD COLUMN IF NOT EXISTS emergencyContact VARCHAR(255) NULL;

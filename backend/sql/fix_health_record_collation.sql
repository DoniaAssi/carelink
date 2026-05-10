-- =============================================================================
-- CareLink — fix_health_record_collation.sql
-- =============================================================================
-- Normalizes charset/collation for Health Record–related data so text JOINs
-- and WHERE comparisons do not mix utf8mb4_general_ci with utf8mb4_unicode_ci.
--
-- HOW TO RUN (replace credentials / database name as needed):
--   mysql -u root -p carelink < backend/sql/fix_health_record_collation.sql
--
-- Or in a client:
--   USE your_database_name;
--   SOURCE backend/sql/fix_health_record_collation.sql;
--
-- Requires: ALTER privilege on the database and listed tables.
--
-- -----------------------------------------------------------------------------
-- WHAT ACTUALLY FAILED (this codebase)
-- -----------------------------------------------------------------------------
-- 1) Timeline tab → GET /patient/appointments/history/:patientUserId
--    (backend/routes/patient.js)
--    JOIN: servicerequest.providerUserId = user.userId
--          servicerequest.patientUserId = user.userId
--    When `servicerequest` defaulted to utf8mb4_general_ci and `user` to
--    utf8mb4_unicode_ci (or the reverse), MySQL throws on '=' for that JOIN.
--
-- 2) Records tab → GET /medical-records/patient/:id via medicalRecordService
--    (backend/services/medicalRecordService.js)
--    JOIN: user.userId = visit_reports.provider_id
--    WHERE: visit_reports.patient_id = ? (can also mix if column vs connection)
--
-- 3) Profile tab → GET /patient/profile/:userId
--    JOIN: user.userId = patient.userId
--
-- After this script, all listed tables use utf8mb4 + utf8mb4_unicode_ci at the
-- table level; the Node app also sets SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci
-- on each pool connection (backend/db.js).
--
-- Full-app normalization (broader table list) lives in:
--   backend/sql/2026_05_07_utf8mb4_unicode_ci_normalize.mysql.sql
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Default charset for new objects in the *current* database (run USE db first).
SET @dbname = DATABASE();
SET @alterdb = IF(
  @dbname IS NOT NULL AND @dbname <> '',
  CONCAT(
    'ALTER DATABASE `',
    REPLACE(@dbname, '`', '``'),
    '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
  ),
  'SELECT "ERROR: No database selected. Run USE your_database_name;" AS message'
);
PREPARE _carelink_alterdb FROM @alterdb;
EXECUTE _carelink_alterdb;
DEALLOCATE PREPARE _carelink_alterdb;

-- Optional explicit name (uncomment if you prefer a fixed database literal):
-- ALTER DATABASE `carelink` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS carelink_fix_health_record_tables;

DELIMITER $$

CREATE PROCEDURE carelink_fix_health_record_tables()
BEGIN
  DECLARE t VARCHAR(128);
  DECLARE v_done INT DEFAULT 0;

  DECLARE cur CURSOR FOR
    SELECT tbl FROM (
      -- Core identity & profile (Profile tab, all JOINs on userId)
      SELECT 'user' AS tbl
      UNION ALL SELECT 'patient'
      UNION ALL SELECT 'careprovider'
      UNION ALL SELECT 'doctor'
      UNION ALL SELECT 'nurse'
      -- Structured medical record / ICD-style link tables (Records tab)
      UNION ALL SELECT 'medicalrecord'
      UNION ALL SELECT 'medicalrecorddisease'
      UNION ALL SELECT 'disease'
      UNION ALL SELECT 'medicalrecordallergy'
      UNION ALL SELECT 'allergy'
      -- Visit reports (Records tab)
      UNION ALL SELECT 'visit_reports'
      -- Bookings / timeline (Timeline tab)
      UNION ALL SELECT 'servicerequest'
      -- Ratings & payments often loaded with visits
      UNION ALL SELECT 'providervisitrating'
      UNION ALL SELECT 'payment'
      UNION ALL SELECT 'payments'
      -- Favorites / holds touched from patient flows
      UNION ALL SELECT 'patient_provider_favorite'
      UNION ALL SELECT 'user_account_hold'
      -- Scheduling (provider context)
      UNION ALL SELECT 'availabilityslot'
      -- Messaging (optional; safe if table missing)
      UNION ALL SELECT 'message'
    ) AS carelink_health_targets;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  SET FOREIGN_KEY_CHECKS = 0;

  OPEN cur;
  read_tables: LOOP
    FETCH cur INTO t;
    IF v_done THEN
      LEAVE read_tables;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = t
      LIMIT 1
    ) THEN
      SET @q = CONCAT(
        'ALTER TABLE `',
        REPLACE(t, '`', '``'),
        '` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
      );
      PREPARE _conv FROM @q;
      EXECUTE _conv;
      DEALLOCATE PREPARE _conv;
    END IF;

  END LOOP read_tables;

  CLOSE cur;
  SET FOREIGN_KEY_CHECKS = 1;
END$$

DELIMITER ;

CALL carelink_fix_health_record_tables();

DROP PROCEDURE IF EXISTS carelink_fix_health_record_tables;

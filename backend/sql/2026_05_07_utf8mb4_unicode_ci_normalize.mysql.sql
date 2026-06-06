-- CareLink — normalize MySQL / MariaDB text collations across app tables.
--
-- Symptoms fixed:
--   Illegal mix of collations (utf8mb4_general_ci,IMPLICIT) and (utf8mb4_unicode_ci,IMPLICIT) for operation '='
--
-- Typical failing queries in this codebase:
--   LEFT JOIN user u ON u.userId = vr.provider_id          (visit_reports + user)
--   JOIN disease d ON mrd.diseaseId = d.diseaseId          (medicalrecorddisease + disease)
--   JOIN allergy a ON mra.allergyId = a.allergyId          (medicalrecordallergy + allergy)
--
-- Run against your CareLink database (same as DB_NAME in backend/.env):
--   mysql -u root -p carelink < backend/sql/2026_05_07_utf8mb4_unicode_ci_normalize.mysql.sql
--
-- Or: open MySQL client, run  USE your_database;  then paste this file.
--
-- Requires: ALTER privilege on the database and listed tables.

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Default charset for new objects in the current database
SET @dbname = DATABASE();
SET @alterdb = IF(
  @dbname IS NOT NULL AND @dbname <> '',
  CONCAT(
    'ALTER DATABASE `',
    REPLACE(@dbname, '`', '``'),
    '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
  ),
  'SELECT "ERROR: No database selected. Run USE <db>;" AS message'
);
PREPARE _carelink_alterdb FROM @alterdb;
EXECUTE _carelink_alterdb;
DEALLOCATE PREPARE _carelink_alterdb;

DROP PROCEDURE IF EXISTS carelink_utf8mb4_normalize_listed_tables;

DELIMITER $$

CREATE PROCEDURE carelink_utf8mb4_normalize_listed_tables()
BEGIN
  DECLARE t VARCHAR(128);
  DECLARE v_done INT DEFAULT 0;

  DECLARE cur CURSOR FOR
    SELECT tbl FROM (
      SELECT 'user' AS tbl
      UNION ALL SELECT 'patient'
      UNION ALL SELECT 'careprovider'
      UNION ALL SELECT 'doctor'
      UNION ALL SELECT 'nurse'
      UNION ALL SELECT 'medicalrecord'
      UNION ALL SELECT 'medicalrecorddisease'
      UNION ALL SELECT 'disease'
      UNION ALL SELECT 'medicalrecordallergy'
      UNION ALL SELECT 'allergy'
      UNION ALL SELECT 'visit_reports'
      UNION ALL SELECT 'servicerequest'
      UNION ALL SELECT 'payment'
      UNION ALL SELECT 'payments'
      UNION ALL SELECT 'providervisitrating'
      UNION ALL SELECT 'provider_certification'
      UNION ALL SELECT 'availabilityslot'
      UNION ALL SELECT 'provider_payment_method'
      UNION ALL SELECT 'nurse_appsettings'
      UNION ALL SELECT 'usernotification'
      UNION ALL SELECT 'email_verification_codes'
      UNION ALL SELECT 'signup_verification_proof'
      UNION ALL SELECT 'patient_provider_favorite'
      UNION ALL SELECT 'user_account_hold'
    ) AS carelink_table_targets;

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

CALL carelink_utf8mb4_normalize_listed_tables();

DROP PROCEDURE IF EXISTS carelink_utf8mb4_normalize_listed_tables;

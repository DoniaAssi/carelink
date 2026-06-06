-- CareLink — Email OTP registration flow (MySQL / MariaDB)
-- Run manually or via your migration runner.

-- If this fails with "Duplicate column name", is_verified already exists.
ALTER TABLE user ADD COLUMN is_verified TINYINT(1) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS email_verification_codes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email VARCHAR(320) NOT NULL,
  otp_hash VARCHAR(255) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  used_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  INDEX idx_email_created (email, created_at),
  INDEX idx_email_active (email, used_at, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

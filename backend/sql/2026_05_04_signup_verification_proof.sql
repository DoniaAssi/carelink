-- Persists email/phone signup verification tokens across server restarts.
-- (Table is also auto-created by signupVerificationProof.js if missing.)

CREATE TABLE IF NOT EXISTS signup_verification_proof (
  proofToken VARCHAR(64) NOT NULL,
  channel ENUM('email', 'phone') NOT NULL,
  subject VARCHAR(320) NOT NULL,
  expiresAt BIGINT NOT NULL,
  PRIMARY KEY (proofToken),
  KEY idx_expires (expiresAt)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

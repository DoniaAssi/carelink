-- Patient favorite providers and soft account hold (used by /patient/favorites/* and /auth/deactivate-account).
-- Tables are also auto-created by the Node app on first use; this file is for manual DBA setup.

CREATE TABLE IF NOT EXISTS patient_provider_favorite (
  patientUserId VARCHAR(64) NOT NULL,
  providerUserId VARCHAR(64) NOT NULL,
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (patientUserId, providerUserId),
  KEY idx_ppf_provider (providerUserId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_account_hold (
  userId VARCHAR(64) PRIMARY KEY,
  deactivatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

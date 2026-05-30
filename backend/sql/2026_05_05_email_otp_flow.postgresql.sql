-- CareLink — Email OTP registration flow (PostgreSQL)

ALTER TABLE "user"
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS email_verification_codes (
  id BIGSERIAL PRIMARY KEY,
  email VARCHAR(320) NOT NULL,
  otp_hash VARCHAR(255) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_verification_codes_email_created
  ON email_verification_codes (email, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_email_verification_codes_active
  ON email_verification_codes (email)
  WHERE used_at IS NULL;

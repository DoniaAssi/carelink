const bcrypt = require('bcrypt');
const crypto = require('crypto');
const db = require('../db');
const { dispatchEmailVerificationCode } = require('./verificationDispatch');

const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes
const RESEND_INTERVAL_MS = 60 * 1000; // 60 seconds
const BCRYPT_ROUNDS_OTP = 10;

function generateSixDigitCode() {
  return String(crypto.randomInt(100000, 1000000));
}

async function ensureEmailVerificationTable() {
  await db.query(`
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
}

async function userHasVerifiedColumn() {
  try {
    const [rows] = await db.query('SHOW COLUMNS FROM user LIKE ?', ['is_verified']);
    return rows.length > 0;
  } catch (_) {
    return false;
  }
}

/**
 * @param {string} normalizedEmail
 * @returns {Promise<{ plainCode: string }>}
 */
async function issueOtpForEmail(normalizedEmail) {
  await ensureEmailVerificationTable();

  const [recent] = await db.query(
    `SELECT created_at FROM email_verification_codes
     WHERE email = ? ORDER BY id DESC LIMIT 1`,
    [normalizedEmail],
  );

  if (recent.length > 0) {
    const last = new Date(recent[0].created_at).getTime();
    const delta = Date.now() - last;
    if (delta >= 0 && delta < RESEND_INTERVAL_MS) {
      const wait = Math.ceil((RESEND_INTERVAL_MS - delta) / 1000);
      const err = new Error(`Please wait ${wait} seconds before requesting a new code`);
      err.statusCode = 429;
      err.retryAfterSeconds = wait;
      throw err;
    }
  }

  const plainCode = generateSixDigitCode();
  const otpHash = await bcrypt.hash(plainCode, BCRYPT_ROUNDS_OTP);
  const expiresAt = new Date(Date.now() + OTP_TTL_MS);

  await db.query(
    `INSERT INTO email_verification_codes (email, otp_hash, expires_at)
     VALUES (?, ?, ?)`,
    [normalizedEmail, otpHash, expiresAt],
  );

  return { plainCode };
}

/**
 * @param {string} normalizedEmail
 * @param {string} plainCode
 */
async function verifyOtpAndConsume(normalizedEmail, plainCode) {
  await ensureEmailVerificationTable();

  const [rows] = await db.query(
    `SELECT id, otp_hash, expires_at, used_at
     FROM email_verification_codes
     WHERE email = ? AND used_at IS NULL
     ORDER BY id DESC
     LIMIT 5`,
    [normalizedEmail],
  );

  const now = new Date();
  const code = String(plainCode || '').trim();

  for (const row of rows) {
    if (new Date(row.expires_at) < now) continue;
    const ok = await bcrypt.compare(code, row.otp_hash);
    if (ok) {
      await db.query(
        'UPDATE email_verification_codes SET used_at = ? WHERE id = ?',
        [now, row.id],
      );
      return { matchedId: row.id };
    }
  }

  const err = new Error('Invalid or expired verification code');
  err.statusCode = 400;
  throw err;
}

async function sendOtpEmail(normalizedEmail, plainCode) {
  return dispatchEmailVerificationCode({
    to: normalizedEmail,
    code: plainCode,
    purpose: 'signup',
  });
}

module.exports = {
  ensureEmailVerificationTable,
  userHasVerifiedColumn,
  issueOtpForEmail,
  verifyOtpAndConsume,
  sendOtpEmail,
  OTP_TTL_MS,
  RESEND_INTERVAL_MS,
};

const bcrypt = require('bcrypt');
const crypto = require('crypto');

const CODE_TTL_MS = 5 * 60 * 1000;
const RESEND_INTERVAL_MS = 30 * 1000;
const MAX_WRONG_ATTEMPTS = 5;
const BCRYPT_ROUNDS = 10;

/** @type {Map<string, { codeHash: string, debugCode?: string, expiresAt: number, attempts: number, lastSentAt: number, verifiedAt?: number }>} */
const challenges = new Map();
const OTP_DEBUG_LOGS =
  process.env.NODE_ENV !== 'production' && process.env.OTP_DEBUG_LOGS !== '0';

function storageKey(channel, target, purpose) {
  const normalizedTarget = channel === 'email'
    ? (target || '').toString().trim().toLowerCase()
    : (target || '').toString().replace(/\D/g, '');
  const normalizedPurpose = (purpose || '').toString().trim().toLowerCase();
  return `${channel}:${normalizedTarget}:${normalizedPurpose}`;
}

function pruneExpired() {
  const now = Date.now();
  for (const [k, v] of challenges.entries()) {
    if (v.expiresAt < now) challenges.delete(k);
  }
}

function generateSixDigitCode() {
  return String(crypto.randomInt(100000, 1000000));
}

/**
 * @param {'email'|'phone'} channel
 * @param {string} target normalized email or phone digits
 * @param {'signup'|'password_reset'} purpose
 * @returns {{ plainCode: string, retryAfterSeconds?: number }}
 */
async function startChallenge(channel, target, purpose) {
  pruneExpired();
  const k = storageKey(channel, target, purpose);
  const now = Date.now();
  const existing = challenges.get(k);
  if (existing && existing.expiresAt > now) {
    const sinceSend = now - existing.lastSentAt;
    if (sinceSend < RESEND_INTERVAL_MS) {
      const retrySec = Math.ceil((RESEND_INTERVAL_MS - sinceSend) / 1000);
      const err = new Error(
        `Please wait ${retrySec} seconds before requesting another code`,
      );
      err.statusCode = 429;
      err.retryAfterSeconds = retrySec;
      throw err;
    }
  }

  const plainCode = generateSixDigitCode();
  const codeHash = await bcrypt.hash(plainCode, BCRYPT_ROUNDS);
  const previousInvalidated = challenges.delete(k);
  challenges.set(k, {
    codeHash,
    ...(OTP_DEBUG_LOGS ? { debugCode: plainCode } : {}),
    expiresAt: now + CODE_TTL_MS,
    attempts: 0,
    lastSentAt: now,
  });
  if (OTP_DEBUG_LOGS) {
    console.log('[OTP SEND]', {
      key: k,
      email: channel === 'email' ? target : undefined,
      storedOtp: plainCode,
      expirationTime: new Date(now + CODE_TTL_MS).toISOString(),
      currentTime: new Date(now).toISOString(),
      previousInvalidated,
    });
  }
  return { plainCode };
}

/**
 * @param {'email'|'phone'} channel
 */
async function completeChallenge(channel, target, purpose, rawCode) {
  pruneExpired();
  const k = storageKey(channel, target, purpose);
  const ch = challenges.get(k);
  const code = (rawCode || '').toString().trim();
  const now = Date.now();

  if (OTP_DEBUG_LOGS) {
    console.log('[OTP VERIFY]', {
      key: k,
      email: channel === 'email' ? target : undefined,
      enteredOtp: code,
      storedOtp: ch?.debugCode ?? '(stored as bcrypt hash)',
      storedOtpHash: ch?.codeHash,
      expirationTime: ch ? new Date(ch.expiresAt).toISOString() : null,
      currentTime: new Date(now).toISOString(),
      attempts: ch?.attempts ?? null,
      previouslyVerifiedAt: ch?.verifiedAt
        ? new Date(ch.verifiedAt).toISOString()
        : null,
    });
  }

  if (!ch || ch.expiresAt < now) {
    const err = new Error('Invalid or expired code');
    err.statusCode = 400;
    throw err;
  }

  const match = await bcrypt.compare(code, ch.codeHash);
  if (!match) {
    ch.attempts += 1;
    if (ch.attempts >= MAX_WRONG_ATTEMPTS) {
      challenges.delete(k);
      const err = new Error(
        'Too many invalid attempts. Request a new verification code.',
      );
      err.statusCode = 400;
      throw err;
    }
    const err = new Error('Invalid verification code');
    err.statusCode = 400;
    throw err;
  }

  // Keep the latest successfully verified challenge until expiry. This makes
  // signup retry-safe when account creation fails after OTP verification.
  ch.verifiedAt = now;
  return true;
}

function invalidateChallenge(channel, target, purpose) {
  return challenges.delete(storageKey(channel, target, purpose));
}

function getChallengeDebugInfo(channel, target, purpose) {
  const ch = challenges.get(storageKey(channel, target, purpose));
  if (!ch) return null;
  return {
    storedOtp: OTP_DEBUG_LOGS ? ch.debugCode : undefined,
    storedOtpHash: ch.codeHash,
    expirationTime: new Date(ch.expiresAt).toISOString(),
    lastSentAt: new Date(ch.lastSentAt).toISOString(),
    attempts: ch.attempts,
    verifiedAt: ch.verifiedAt ? new Date(ch.verifiedAt).toISOString() : null,
  };
}

module.exports = {
  startChallenge,
  completeChallenge,
  invalidateChallenge,
  getChallengeDebugInfo,
  generateSixDigitCode,
  CODE_TTL_MS,
  RESEND_INTERVAL_MS,
  MAX_WRONG_ATTEMPTS,
};

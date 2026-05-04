const bcrypt = require('bcrypt');
const crypto = require('crypto');

const CODE_TTL_MS = 5 * 60 * 1000;
const RESEND_INTERVAL_MS = 30 * 1000;
const MAX_WRONG_ATTEMPTS = 5;
const BCRYPT_ROUNDS = 10;

/** @type {Map<string, { codeHash: string, expiresAt: number, attempts: number, lastSentAt: number }>} */
const challenges = new Map();

function storageKey(channel, target, purpose) {
  return `${channel}:${target}:${purpose}`;
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
  challenges.set(k, {
    codeHash,
    expiresAt: now + CODE_TTL_MS,
    attempts: 0,
    lastSentAt: now,
  });
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

  if (!ch || ch.expiresAt < Date.now()) {
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

  challenges.delete(k);
  return true;
}

module.exports = {
  startChallenge,
  completeChallenge,
  generateSixDigitCode,
  CODE_TTL_MS,
  RESEND_INTERVAL_MS,
  MAX_WRONG_ATTEMPTS,
};

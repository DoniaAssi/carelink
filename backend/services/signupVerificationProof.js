const db = require('../db');

let tableEnsured = false;

async function ensureTable() {
  if (tableEnsured) return;
  await db.query(`
    CREATE TABLE IF NOT EXISTS signup_verification_proof (
      proofToken VARCHAR(64) NOT NULL,
      channel ENUM('email', 'phone') NOT NULL,
      subject VARCHAR(320) NOT NULL,
      expiresAt BIGINT NOT NULL,
      PRIMARY KEY (proofToken),
      KEY idx_expires (expiresAt)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
  tableEnsured = true;
}

async function pruneExpired() {
  await ensureTable();
  await db.query('DELETE FROM signup_verification_proof WHERE expiresAt < ?', [
    Date.now(),
  ]);
}

/**
 * @param {'email' | 'phone'} channel
 * @param {string} proofToken hex from randomBytes(32).toString('hex')
 * @param {string} subject normalized email (lowercase) or phone digits only
 * @param {number} expiresAtMs Date.now() + TTL
 */
async function saveProof(channel, proofToken, subject, expiresAtMs) {
  await ensureTable();
  await pruneExpired();
  await db.query(
    `INSERT INTO signup_verification_proof (proofToken, channel, subject, expiresAt)
     VALUES (?, ?, ?, ?)`,
    [proofToken, channel, subject, expiresAtMs],
  );
}

/**
 * Peek at a proof without deleting (used during /register validation).
 * @returns {Promise<{ subject: string, expiresAt: number } | null>}
 */
async function getValidProof(channel, proofToken) {
  await ensureTable();
  const [rows] = await db.query(
    `SELECT subject, expiresAt FROM signup_verification_proof
     WHERE proofToken = ? AND channel = ?`,
    [proofToken, channel],
  );
  if (!rows.length) return null;
  const expiresAt = Number(rows[0].expiresAt);
  if (!Number.isFinite(expiresAt) || expiresAt < Date.now()) {
    await db.query(
      'DELETE FROM signup_verification_proof WHERE proofToken = ?',
      [proofToken],
    );
    return null;
  }
  return { subject: String(rows[0].subject || ''), expiresAt };
}

async function deleteProof(proofToken) {
  await ensureTable();
  await db.query('DELETE FROM signup_verification_proof WHERE proofToken = ?', [
    proofToken,
  ]);
}

module.exports = {
  ensureTable,
  saveProof,
  getValidProof,
  deleteProof,
  pruneExpired,
};

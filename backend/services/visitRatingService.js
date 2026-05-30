'use strict';

const { randomUUID } = require('crypto');
const db = require('../db');

let ratingsTableCache = null;
let ratingsCountColumnCache = null;
let providerReviewTableCache = null;

async function ratingsTableExists() {
  if (ratingsTableCache !== null) return ratingsTableCache;
  try {
    const [rows] = await db.query(
      "SHOW TABLES LIKE 'providervisitrating'",
    );
    ratingsTableCache = rows.length > 0;
    return ratingsTableCache;
  } catch (_) {
    ratingsTableCache = false;
    return false;
  }
}

async function careproviderHasRatingsCount() {
  if (ratingsCountColumnCache !== null) return ratingsCountColumnCache;
  try {
    const [rows] = await db.query(
      "SHOW COLUMNS FROM careprovider LIKE 'ratingsCount'",
    );
    ratingsCountColumnCache = rows.length > 0;
    return ratingsCountColumnCache;
  } catch (_) {
    ratingsCountColumnCache = false;
    return false;
  }
}

async function providerReviewTableExists() {
  if (providerReviewTableCache !== null) return providerReviewTableCache;
  try {
    const [rows] = await db.query("SHOW TABLES LIKE 'providerreview'");
    providerReviewTableCache = rows.length > 0;
    return providerReviewTableCache;
  } catch (_) {
    providerReviewTableCache = false;
    return false;
  }
}

/**
 * Recompute average + count from providervisitrating and persist on careprovider.
 * @returns {{ averageRating: number, ratingsCount: number }}
 */
async function recomputeProviderRatingStats(providerUserId) {
  const [agg] = await db.query(
    `SELECT AVG(stars) AS a, COUNT(*) AS c
     FROM providervisitrating
     WHERE providerUserId = ?`,
    [providerUserId],
  );
  const cnt = Number(agg[0]?.c || 0);
  const raw = agg[0]?.a;
  const value = cnt === 0 ? 0 : Math.round(Number(raw) * 100) / 100;
  const hasRc = await careproviderHasRatingsCount();
  if (hasRc) {
    await db.execute(
      `UPDATE careprovider SET overallRating = ?, ratingsCount = ? WHERE userId = ?`,
      [value, cnt, providerUserId],
    );
  } else {
    await db.execute(
      `UPDATE careprovider SET overallRating = ? WHERE userId = ?`,
      [value, providerUserId],
    );
  }
  return { averageRating: value, ratingsCount: cnt };
}

async function submitPatientVisitRating({
  appointmentId,
  patientUserId,
  stars,
  comment,
}) {
  if (!patientUserId) {
    const e = new Error('patientUserId is required');
    e.status = 400;
    throw e;
  }
  if (!appointmentId) {
    const e = new Error('appointmentId is required');
    e.status = 400;
    throw e;
  }

  const s = Math.round(Number(stars));
  if (!Number.isFinite(s) || s < 1 || s > 5) {
    const e = new Error('stars must be between 1 and 5');
    e.status = 400;
    throw e;
  }

  if (!(await ratingsTableExists())) {
    const e = new Error(
      'Ratings are not available; run the providervisitrating migration.',
    );
    e.status = 501;
    throw e;
  }

  const commentText =
    comment != null ? String(comment).trim().slice(0, 2000) : '';

  const [rows] = await db.query(
    `SELECT requestId, patientUserId, providerUserId, status
     FROM servicerequest
     WHERE requestId = ?`,
    [appointmentId],
  );

  if (rows.length === 0) {
    const e = new Error('Appointment not found');
    e.status = 404;
    throw e;
  }

  const row = rows[0];
  if (row.patientUserId !== patientUserId) {
    const e = new Error('Not allowed');
    e.status = 403;
    throw e;
  }

  if ((row.status || '').toString().toLowerCase() !== 'completed') {
    const e = new Error('You can only rate after the visit is completed');
    e.status = 409;
    throw e;
  }

  const [existing] = await db.query(
    'SELECT ratingId FROM providervisitrating WHERE TRIM(requestId) = TRIM(?)',
    [appointmentId],
  );

  if (existing.length > 0) {
    const e = new Error('This visit is already rated');
    e.status = 409;
    throw e;
  }

  if (await legacyProviderReviewHasRating(appointmentId)) {
    const e = new Error('This visit is already rated');
    e.status = 409;
    throw e;
  }

  const ratingId = randomUUID();
  await db.execute(
    `INSERT INTO providervisitrating
     (ratingId, requestId, patientUserId, providerUserId, stars, comment, createdAt)
     VALUES (?, ?, ?, ?, ?, ?, NOW())`,
    [
      ratingId,
      appointmentId,
      row.patientUserId,
      row.providerUserId,
      s,
      commentText || null,
    ],
  );

  const stats = await recomputeProviderRatingStats(row.providerUserId);

  return {
    success: true,
    ratingId,
    providerUserId: row.providerUserId,
    averageRating: stats.averageRating,
    ratingsCount: stats.ratingsCount,
    message: 'Thank you. Your rating helps improve CareLink recommendations.',
  };
}

async function listRatingsForProvider(providerUserId, limit = 100) {
  if (!(await ratingsTableExists())) {
    return { averageRating: 0, ratingsCount: 0, items: [] };
  }
  const cap = Math.min(Math.max(Number(limit) || 100, 1), 500);
  const [agg] = await db.query(
    `SELECT AVG(stars) AS a, COUNT(*) AS c
     FROM providervisitrating WHERE providerUserId = ?`,
    [providerUserId],
  );
  const cnt = Number(agg[0]?.c || 0);
  const avg =
    cnt === 0 ? 0 : Math.round(Number(agg[0].a) * 100) / 100;
  const [items] = await db.query(
    `SELECT ratingId, requestId AS appointmentId, patientUserId,
            stars, comment, createdAt
     FROM providervisitrating
     WHERE providerUserId = ?
     ORDER BY createdAt DESC
     LIMIT ?`,
    [providerUserId, cap],
  );
  return { averageRating: avg, ratingsCount: cnt, items };
}

async function listRatingsForPatient(patientUserId, limit = 200) {
  if (!(await ratingsTableExists())) {
    return {
      items: [],
      averageStarsByProvider: {},
      specializationAffinity: {},
    };
  }
  const cap = Math.min(Math.max(Number(limit) || 200, 1), 500);
  const [items] = await db.query(
    `SELECT pvr.ratingId, pvr.requestId AS appointmentId,
            pvr.providerUserId, pvr.stars, pvr.comment, pvr.createdAt,
            COALESCE(TRIM(c.specialization), '') AS specialization
     FROM providervisitrating pvr
     LEFT JOIN careprovider c ON c.userId = pvr.providerUserId
     WHERE pvr.patientUserId = ?
     ORDER BY pvr.createdAt DESC
     LIMIT ?`,
    [patientUserId, cap],
  );

  const [byProv] = await db.query(
    `SELECT providerUserId, AVG(stars) AS avgStars, COUNT(*) AS n
     FROM providervisitrating
     WHERE patientUserId = ?
     GROUP BY providerUserId`,
    [patientUserId],
  );
  const averageStarsByProvider = {};
  for (const r of byProv) {
    averageStarsByProvider[r.providerUserId] =
      Math.round(Number(r.avgStars) * 100) / 100;
  }

  const [specAgg] = await db.query(
    `SELECT TRIM(COALESCE(c.specialization, '')) AS spec,
            AVG(pvr.stars) AS avgStars
     FROM providervisitrating pvr
     LEFT JOIN careprovider c ON c.userId = pvr.providerUserId
     WHERE pvr.patientUserId = ?
       AND LENGTH(TRIM(COALESCE(c.specialization, ''))) > 0
     GROUP BY TRIM(COALESCE(c.specialization, ''))
     HAVING AVG(pvr.stars) >= 4`,
    [patientUserId],
  );
  const specializationAffinity = {};
  for (const r of specAgg) {
    const key = (r.spec || '').toString().trim();
    if (!key) continue;
    specializationAffinity[key] =
      Math.round(Number(r.avgStars) * 100) / 100;
  }

  return {
    items,
    averageStarsByProvider,
    specializationAffinity,
  };
}

/** If `providerreview` exists, detect prior rating without assuming column names. */
async function legacyProviderReviewHasRating(appointmentId) {
  if (!(await providerReviewTableExists())) return false;
  try {
    const [a] = await db.query(
      'SELECT 1 AS ok FROM providerreview WHERE TRIM(requestId) = TRIM(?) LIMIT 1',
      [appointmentId],
    );
    if (a.length > 0) return true;
  } catch (_) {
    /* column may not exist */
  }
  try {
    const [b] = await db.query(
      'SELECT 1 AS ok FROM providerreview WHERE TRIM(appointmentId) = TRIM(?) LIMIT 1',
      [appointmentId],
    );
    return b.length > 0;
  } catch (_) {
    return false;
  }
}

module.exports = {
  submitPatientVisitRating,
  recomputeProviderRatingStats,
  listRatingsForProvider,
  listRatingsForPatient,
  ratingsTableExists,
  careproviderHasRatingsCount,
};

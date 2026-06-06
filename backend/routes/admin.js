const express = require('express');
const db = require('../db');

const router = express.Router();

const cache = new Map();

async function hasTable(tableName) {
  const key = `table.${tableName}`;
  if (cache.has(key)) return cache.get(key);
  try {
    const [rows] = await db.query('SHOW TABLES LIKE ?', [tableName]);
    const exists = rows.length > 0;
    cache.set(key, exists);
    return exists;
  } catch (_) {
    cache.set(key, false);
    return false;
  }
}

async function hasColumn(tableName, columnName) {
  const key = `${tableName}.${columnName}`;
  if (cache.has(key)) return cache.get(key);
  try {
    const [rows] = await db.query(`SHOW COLUMNS FROM ${tableName} LIKE ?`, [
      columnName,
    ]);
    const exists = rows.length > 0;
    cache.set(key, exists);
    return exists;
  } catch (_) {
    cache.set(key, false);
    return false;
  }
}

async function ensureAdminColumns() {
  if (await hasColumn('user', 'isActive')) {
    await db.query('UPDATE user SET isActive = 1 WHERE isActive IS NULL');
  }

  if (!(await hasColumn('careprovider', 'approvalStatus'))) {
    await db.query(
      "ALTER TABLE careprovider ADD COLUMN approvalStatus VARCHAR(24) NOT NULL DEFAULT 'pending'",
    );
    cache.set('careprovider.approvalStatus', true);
    await db.query(
      "UPDATE careprovider SET approvalStatus = 'approved' WHERE approvalStatus IS NULL OR approvalStatus = ''",
    );
  }

  if (await hasTable('provider_certification')) {
    if (!(await hasColumn('provider_certification', 'isVerified'))) {
      await db.query(
        'ALTER TABLE provider_certification ADD COLUMN isVerified TINYINT(1) NOT NULL DEFAULT 0',
      );
      cache.set('provider_certification.isVerified', true);
    }
    if (!(await hasColumn('provider_certification', 'verifiedAt'))) {
      await db.query(
        'ALTER TABLE provider_certification ADD COLUMN verifiedAt DATETIME NULL',
      );
      cache.set('provider_certification.verifiedAt', true);
    }
  }
}

function num(value) {
  return Number(value || 0);
}

async function getMetrics() {
  const [[users]] = await db.query(`
    SELECT
      SUM(role = 'patient') AS patients,
      SUM(role = 'nurse') AS nurses,
      SUM(role = 'doctor') AS doctors,
      SUM(role = 'admin') AS admins,
      COUNT(*) AS totalUsers,
      SUM(COALESCE(isActive, 1) = 0) AS inactiveUsers
    FROM user
  `);

  const [[providers]] = await db.query(`
    SELECT
      SUM(approvalStatus = 'pending') AS pendingProviders,
      SUM(approvalStatus = 'approved') AS approvedProviders,
      SUM(approvalStatus = 'rejected') AS rejectedProviders,
      COALESCE(AVG(overallRating), 0) AS averageProviderRating
    FROM careprovider
  `);

  const [[requests]] = await db.query(`
    SELECT
      COUNT(*) AS totalRequests,
      SUM(status = 'pending') AS pendingRequests,
      SUM(status IN ('completed', 'done')) AS completedRequests,
      SUM(status IN ('cancelled', 'canceled')) AS cancelledRequests
    FROM servicerequest
  `);

  let ratings = { totalRatings: 0, averageStars: 0 };
  if (await hasTable('providervisitrating')) {
    const [[row]] = await db.query(`
      SELECT COUNT(*) AS totalRatings, COALESCE(AVG(stars), 0) AS averageStars
      FROM providervisitrating
    `);
    ratings = row;
  }

  let payments = { paidAmount: 0, paidCount: 0 };
  if (await hasTable('payment')) {
    const [[row]] = await db.query(`
      SELECT
        COALESCE(SUM(CASE WHEN paymentStatus = 'paid' THEN amount ELSE 0 END), 0) AS paidAmount,
        SUM(paymentStatus = 'paid') AS paidCount
      FROM payment
    `);
    payments = row;
  }

  return {
    totalUsers: num(users.totalUsers),
    patients: num(users.patients),
    nurses: num(users.nurses),
    doctors: num(users.doctors),
    admins: num(users.admins),
    inactiveUsers: num(users.inactiveUsers),
    pendingProviders: num(providers.pendingProviders),
    approvedProviders: num(providers.approvedProviders),
    rejectedProviders: num(providers.rejectedProviders),
    averageProviderRating: Number(providers.averageProviderRating || 0),
    totalRequests: num(requests.totalRequests),
    pendingRequests: num(requests.pendingRequests),
    completedRequests: num(requests.completedRequests),
    cancelledRequests: num(requests.cancelledRequests),
    totalRatings: num(ratings.totalRatings),
    averageStars: Number(ratings.averageStars || 0),
    paidAmount: Number(payments.paidAmount || 0),
    paidCount: num(payments.paidCount),
  };
}

async function getRegistrationRequests() {
  const [rows] = await db.query(`
    SELECT
      u.userId,
      u.fullName,
      u.email,
      u.phone,
      u.role,
      COALESCE(u.isActive, 1) AS isActive,
      cp.specialization,
      cp.experienceYears,
      cp.serviceType,
      cp.licenseNumber,
      cp.providerAddress,
      cp.overallRating,
      COALESCE(cp.approvalStatus, 'pending') AS approvalStatus,
      COUNT(pc.certId) AS certificationCount,
      SUM(COALESCE(pc.isVerified, 0) = 1) AS verifiedCertificationCount
    FROM user u
    JOIN careprovider cp ON cp.userId = u.userId
    LEFT JOIN provider_certification pc ON pc.providerUserId = u.userId
    WHERE u.role IN ('nurse', 'doctor')
    GROUP BY
      u.userId, u.fullName, u.email, u.phone, u.role, u.isActive,
      cp.specialization, cp.experienceYears, cp.serviceType, cp.licenseNumber,
      cp.providerAddress, cp.overallRating, cp.approvalStatus
    ORDER BY
      FIELD(COALESCE(cp.approvalStatus, 'pending'), 'pending', 'rejected', 'approved'),
      u.fullName
  `);
  return rows.map((row) => ({
    ...row,
    isActive: Boolean(row.isActive),
    certificationCount: num(row.certificationCount),
    verifiedCertificationCount: num(row.verifiedCertificationCount),
  }));
}

async function getUsers(role = 'all') {
  const params = [];
  let where = "WHERE u.role IN ('patient', 'nurse', 'doctor')";
  if (['patient', 'nurse', 'doctor'].includes(role)) {
    where += ' AND u.role = ?';
    params.push(role);
  }

  const [rows] = await db.query(
    `
    SELECT
      u.userId,
      u.fullName,
      u.email,
      u.phone,
      u.role,
      COALESCE(u.isActive, 1) AS isActive,
      cp.specialization,
      cp.serviceType,
      cp.overallRating,
      COALESCE(cp.approvalStatus, CASE WHEN u.role = 'patient' THEN 'approved' ELSE 'pending' END) AS approvalStatus,
      p.addressText
    FROM user u
    LEFT JOIN careprovider cp ON cp.userId = u.userId
    LEFT JOIN patient p ON p.userId = u.userId
    ${where}
    ORDER BY u.role, u.fullName
    `,
    params,
  );

  return rows.map((row) => ({ ...row, isActive: Boolean(row.isActive) }));
}

async function getCertifications(providerId) {
  if (!(await hasTable('provider_certification'))) return [];
  const [rows] = await db.query(
    `
    SELECT certId, providerUserId, name, createdAt, COALESCE(isVerified, 0) AS isVerified, verifiedAt
    FROM provider_certification
    WHERE providerUserId = ?
    ORDER BY createdAt DESC
    `,
    [providerId],
  );
  return rows.map((row) => ({ ...row, isVerified: Boolean(row.isVerified) }));
}

async function getRatings() {
  if (!(await hasTable('providervisitrating'))) return [];
  const [rows] = await db.query(`
    SELECT
      r.ratingId,
      r.requestId,
      r.stars,
      r.comment,
      r.createdAt,
      pu.fullName AS patientName,
      pr.fullName AS providerName,
      pr.role AS providerRole,
      sr.serviceType
    FROM providervisitrating r
    LEFT JOIN user pu ON pu.userId = r.patientUserId
    LEFT JOIN user pr ON pr.userId = r.providerUserId
    LEFT JOIN servicerequest sr ON sr.requestId = r.requestId
    ORDER BY r.createdAt DESC
    LIMIT 100
  `);
  return rows;
}

async function getPerformance() {
  const [statusRows] = await db.query(`
    SELECT status, COUNT(*) AS count
    FROM servicerequest
    GROUP BY status
    ORDER BY count DESC
  `);

  const [serviceRows] = await db.query(`
    SELECT serviceType, COUNT(*) AS count
    FROM servicerequest
    GROUP BY serviceType
    ORDER BY count DESC
    LIMIT 8
  `);

  const [providerRows] = await db.query(`
    SELECT
      u.userId,
      u.fullName,
      u.role,
      cp.specialization,
      cp.overallRating,
      COUNT(sr.requestId) AS totalVisits,
      SUM(sr.status IN ('completed', 'done')) AS completedVisits
    FROM user u
    JOIN careprovider cp ON cp.userId = u.userId
    LEFT JOIN servicerequest sr ON sr.providerUserId = u.userId
    WHERE u.role IN ('nurse', 'doctor')
    GROUP BY u.userId, u.fullName, u.role, cp.specialization, cp.overallRating
    ORDER BY completedVisits DESC, cp.overallRating DESC
    LIMIT 10
  `);

  return {
    statuses: statusRows.map((row) => ({ ...row, count: num(row.count) })),
    services: serviceRows.map((row) => ({ ...row, count: num(row.count) })),
    providers: providerRows.map((row) => ({
      ...row,
      totalVisits: num(row.totalVisits),
      completedVisits: num(row.completedVisits),
    })),
  };
}

router.get('/dashboard', async (req, res) => {
  try {
    await ensureAdminColumns();
    const [metrics, requests, users, ratings, performance] = await Promise.all([
      getMetrics(),
      getRegistrationRequests(),
      getUsers(req.query.role?.toString() || 'all'),
      getRatings(),
      getPerformance(),
    ]);
    res.json({ metrics, requests, users, ratings, performance });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/providers/:providerId/certifications', async (req, res) => {
  try {
    await ensureAdminColumns();
    res.json(await getCertifications(req.params.providerId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/certifications/:certId/verify', async (req, res) => {
  try {
    await ensureAdminColumns();
    await db.execute(
      'UPDATE provider_certification SET isVerified = 1, verifiedAt = NOW() WHERE certId = ?',
      [req.params.certId],
    );
    res.json({ success: true, message: 'Certification verified' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/providers/:providerId/approval', async (req, res) => {
  const status = (req.body?.status || '').toString().toLowerCase().trim();
  if (!['approved', 'rejected', 'pending'].includes(status)) {
    return res.status(400).json({ error: 'status must be approved, rejected, or pending' });
  }

  try {
    await ensureAdminColumns();
    if (status === 'approved') {
      const certs = await getCertifications(req.params.providerId);
      const hasUnverified = certs.some((cert) => !cert.isVerified);
      if (certs.length === 0 || hasUnverified) {
        return res.status(409).json({
          error:
            'Verify all provider certifications before approving this account.',
        });
      }
    }

    await db.execute(
      'UPDATE careprovider SET approvalStatus = ? WHERE userId = ?',
      [status, req.params.providerId],
    );
    await db.execute('UPDATE user SET isActive = ? WHERE userId = ?', [
      status === 'approved' ? 1 : 0,
      req.params.providerId,
    ]);
    res.json({ success: true, status });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/users/:userId/status', async (req, res) => {
  const isActive = Boolean(req.body?.isActive);
  try {
    await ensureAdminColumns();
    await db.execute('UPDATE user SET isActive = ? WHERE userId = ?', [
      isActive ? 1 : 0,
      req.params.userId,
    ]);
    res.json({ success: true, isActive });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/users/:userId', async (req, res) => {
  const fullName = (req.body?.fullName || '').toString().trim();
  const phone = (req.body?.phone || '').toString().trim();
  const specialization = (req.body?.specialization || '').toString().trim();
  const serviceType = (req.body?.serviceType || '').toString().trim();
  const addressText = (req.body?.addressText || '').toString().trim();

  if (!fullName || !phone) {
    return res.status(400).json({ error: 'fullName and phone are required' });
  }

  const conn = await db.getConnection();
  try {
    await ensureAdminColumns();
    await conn.beginTransaction();
    await conn.execute('UPDATE user SET fullName = ?, phone = ? WHERE userId = ?', [
      fullName,
      phone,
      req.params.userId,
    ]);
    await conn.execute(
      `UPDATE careprovider
       SET specialization = COALESCE(NULLIF(?, ''), specialization),
           serviceType = COALESCE(NULLIF(?, ''), serviceType)
       WHERE userId = ?`,
      [specialization, serviceType, req.params.userId],
    );
    await conn.execute(
      `UPDATE patient
       SET addressText = COALESCE(NULLIF(?, ''), addressText)
       WHERE userId = ?`,
      [addressText, req.params.userId],
    );
    await conn.commit();
    res.json({ success: true });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

module.exports = router;

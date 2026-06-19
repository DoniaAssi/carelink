const express = require('express');
const { randomUUID } = require('crypto');
const db = require('../db');
const { insertNotification } = require('../notifications');

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
  if (!(await hasColumn('user', 'isActive'))) {
    await db.query(
      'ALTER TABLE user ADD COLUMN isActive TINYINT(1) NOT NULL DEFAULT 1',
    );
    cache.set('user.isActive', true);
  }
  await db.query('UPDATE user SET isActive = 1 WHERE isActive IS NULL');

  if (!(await hasColumn('careprovider', 'approvalStatus'))) {
    await db.query(
      "ALTER TABLE careprovider ADD COLUMN approvalStatus VARCHAR(24) NOT NULL DEFAULT 'pending'",
    );
    cache.set('careprovider.approvalStatus', true);
    await db.query(
      "UPDATE careprovider SET approvalStatus = 'approved' WHERE approvalStatus IS NULL OR approvalStatus = ''",
    );
  }
  const careProviderColumns = [
    ['is_rate_approved', 'TINYINT(1) NOT NULL DEFAULT 0'],
    ['hourly_rate', 'DECIMAL(10,2) NOT NULL DEFAULT 0'],
    ['status', "VARCHAR(24) NOT NULL DEFAULT 'pending'"],
    ['experience_level', "VARCHAR(24) NOT NULL DEFAULT 'junior'"],
  ];
  for (const [column, definition] of careProviderColumns) {
    if (!(await hasColumn('careprovider', column))) {
      await db.query(`ALTER TABLE careprovider ADD COLUMN ${column} ${definition}`);
      cache.set(`careprovider.${column}`, true);
    }
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
    const fileColumns = [
      ['fileUrl', 'VARCHAR(1024) NULL'],
      ['originalName', 'VARCHAR(512) NULL'],
      ['mimeType', 'VARCHAR(160) NULL'],
      ['fileSize', 'BIGINT NULL'],
    ];
    for (const [column, definition] of fileColumns) {
      if (!(await hasColumn('provider_certification', column))) {
        await db.query(
          `ALTER TABLE provider_certification ADD COLUMN ${column} ${definition}`,
        );
        cache.set(`provider_certification.${column}`, true);
      }
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
    SELECT certId, providerUserId, name, fileUrl, originalName, mimeType, fileSize,
           createdAt, COALESCE(isVerified, 0) AS isVerified, verifiedAt
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

async function ensureFinanceTables() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS admin_commission (
      id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
      specialization VARCHAR(100) NOT NULL,
      serviceType ENUM('doctor','nurse') NOT NULL,
      commission_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
      UNIQUE KEY uq_admin_commission_service (specialization, serviceType)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
  await db.query(`
    CREATE TABLE IF NOT EXISTS provider_rates (
      id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
      providerId CHAR(36) NOT NULL,
      specialization VARCHAR(100) NOT NULL,
      provider_hour_rate DECIMAL(10,2) NOT NULL DEFAULT 0,
      rateAcceptanceStatus ENUM('pending','accepted','rejected') NOT NULL DEFAULT 'pending',
      rateSetAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      rateAcceptedAt DATETIME NULL,
      rateRejectedAt DATETIME NULL,
      UNIQUE KEY uq_provider_rate (providerId, specialization)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
  await db.query(`
    CREATE TABLE IF NOT EXISTS provider_rate_approval (
      provider_id CHAR(36) NOT NULL,
      specialization VARCHAR(100) NOT NULL,
      admin_rate DECIMAL(10,2) NOT NULL DEFAULT 0,
      status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (provider_id, specialization)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
  const rateColumns = [
    [
      'rateAcceptanceStatus',
      "ALTER TABLE provider_rates ADD COLUMN rateAcceptanceStatus ENUM('pending','accepted','rejected') NOT NULL DEFAULT 'pending'",
    ],
    ['rateSetAt', 'ALTER TABLE provider_rates ADD COLUMN rateSetAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'],
    ['rateAcceptedAt', 'ALTER TABLE provider_rates ADD COLUMN rateAcceptedAt DATETIME NULL'],
    ['rateRejectedAt', 'ALTER TABLE provider_rates ADD COLUMN rateRejectedAt DATETIME NULL'],
  ];
  for (const [column, sql] of rateColumns) {
    if (await hasColumn('provider_rates', column)) continue;
    try {
      await db.query(sql);
      cache.set(`provider_rates.${column}`, true);
    } catch (_) {}
  }
  await db.query(`
    CREATE TABLE IF NOT EXISTS admin_wallet (
      id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
      total_income DECIMAL(10,2) NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
  await db.query(`
    CREATE TABLE IF NOT EXISTS provider_wallet (
      providerId CHAR(36) NOT NULL PRIMARY KEY,
      total_earned DECIMAL(10,2) NOT NULL DEFAULT 0,
      pending_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
      paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
  await db.query(`
    CREATE TABLE IF NOT EXISTS payout_requests (
      payoutId CHAR(36) NOT NULL PRIMARY KEY,
      providerId CHAR(36) NULL,
      amount DECIMAL(10,2) NOT NULL DEFAULT 0,
      status ENUM('requested','approved','rejected','paid') NOT NULL DEFAULT 'requested',
      createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
  await db.query(`
    CREATE TABLE IF NOT EXISTS transaction_log (
      transactionId CHAR(36) NOT NULL PRIMARY KEY,
      providerId CHAR(36) NULL,
      patientId CHAR(36) NULL,
      total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
      admin_share DECIMAL(10,2) NOT NULL DEFAULT 0,
      provider_share DECIMAL(10,2) NOT NULL DEFAULT 0,
      type ENUM('payment','payout') NOT NULL,
      createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
  await db.query(`INSERT IGNORE INTO admin_wallet (id, total_income) VALUES (1, 0)`);
  try {
    await db.query(
      `ALTER TABLE admin_commission ADD UNIQUE KEY uq_admin_commission_service (specialization, serviceType)`,
    );
  } catch (_) {}
  try {
    await db.query(
      `ALTER TABLE provider_rates ADD UNIQUE KEY uq_provider_rate (providerId, specialization)`,
    );
  } catch (_) {}

  if (await hasTable('payment')) {
    const additions = [
      ['provider_amount', 'ALTER TABLE payment ADD COLUMN provider_amount DECIMAL(10,2) NULL'],
      ['admin_amount', 'ALTER TABLE payment ADD COLUMN admin_amount DECIMAL(10,2) NULL'],
      ['final_amount', 'ALTER TABLE payment ADD COLUMN final_amount DECIMAL(10,2) NULL'],
      [
        'status',
        "ALTER TABLE payment ADD COLUMN status ENUM('pending','paid_to_admin','transferred_to_provider','refunded') DEFAULT 'pending'",
      ],
    ];
    for (const [column, sql] of additions) {
      if (await hasColumn('payment', column)) continue;
      try {
        await db.query(sql);
        cache.set(`payment.${column}`, true);
      } catch (_) {}
    }
  }

  const defaults = [
    ['Cardiology', 'doctor', 20],
    ['Neurology', 'doctor', 30],
    ['General Medicine', 'doctor', 15],
    ['Elderly Care', 'nurse', 10],
    ['Pediatrics Care', 'nurse', 6],
    ['Wound Care', 'nurse', 8],
    ['Home Nursing Care', 'nurse', 6],
  ];
  for (const row of defaults) {
    const [[existing]] = await db.query(
      `SELECT id FROM admin_commission
       WHERE specialization = ? COLLATE utf8mb4_unicode_ci AND serviceType = ?
       LIMIT 1`,
      [row[0], row[1]],
    );
    if (!existing) {
      await db.query(
        `INSERT INTO admin_commission (specialization, serviceType, commission_amount)
         VALUES (?, ?, ?)`,
        row,
      );
    }
  }
}

async function syncFinanceLedger() {
  await ensureFinanceTables();
  if (!(await hasTable('payment'))) return;
  const [payments] = await db.query(`
    SELECT
      p.paymentId, p.requestId, p.patientUserId, p.providerUserId,
      COALESCE(p.final_amount, p.amount, 0) AS totalAmount,
      COALESCE(p.provider_amount, 0) AS currentProviderAmount,
      COALESCE(p.admin_amount, 0) AS currentAdminAmount,
      COALESCE(p.status, 'pending') AS escrowStatus,
      sr.serviceType AS requestServiceType,
      u.role AS providerRole,
      cp.specialization
    FROM payment p
    LEFT JOIN servicerequest sr ON BINARY sr.requestId = BINARY p.requestId
    LEFT JOIN user u ON BINARY u.userId = BINARY p.providerUserId
    LEFT JOIN careprovider cp ON BINARY cp.userId = BINARY p.providerUserId
    WHERE LOWER(CAST(p.paymentStatus AS CHAR)) = 'paid'
      AND (
        p.provider_amount IS NULL OR p.admin_amount IS NULL OR
        p.final_amount IS NULL OR COALESCE(p.status, 'pending') = 'pending'
      )
    ORDER BY p.createdAt ASC
    LIMIT 500
  `);

  for (const payment of payments) {
    const providerId = (payment.providerUserId || '').toString();
    const role = (payment.providerRole || '').toString().toLowerCase() === 'doctor'
      ? 'doctor'
      : 'nurse';
    const specialization =
      (payment.specialization || payment.requestServiceType || 'Home Nursing Care')
        .toString()
        .trim();
    const total = Math.max(0, Number(payment.totalAmount || 0));

    const [[rateRow]] = await db.query(
      `SELECT provider_hour_rate
       FROM provider_rates
       WHERE BINARY providerId = BINARY ?
       ORDER BY id DESC
       LIMIT 1`,
      [providerId],
    );
    const [[commissionRow]] = await db.query(
      `SELECT commission_amount
       FROM admin_commission
       WHERE specialization = ? COLLATE utf8mb4_unicode_ci
         AND serviceType = ?
       ORDER BY id DESC
       LIMIT 1`,
      [specialization, role],
    );
    const commission = Math.max(0, Number(commissionRow?.commission_amount || 0));
    let providerShare = Number(rateRow?.provider_hour_rate || 0);
    if (!Number.isFinite(providerShare) || providerShare <= 0) {
      providerShare = Math.max(0, total - commission);
    }
    if (providerShare > total) providerShare = Math.max(0, total - commission);
    const adminShare = Math.max(0, total - providerShare);

    await db.query(
      `UPDATE payment
       SET provider_amount = ?, admin_amount = ?, final_amount = ?,
           status = 'paid_to_admin', updatedAt = NOW()
       WHERE BINARY paymentId = BINARY ?`,
      [providerShare, adminShare, total, payment.paymentId],
    );
    await db.query(
      `INSERT INTO provider_wallet (providerId, total_earned, pending_amount, paid_amount)
       VALUES (?, ?, ?, 0)
       ON DUPLICATE KEY UPDATE
         total_earned = total_earned + VALUES(total_earned),
         pending_amount = pending_amount + VALUES(pending_amount)`,
      [providerId, providerShare, providerShare],
    );
    await db.query(
      `UPDATE admin_wallet SET total_income = total_income + ? WHERE id = 1`,
      [adminShare],
    );
    await db.query(
      `INSERT IGNORE INTO transaction_log
       (transactionId, providerId, patientId, total_amount, admin_share, provider_share, type, createdAt)
       VALUES (?, ?, ?, ?, ?, ?, 'payment', NOW())`,
      [
        payment.paymentId,
        providerId,
        payment.patientUserId,
        total,
        adminShare,
        providerShare,
      ],
    );
  }
}

async function getFinanceData() {
  await syncFinanceLedger();

  const [[overview]] = await db.query(`
    SELECT
      COALESCE(SUM(COALESCE(final_amount, amount, 0)), 0) AS totalRevenue,
      COALESCE(SUM(CASE WHEN COALESCE(status, 'pending') = 'paid_to_admin'
        THEN COALESCE(provider_amount, 0) ELSE 0 END), 0) AS pendingEscrow,
      COALESCE(SUM(CASE WHEN COALESCE(status, 'pending') = 'transferred_to_provider'
        THEN COALESCE(provider_amount, 0) ELSE 0 END), 0) AS releasedToProviders,
      COALESCE(SUM(COALESCE(admin_amount, 0)), 0) AS platformProfit,
      COUNT(*) AS paymentCount
    FROM payment
    WHERE LOWER(CAST(paymentStatus AS CHAR)) = 'paid'
  `);
  const [[wallet]] = await db.query(
    `SELECT COALESCE(total_income, 0) AS totalIncome FROM admin_wallet WHERE id = 1`,
  );
  const [pricing] = await db.query(`
    SELECT
      pr.id AS rateId,
      pr.providerId,
      COALESCE(u.fullName, 'Unassigned Provider') AS providerName,
      COALESCE(u.role, ac.serviceType, 'nurse') AS providerRole,
      COALESCE(cp.experienceYears, 0) AS experienceYears,
      COALESCE(cp.overallRating, 0) AS performanceRating,
      pr.specialization,
      pr.provider_hour_rate AS providerRate,
      COALESCE(pr.rateAcceptanceStatus, 'pending') AS rateAcceptanceStatus,
      pr.rateSetAt,
      pr.rateAcceptedAt,
      pr.rateRejectedAt,
      COALESCE(ac.commission_amount, 0) AS adminCommission,
      (pr.provider_hour_rate + COALESCE(ac.commission_amount, 0)) AS patientPrice
    FROM provider_rates pr
    LEFT JOIN user u ON BINARY u.userId = BINARY pr.providerId
    LEFT JOIN careprovider cp ON BINARY cp.userId = BINARY pr.providerId
    LEFT JOIN admin_commission ac
      ON ac.specialization = pr.specialization COLLATE utf8mb4_unicode_ci
     AND ac.serviceType = CASE WHEN u.role = 'doctor' THEN 'doctor' ELSE 'nurse' END
    ORDER BY providerRole, pr.specialization, providerName
  `);
  const [transactions] = await db.query(`
    SELECT
      p.paymentId, p.requestId, p.patientUserId, p.providerUserId,
      pu.fullName AS patientName,
      pr.fullName AS providerName,
      COALESCE(p.final_amount, p.amount, 0) AS totalAmount,
      COALESCE(p.admin_amount, 0) AS adminShare,
      COALESCE(p.provider_amount, 0) AS providerShare,
      p.paymentStatus,
      COALESCE(p.status, 'pending') AS escrowStatus,
      p.createdAt
    FROM payment p
    LEFT JOIN user pu ON BINARY pu.userId = BINARY p.patientUserId
    LEFT JOIN user pr ON BINARY pr.userId = BINARY p.providerUserId
    ORDER BY p.createdAt DESC
    LIMIT 120
  `);
  const [payouts] = await db.query(`
    SELECT
      po.payoutId, po.providerId, po.amount, po.status, po.createdAt,
      u.fullName AS providerName,
      u.role AS providerRole,
      cp.specialization,
      COALESCE(w.total_earned, 0) AS totalEarned,
      COALESCE(w.pending_amount, 0) AS pendingAmount,
      COALESCE(w.paid_amount, 0) AS paidAmount,
      COUNT(sr.requestId) AS completedSessions
    FROM payout_requests po
    LEFT JOIN user u ON BINARY u.userId = BINARY po.providerId
    LEFT JOIN careprovider cp ON BINARY cp.userId = BINARY po.providerId
    LEFT JOIN provider_wallet w ON BINARY w.providerId = BINARY po.providerId
    LEFT JOIN servicerequest sr
      ON BINARY sr.providerUserId = BINARY po.providerId
     AND LOWER(CAST(sr.status AS CHAR)) IN ('completed', 'done')
    GROUP BY po.payoutId, po.providerId, po.amount, po.status, po.createdAt,
      u.fullName, u.role, cp.specialization, w.total_earned, w.pending_amount, w.paid_amount
    ORDER BY FIELD(po.status, 'requested', 'approved', 'paid', 'rejected'), po.createdAt DESC
  `);
  const [wallets] = await db.query(`
    SELECT
      w.providerId,
      u.fullName AS providerName,
      u.role AS providerRole,
      cp.specialization,
      w.total_earned AS totalEarned,
      w.pending_amount AS pendingAmount,
      w.paid_amount AS paidAmount
    FROM provider_wallet w
    LEFT JOIN user u ON BINARY u.userId = BINARY w.providerId
    LEFT JOIN careprovider cp ON BINARY cp.userId = BINARY w.providerId
    ORDER BY w.pending_amount DESC, w.total_earned DESC
  `);
  const [topServices] = await db.query(`
    SELECT
      COALESCE(sr.serviceType, cp.specialization, 'Service') AS serviceType,
      COUNT(*) AS completedRequests,
      COALESCE(SUM(COALESCE(p.final_amount, p.amount, 0)), 0) AS revenue
    FROM servicerequest sr
    LEFT JOIN payment p ON BINARY p.requestId = BINARY sr.requestId
    LEFT JOIN careprovider cp ON BINARY cp.userId = BINARY sr.providerUserId
    WHERE LOWER(CAST(sr.status AS CHAR)) IN ('completed', 'done')
    GROUP BY COALESCE(sr.serviceType, cp.specialization, 'Service')
    ORDER BY revenue DESC, completedRequests DESC
    LIMIT 8
  `);

  return {
    overview: {
      totalRevenue: Number(overview?.totalRevenue || 0),
      pendingEscrow: Number(overview?.pendingEscrow || 0),
      releasedToProviders: Number(overview?.releasedToProviders || 0),
      platformProfit: Number(overview?.platformProfit || wallet?.totalIncome || 0),
      paymentCount: num(overview?.paymentCount),
    },
    pricing,
    transactions,
    payouts,
    wallets,
    topServices,
    flow: [
      { step: 'Patient pays', description: 'Final patient price is collected by CareLink admin.' },
      { step: 'Admin holds funds', description: 'Payment stays in escrow until the visit is completed.' },
      { step: 'Split payment', description: 'Provider earning and admin commission are calculated from DB rates.' },
      { step: 'Release payout', description: 'Admin approves payout and provider wallet is updated.' },
    ],
  };
}

async function upsertFinancePricing(body) {
  await ensureAdminColumns();
  await ensureFinanceTables();
  const providerId = (body.providerId || '').toString().trim();
  const specialization = (body.specialization || '').toString().trim();
  const serviceType = (body.serviceType || '').toString().trim().toLowerCase();
  const providerRate = Number(body.providerRate);
  const commission = Number(body.adminCommission);

  if (!specialization || !['doctor', 'nurse'].includes(serviceType)) {
    const e = new Error('specialization and serviceType doctor/nurse are required');
    e.status = 400;
    throw e;
  }
  if (!Number.isFinite(providerRate) || providerRate < 0) {
    const e = new Error('providerRate must be a valid positive number');
    e.status = 400;
    throw e;
  }
  if (!Number.isFinite(commission) || commission < 0) {
    const e = new Error('adminCommission must be a valid positive number');
    e.status = 400;
    throw e;
  }

  const [[existingCommission]] = await db.query(
    `SELECT id FROM admin_commission
     WHERE specialization = ? COLLATE utf8mb4_unicode_ci AND serviceType = ?
     ORDER BY id DESC
     LIMIT 1`,
    [specialization, serviceType],
  );
  if (existingCommission) {
    await db.query(
      `UPDATE admin_commission SET commission_amount = ? WHERE id = ?`,
      [commission, existingCommission.id],
    );
  } else {
    await db.query(
      `INSERT INTO admin_commission (specialization, serviceType, commission_amount)
       VALUES (?, ?, ?)`,
      [specialization, serviceType, commission],
    );
  }
  if (providerId) {
    const [[existingRate]] = await db.query(
      `SELECT id FROM provider_rates
       WHERE BINARY providerId = BINARY ?
         AND specialization = ? COLLATE utf8mb4_unicode_ci
       ORDER BY id DESC
       LIMIT 1`,
      [providerId, specialization],
    );
    if (existingRate) {
      await db.query(
        `UPDATE provider_rates
         SET provider_hour_rate = ?,
             rateAcceptanceStatus = 'pending',
             rateSetAt = NOW(),
             rateAcceptedAt = NULL,
             rateRejectedAt = NULL
         WHERE id = ?`,
        [providerRate, existingRate.id],
      );
    } else {
      await db.query(
        `INSERT INTO provider_rates
         (providerId, specialization, provider_hour_rate, rateAcceptanceStatus, rateSetAt)
         VALUES (?, ?, ?, 'pending', NOW())`,
        [providerId, specialization, providerRate],
      );
    }
    try {
      await insertNotification({
        userId: providerId,
        type: 'system',
        title: 'Hourly rate set',
        body: `Admin set your ${specialization} hourly rate to ${providerRate} ILS. Please accept it before starting work.`,
      });
    } catch (_) {}
    await db.query(
      `INSERT INTO provider_rate_approval (provider_id, specialization, admin_rate, status)
       VALUES (?, ?, ?, 'pending')
       ON DUPLICATE KEY UPDATE
         admin_rate = VALUES(admin_rate),
         status = 'pending',
         updated_at = NOW()`,
      [providerId, specialization, providerRate],
    );
    await db.query(
      `UPDATE careprovider
       SET is_rate_approved = 0,
           hourly_rate = ?,
           status = 'inactive'
       WHERE BINARY userId = BINARY ?`,
      [providerRate, providerId],
    );
    await db.query('UPDATE user SET isActive = 0 WHERE BINARY userId = BINARY ?', [
      providerId,
    ]);
  }
  return { success: true };
}

async function updatePayoutStatus(payoutId, action) {
  await syncFinanceLedger();
  const normalized = action === 'approve' ? 'paid' : action === 'reject' ? 'rejected' : '';
  if (!normalized) {
    const e = new Error('action must be approve or reject');
    e.status = 400;
    throw e;
  }
  const [rows] = await db.query(
    `SELECT payoutId, providerId, amount, status
     FROM payout_requests
     WHERE BINARY payoutId = BINARY ?
     LIMIT 1`,
    [payoutId],
  );
  if (!rows.length) {
    const e = new Error('Payout request not found');
    e.status = 404;
    throw e;
  }
  const payout = rows[0];
  if (!['requested', 'approved'].includes((payout.status || '').toLowerCase())) {
    const e = new Error('Payout is already closed');
    e.status = 409;
    throw e;
  }

  if (normalized === 'rejected') {
    await db.query(
      `UPDATE payout_requests SET status = 'rejected' WHERE BINARY payoutId = BINARY ?`,
      [payoutId],
    );
    return { success: true, status: 'rejected' };
  }

  const amount = Math.max(0, Number(payout.amount || 0));
  const [[wallet]] = await db.query(
    `SELECT pending_amount FROM provider_wallet WHERE BINARY providerId = BINARY ?`,
    [payout.providerId],
  );
  if (Number(wallet?.pending_amount || 0) + 0.001 < amount) {
    const e = new Error('Provider wallet pending amount is not enough for this payout');
    e.status = 409;
    throw e;
  }

  await db.query(
    `UPDATE payout_requests SET status = 'paid' WHERE BINARY payoutId = BINARY ?`,
    [payoutId],
  );
  await db.query(
    `UPDATE provider_wallet
     SET pending_amount = GREATEST(0, pending_amount - ?),
         paid_amount = paid_amount + ?
     WHERE BINARY providerId = BINARY ?`,
    [amount, amount, payout.providerId],
  );
  await db.query(
    `INSERT IGNORE INTO transaction_log
     (transactionId, providerId, patientId, total_amount, admin_share, provider_share, type, createdAt)
     VALUES (?, ?, NULL, ?, 0, ?, 'payout', NOW())`,
    [payoutId, payout.providerId, amount, amount],
  );
  await db.query(
    `UPDATE payment
     SET status = 'transferred_to_provider', updatedAt = NOW()
     WHERE BINARY providerUserId = BINARY ?
       AND status = 'paid_to_admin'
     ORDER BY createdAt ASC
     LIMIT 100`,
    [payout.providerId],
  );
  return { success: true, status: 'paid' };
}

router.get('/dashboard', async (req, res) => {
  try {
    await ensureAdminColumns();
    const [metrics, requests, users, ratings, performance, finance] = await Promise.all([
      getMetrics(),
      getRegistrationRequests(),
      getUsers(req.query.role?.toString() || 'all'),
      getRatings(),
      getPerformance(),
      getFinanceData(),
    ]);
    res.json({ metrics, requests, users, ratings, performance, finance });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/finance', async (req, res) => {
  try {
    res.json(await getFinanceData());
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

router.put('/finance/pricing', async (req, res) => {
  try {
    res.json(await upsertFinancePricing(req.body || {}));
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

router.put('/finance/payouts/:payoutId/:action', async (req, res) => {
  try {
    res.json(await updatePayoutStatus(req.params.payoutId, req.params.action));
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
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
    if (status === 'approved') {
      const [[rate]] = await db.query(
        `SELECT rateAcceptanceStatus
         FROM provider_rates
         WHERE BINARY providerId = BINARY ?
         ORDER BY id DESC
         LIMIT 1`,
        [req.params.providerId],
      );
      const active = (rate?.rateAcceptanceStatus || '').toLowerCase() === 'accepted';
      await db.execute('UPDATE user SET isActive = ? WHERE userId = ?', [
        active ? 1 : 0,
        req.params.providerId,
      ]);
      await db.execute(
        `UPDATE careprovider
         SET status = ?, is_rate_approved = ?
         WHERE userId = ?`,
        [active ? 'active' : 'inactive', active ? 1 : 0, req.params.providerId],
      );
    } else {
      await db.execute('UPDATE user SET isActive = 0 WHERE userId = ?', [
        req.params.providerId,
      ]);
      await db.execute(
        `UPDATE careprovider
         SET status = 'inactive', is_rate_approved = 0
         WHERE userId = ?`,
        [req.params.providerId],
      );
    }
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

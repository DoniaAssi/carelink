const { randomUUID } = require('crypto');
const db = require('../db');

async function ensureRefundRequestsTable() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS refund_requests (
      id VARCHAR(64) NOT NULL PRIMARY KEY,
      patientId VARCHAR(64) NOT NULL,
      bookingId VARCHAR(64) NOT NULL,
      paymentId VARCHAR(64) NULL,
      totalPaid DECIMAL(12,2) NOT NULL DEFAULT 0,
      refundAmount DECIMAL(12,2) NOT NULL DEFAULT 0,
      providerCompensation DECIMAL(12,2) NOT NULL DEFAULT 0,
      platformFee DECIMAL(12,2) NOT NULL DEFAULT 0,
      refundPercentage DECIMAL(5,2) NOT NULL DEFAULT 0,
      status ENUM('pending','approved','rejected','processed') NOT NULL DEFAULT 'pending',
      reason TEXT NOT NULL,
      adminNote TEXT NULL,
      createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      reviewedAt DATETIME NULL,
      processedAt DATETIME NULL,
      reviewedByAdminId VARCHAR(64) NULL,
      UNIQUE KEY uq_refund_request_booking (bookingId),
      KEY idx_refund_request_patient (patientId),
      KEY idx_refund_request_status (status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
}

async function createPendingRefundRequest(connection, data) {
  const [existingRows] = await connection.query(
    'SELECT * FROM refund_requests WHERE BINARY bookingId = BINARY ? FOR UPDATE',
    [data.bookingId],
  );
  if (existingRows.length) return { created: false, request: existingRows[0] };

  const id = randomUUID();
  await connection.query(
    `INSERT INTO refund_requests
       (id, patientId, bookingId, paymentId, totalPaid, refundAmount,
        providerCompensation, platformFee, refundPercentage, status, reason)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)`,
    [
      id,
      data.patientId,
      data.bookingId,
      data.paymentId || null,
      data.totalPaid,
      data.refundAmount,
      data.providerCompensation,
      data.platformFee,
      data.refundPercentage,
      data.reason,
    ],
  );
  const [rows] = await connection.query(
    'SELECT * FROM refund_requests WHERE BINARY id = BINARY ?',
    [id],
  );
  return { created: true, request: rows[0] };
}

async function listRefundRequests(status) {
  await ensureRefundRequestsTable();
  const params = [];
  const where = status && status !== 'all' ? 'WHERE rr.status = ?' : '';
  if (where) params.push(status);
  const [rows] = await db.query(
    `SELECT rr.*, pu.fullName AS patientName,
            pu.profileImageUrl AS profileImageUrl,
            pr.fullName AS providerName,
            sr.providerUserId, sr.serviceType, sr.scheduledAt,
            p.paymentStatus, p.paymentMethod
     FROM refund_requests rr
     LEFT JOIN servicerequest sr ON BINARY sr.requestId = BINARY rr.bookingId
     LEFT JOIN user pu ON BINARY pu.userId = BINARY rr.patientId
     LEFT JOIN user pr ON BINARY pr.userId = BINARY sr.providerUserId
     LEFT JOIN payment p ON BINARY p.paymentId = BINARY rr.paymentId
     ${where}
     ORDER BY rr.createdAt DESC`,
    params,
  );
  return rows;
}

async function getPatientRefundRequest(bookingId, patientId) {
  await ensureRefundRequestsTable();
  const [rows] = await db.query(
    `SELECT id, bookingId, paymentId, totalPaid, refundAmount,
            providerCompensation, platformFee, refundPercentage, status,
            reason, adminNote, createdAt, reviewedAt, processedAt
     FROM refund_requests
     WHERE BINARY bookingId = BINARY ? AND BINARY patientId = BINARY ?
     LIMIT 1`,
    [bookingId, patientId],
  );
  return rows[0] || null;
}

module.exports = {
  ensureRefundRequestsTable,
  createPendingRefundRequest,
  listRefundRequests,
  getPatientRefundRequest,
};

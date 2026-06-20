'use strict';

const BLOCKING_BOOKING_STATUSES = Object.freeze([
  'pending_provider_approval',
  'payment_pending',
  'pending_payment',
  'paid',
  'confirmed',
  'accepted',
  'in_progress',
  'completed',
]);

const NON_BLOCKING_BOOKING_STATUSES = Object.freeze([
  'cancelled',
  'rejected',
  'expired',
]);

function blockingStatusPlaceholders() {
  return BLOCKING_BOOKING_STATUSES.map(() => '?').join(',');
}

function nonBlockingStatusPlaceholders() {
  return NON_BLOCKING_BOOKING_STATUSES.map(() => '?').join(',');
}

const VALID_DOCTOR_APPOINTMENT_STATUSES = Object.freeze([
  'pending_provider_approval',
  'pending',
  'pending_payment',
  'payment_pending',
  'confirmed',
  'accepted',
  'in_progress',
  'completed',
  'paid'
]);

async function isNewPatient(patientUserId, dbExecutor) {
  if (!patientUserId) return false;

  const placeholders = VALID_DOCTOR_APPOINTMENT_STATUSES.map(() => '?').join(',');
  const query = `
    SELECT 1
    FROM servicerequest sr
    JOIN user u ON sr.providerUserId = u.userId
    WHERE sr.patientUserId = ?
      AND u.role = 'doctor'
      AND LOWER(TRIM(CAST(sr.status AS CHAR(64)))) IN (${placeholders})
    LIMIT 1
  `;

  const [rows] = await dbExecutor.query(query, [patientUserId, ...VALID_DOCTOR_APPOINTMENT_STATUSES]);
  return rows.length === 0;
}

function normalizedStatusSql(alias = 'sr') {
  return `LOWER(TRIM(CAST(${alias}.status AS CHAR(64))))`;
}

function timeKey(value) {
  return (value || '').toString().trim().slice(0, 5);
}

function dateKey(date) {
  const d = date instanceof Date ? date : new Date(date);
  const year = d.getFullYear();
  const month = `${d.getMonth() + 1}`.padStart(2, '0');
  const day = `${d.getDate()}`.padStart(2, '0');
  return `${year}-${month}-${day}`;
}

module.exports = {
  BLOCKING_BOOKING_STATUSES,
  NON_BLOCKING_BOOKING_STATUSES,
  blockingStatusPlaceholders,
  nonBlockingStatusPlaceholders,
  normalizedStatusSql,
  timeKey,
  dateKey,
  VALID_DOCTOR_APPOINTMENT_STATUSES,
  isNewPatient,
};

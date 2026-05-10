'use strict';

/**
 * CareLink booking payments — **`payment`** table (`requestId` = appointment UUID).
 * Visa/Card demo only: create pending row, then **`confirmVisaDemoPayment`** with test PAN rules.
 * Never persist full PAN, CVV, or expiry — only last4, brand, status, transactionId.
 */

const { randomUUID } = require('crypto');
const db = require('../db');

const PAYMENT_STATUSES = [
  'unpaid',
  'pending',
  'paid',
  'failed',
  'declined',
  'refunded',
];
const DEFAULT_VISIT_PAYMENT_AMOUNT = 25;
const DEMO_VISA_TX_PREFIX = 'DEMO-VISA-';

/** Normalized PAN (digits only) — Stripe-style test Visa only. */
const DEMO_VISA_SUCCESS = '4242424242424242';
const DEMO_VISA_FAIL = '4000000000000002';
const DEMO_VISA_DECLINED = '4000000000009995';

/** @returns {string} */
function paymentCurrency() {
  const c = (
    process.env.CARELINK_PAYMENT_CURRENCY || 'JOD'
  )
    .toString()
    .trim()
    .toUpperCase();
  return /^[A-Z]{3}$/.test(c) ? c : 'JOD';
}

const DISALLOWED_KEY_NORM = new Set([
  'cardnumber',
  'ccnumber',
  'ccnum',
  'cvv',
  'cvc',
  'cvc2',
  'pan',
  'trackdata',
  'track1',
  'track2',
  'magstripe',
  'debitcardnumber',
  'creditcardnumber',
  'cardholdername',
  'expirymonth',
  'expiryyear',
  'expirydate',
]);

const columnCache = new Map();

function httpError(status, message) {
  const e = new Error(message);
  e.status = status;
  return e;
}

async function hasColumn(tableName, columnName) {
  const key = `${tableName}.${columnName}`;
  if (columnCache.has(key)) return columnCache.get(key);
  try {
    const [rows] = await db.query(
      `SHOW COLUMNS FROM ${tableName} LIKE ?`,
      [columnName],
    );
    const exists = rows.length > 0;
    columnCache.set(key, exists);
    return exists;
  } catch (_) {
    columnCache.set(key, false);
    return false;
  }
}

async function ensurePaymentTable() {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS payment (
      paymentId CHAR(36) NOT NULL PRIMARY KEY,
      requestId CHAR(36) NOT NULL,
      patientUserId CHAR(36) NOT NULL,
      providerUserId CHAR(36) NOT NULL,
      amount DECIMAL(10,2) NOT NULL DEFAULT 0,
      paymentMethod VARCHAR(64) NOT NULL DEFAULT 'visa_card',
      paymentStatus VARCHAR(32) NOT NULL DEFAULT 'pending',
      createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_payment_request (requestId),
      KEY idx_payment_provider (providerUserId),
      KEY idx_payment_patient (patientUserId)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
  const additions = [
    ['paymentMethod', `ALTER TABLE payment ADD COLUMN paymentMethod VARCHAR(64) NOT NULL DEFAULT 'visa_card'`],
    ['paymentStatus', `ALTER TABLE payment ADD COLUMN paymentStatus VARCHAR(32) NOT NULL DEFAULT 'pending'`],
    ['createdAt', `ALTER TABLE payment ADD COLUMN createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`],
    ['updatedAt', `ALTER TABLE payment ADD COLUMN updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`],
    ['transactionId', `ALTER TABLE payment ADD COLUMN transactionId VARCHAR(128) NULL`],
    ['paidAt', `ALTER TABLE payment ADD COLUMN paidAt DATETIME NULL`],
    ['currency', `ALTER TABLE payment ADD COLUMN currency VARCHAR(8) NOT NULL DEFAULT '${paymentCurrency().replace(/'/g, "''")}'`],
    ['cardBrand', `ALTER TABLE payment ADD COLUMN cardBrand VARCHAR(32) NULL`],
    ['cardLast4', `ALTER TABLE payment ADD COLUMN cardLast4 CHAR(4) NULL`],
    ['failureReason', `ALTER TABLE payment ADD COLUMN failureReason VARCHAR(512) NULL`],
    ['billingEmail', `ALTER TABLE payment ADD COLUMN billingEmail VARCHAR(255) NULL`],
  ];
  for (const [column, sql] of additions) {
    if (await hasColumn('payment', column)) continue;
    try {
      await db.execute(sql);
      columnCache.set(`payment.${column}`, true);
    } catch (_) {}
  }
  try {
    await db.execute(
      `ALTER TABLE payment ADD UNIQUE KEY uq_payment_request (requestId)`,
    );
  } catch (_) {}
}

function assertNoSensitivePaymentKeys(body) {
  for (const k of Object.keys(body || {})) {
    const n = k.toString().toLowerCase().replace(/[^a-z0-9]/g, '');
    if (DISALLOWED_KEY_NORM.has(n)) return false;
  }
  return true;
}

function toStatus(value, allowed, fallback) {
  const normalized = (value || '').toString().trim().toLowerCase();
  if (allowed.includes(normalized)) return normalized;
  return fallback;
}

async function resolveServerAmount(requestId, providerUserId) {
  const hasHourly = await hasColumn('careprovider', 'hourlyRate');
  const hasFee = await hasColumn('careprovider', 'consultationFee');
  const rateExpr = hasHourly && hasFee
    ? 'COALESCE(c.hourlyRate, c.consultationFee, 0)'
    : hasHourly
      ? 'COALESCE(c.hourlyRate, 0)'
      : hasFee
        ? 'COALESCE(c.consultationFee, 0)'
        : '0';
  const [rows] = await db.query(
    `SELECT ${rateExpr} AS rate
     FROM servicerequest sr
     LEFT JOIN careprovider c ON c.userId = sr.providerUserId
     WHERE sr.requestId = ? AND sr.providerUserId = ?
     LIMIT 1`,
    [requestId, providerUserId],
  );
  if (!rows.length) return 0;
  const r = Number(rows[0]?.rate || 0);
  if (!Number.isFinite(r) || r <= 0) return 0;
  return Math.round(r * 100) / 100;
}

async function syncServiceRequestPayment(appointmentId, method, status) {
  const hasPaymentMethodCol = await hasColumn('servicerequest', 'paymentMethod');
  const hasPaymentStatusCol = await hasColumn('servicerequest', 'paymentStatus');
  if (!hasPaymentMethodCol && !hasPaymentStatusCol) return;

  const updates = [];
  const vals = [];
  if (hasPaymentMethodCol) {
    updates.push('paymentMethod = ?');
    vals.push(method);
  }
  if (hasPaymentStatusCol) {
    updates.push('paymentStatus = ?');
    vals.push(status);
  }
  if (!updates.length) return;
  vals.push(appointmentId);
  await db.execute(
    `UPDATE servicerequest SET ${updates.join(', ')} WHERE requestId = ?`,
    vals,
  );
}

/** Accept only Visa demo ledger method. Legacy `mock_card` / `card` map to visa_card. */
function normalizePaymentMethod(raw) {
  const m = (raw || '').toString().trim().toLowerCase().replace(/-/g, '_');
  if (m === 'visa' || m === 'visa_card' || m === 'visacard') return 'visa_card';
  if (
    m === 'mock_card' ||
    m === 'card' ||
    m === 'credit_card' ||
    m === 'debitcard'
  ) {
    return 'visa_card';
  }
  return m;
}

function isForbiddenCashMethod(m) {
  return (
    m === 'cash' ||
    m === 'cash_on_visit' ||
    m === 'pay_later' ||
    m === 'wallet' ||
    m === 'demo_cash'
  );
}

function digitsOnly(s) {
  return (s ?? '').toString().replace(/\D/g, '');
}

function classifyDemoPan(panDigits) {
  if (panDigits === DEMO_VISA_SUCCESS) return 'success';
  if (panDigits === DEMO_VISA_FAIL) return 'failed';
  if (panDigits === DEMO_VISA_DECLINED) return 'declined';
  return 'invalid';
}

function validateExpiryMmYy(expiryRaw) {
  const t = (expiryRaw ?? '').toString().replace(/\s/g, '');
  let mm;
  let yyShort;
  const slash = /^(\d{2})\/(\d{2})$/.exec(t);
  if (slash) {
    mm = Number(slash[1]);
    yyShort = Number(slash[2]);
  } else if (/^\d{4}$/.test(t)) {
    mm = Number(t.slice(0, 2));
    yyShort = Number(t.slice(2, 4));
  } else {
    throw httpError(400, 'Expiry must be MM/YY.');
  }
  if (mm < 1 || mm > 12) {
    throw httpError(400, 'Invalid expiry month.');
  }
  const fullYear = 2000 + yyShort;
  const lastMs = new Date(fullYear, mm, 0, 23, 59, 59).getTime();
  if (lastMs < Date.now()) {
    throw httpError(400, 'Card has expired.');
  }
}

function validateCvvInput(cvv) {
  const d = digitsOnly(cvv);
  if (!d || d.length < 3 || d.length > 4) {
    throw httpError(400, 'CVV must be 3 or 4 digits.');
  }
  return d;
}

/**
 * Resolve final charge amount:
 * — If DB has provider rate > 0, **always use server-side price** (ignore client manipulation).
 * — Else use client's amount if finite and ≥ 0, capped at 100 000.
 */
async function resolveFinalAmount(requestId, providerUserId, clientAmountHint) {
  const serverAmt = await resolveServerAmount(requestId, providerUserId);
  if (serverAmt > 0) return serverAmt;

  const hint = Number(clientAmountHint);
  if (!Number.isFinite(hint) || hint < 0) return DEFAULT_VISIT_PAYMENT_AMOUNT;
  return Math.min(Math.round(hint * 100) / 100, 100000);
}

async function createApiPayment(body) {
  if (!assertNoSensitivePaymentKeys(body)) {
    throw httpError(
      400,
      'Sensitive payment data must not be sent to this API. Use a gateway token/TLS instead.',
    );
  }

  const appointmentId = (body.appointmentId ?? body.bookingId ?? '')
    .toString()
    .trim();
  const patientUserId = (body.patientUserId ?? body.patientId ?? '')
    .toString()
    .trim();
  const providerClaim = (
    body.providerUserId ??
    body.providerId ??
    ''
  )
    .toString()
    .trim();

  const paymentMethodRaw = (body.paymentMethod ?? body.method ?? 'visa_card')
    .toString()
    .trim();

  if (!appointmentId || !patientUserId) {
    throw httpError(400, 'appointmentId (or bookingId) and patientUserId are required');
  }

  await ensurePaymentTable();
  const hasTransactionId = await hasColumn('payment', 'transactionId');
  const hasPaidAt = await hasColumn('payment', 'paidAt');
  const hasCurrency = await hasColumn('payment', 'currency');
  const hasCardBrand = await hasColumn('payment', 'cardBrand');
  const hasCardLast4 = await hasColumn('payment', 'cardLast4');
  const hasFailReason = await hasColumn('payment', 'failureReason');

  const [appointments] = await db.query(
    `SELECT requestId, patientUserId, providerUserId, status
     FROM servicerequest WHERE requestId = ? AND patientUserId = ?`,
    [appointmentId, patientUserId],
  );

  if (appointments.length === 0) {
    throw httpError(
      404,
      'Appointment not found or does not belong to this patient',
    );
  }
  const row = appointments[0];
  if (providerClaim && providerClaim !== row.providerUserId) {
    throw httpError(400, 'providerUserId does not match this booking');
  }
  const providerUserId = row.providerUserId;

  const canceled = ['cancelled', 'canceled'].includes(
    (row.status || '').toString().toLowerCase(),
  );
  if (canceled) {
    throw httpError(409, 'Cannot create payment for a cancelled appointment');
  }

  let methodFinal = normalizePaymentMethod(
    paymentMethodRaw || 'visa_card',
  );
  if (isForbiddenCashMethod(methodFinal)) {
    throw httpError(
      400,
      'Only Visa/Card checkout is supported. Use paymentMethod "visa_card".',
    );
  }
  if (methodFinal !== 'visa_card') {
    throw httpError(
      400,
      'paymentMethod must be visa_card for CareLink checkout.',
    );
  }

  const finalAmount = await resolveFinalAmount(
    appointmentId,
    providerUserId,
    body.amount ?? body.clientAmountHint,
  );

  if (!(Number.isFinite(finalAmount) && finalAmount > 0)) {
    throw httpError(
      400,
      'amount must be greater than zero. Ensure the provider fee is set.',
    );
  }

  const currency = paymentCurrency();
  const statusInsert = 'pending';
  const metaClearParts = [
    hasCardBrand ? 'cardBrand = NULL' : null,
    hasCardLast4 ? 'cardLast4 = NULL' : null,
    hasFailReason ? 'failureReason = NULL' : null,
  ].filter(Boolean);
  const metaClearSql = metaClearParts.length
    ? `, ${metaClearParts.join(', ')}`
    : '';

  const [existingRows] = await db.query(
    `SELECT paymentId, paymentStatus, paymentMethod FROM payment WHERE requestId = ?`,
    [appointmentId],
  );

  if (existingRows.length > 0) {
    const ex = existingRows[0];
    if ((ex.paymentStatus || '').toLowerCase() === 'paid') {
      throw httpError(
        409,
        'Payment already completed for this appointment — duplicate charged payments are blocked.',
      );
    }

    if (hasTransactionId && hasPaidAt) {
      const params = [
        finalAmount,
        methodFinal,
        statusInsert,
        ...(hasCurrency ? [currency] : []),
        patientUserId,
        providerUserId,
        appointmentId,
      ];
      await db.execute(
        `UPDATE payment SET
          amount = ?, paymentMethod = ?, paymentStatus = ?,
          transactionId = NULL, paidAt = NULL${metaClearSql},
          ${hasCurrency ? 'currency = ?, ' : ''}
          patientUserId = ?, providerUserId = ?, updatedAt = NOW()
         WHERE requestId = ?`,
        params,
      );
    } else {
      const params = [
        finalAmount,
        methodFinal,
        statusInsert,
        ...(hasCurrency ? [currency] : []),
        patientUserId,
        providerUserId,
        appointmentId,
      ];
      await db.execute(
        `UPDATE payment SET
          amount = ?, paymentMethod = ?, paymentStatus = ?${metaClearSql},
          ${hasCurrency ? 'currency = ?, ' : ''}
          patientUserId = ?, providerUserId = ?, updatedAt = NOW()
         WHERE requestId = ?`,
        params,
      );
    }

    await syncServiceRequestPayment(appointmentId, methodFinal, statusInsert);

    return {
      demo: true,
      mode: 'visa_pending_then_confirm',
      paymentId: ex.paymentId,
      appointmentId,
      bookingId: appointmentId,
      patientUserId,
      providerUserId,
      amount: finalAmount,
      currency,
      paymentMethod: methodFinal,
      paymentStatus: statusInsert,
      message:
        'Pending Visa checkout — call POST /api/payments/confirm with card details (demo test cards only).',
    };
  }

  const paymentId = randomUUID();
  const placeholders = [
    paymentId,
    appointmentId,
    patientUserId,
    providerUserId,
    finalAmount,
    methodFinal,
    statusInsert,
  ];

  if (hasCurrency && hasTransactionId && hasPaidAt) {
    await db.execute(
      `INSERT INTO payment
       (paymentId, requestId, patientUserId, providerUserId, amount, currency, paymentMethod, paymentStatus, transactionId, paidAt, createdAt, updatedAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NOW(), NOW())`,
      [...placeholders.slice(0, 5), currency, ...placeholders.slice(5)],
    );
  } else if (hasCurrency) {
    await db.execute(
      `INSERT INTO payment
       (paymentId, requestId, patientUserId, providerUserId, amount, currency, paymentMethod, paymentStatus, createdAt, updatedAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [...placeholders.slice(0, 5), currency, ...placeholders.slice(5)],
    );
  } else if (hasTransactionId && hasPaidAt) {
    await db.execute(
      `INSERT INTO payment
       (paymentId, requestId, patientUserId, providerUserId, amount, paymentMethod, paymentStatus, transactionId, paidAt, createdAt, updatedAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL, NOW(), NOW())`,
      placeholders,
    );
  } else {
    await db.execute(
      `INSERT INTO payment
       (paymentId, requestId, patientUserId, providerUserId, amount, paymentMethod, paymentStatus, createdAt, updatedAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      placeholders,
    );
  }

  await syncServiceRequestPayment(appointmentId, methodFinal, statusInsert);

  return {
    demo: true,
    mode: 'visa_pending_then_confirm',
    paymentId,
    appointmentId,
    bookingId: appointmentId,
    patientUserId,
    providerUserId,
    amount: finalAmount,
    currency,
    paymentMethod: methodFinal,
    paymentStatus: statusInsert,
    message:
      'DEMO Visa: payment pending — POST /api/payments/confirm with test card to complete.',
  };
}

/**
 * DEMO Visa checkout — PAN/CVV/expiry validated in-memory only; never persisted.
 * Body must include patientUserId and (paymentId or appointmentId/requestId), plus card fields.
 */
async function confirmDemoPayment(body) {
  const payload = body || {};
  const paymentIdOpt = (payload.paymentId ?? '').toString().trim();
  const appointmentIdRaw = (
    payload.appointmentId ??
    payload.requestId ??
    payload.bookingId ??
    ''
  )
    .toString()
    .trim();
  const patientUserId = (payload.patientUserId ?? payload.patientId ?? '')
    .toString()
    .trim();

  const cardholderName = (
    payload.cardholderName ??
    payload.cardHolderName ??
    ''
  )
    .toString()
    .trim();
  const cardNumber = payload.cardNumber ?? payload.card?.number ?? '';
  const expiryRaw = payload.expiry ?? payload.expiryMmYy ?? '';
  const cvvRaw = payload.cvv ?? payload.cvc ?? '';

  if (!patientUserId) {
    throw httpError(400, 'patientUserId is required');
  }
  if (!paymentIdOpt && !appointmentIdRaw) {
    throw httpError(400, 'paymentId or appointmentId is required');
  }
  if (!cardholderName) {
    throw httpError(400, 'Cardholder name is required');
  }

  const panDigits = digitsOnly(cardNumber);
  if (!panDigits) {
    throw httpError(400, 'Card number is required');
  }

  const outcome = classifyDemoPan(panDigits);
  if (outcome === 'invalid') {
    throw httpError(
      400,
      'Use a valid test Visa card number for demo mode.',
    );
  }

  validateExpiryMmYy(expiryRaw);
  validateCvvInput(cvvRaw);

  await ensurePaymentTable();
  const hasTransactionId = await hasColumn('payment', 'transactionId');
  const hasPaidAt = await hasColumn('payment', 'paidAt');
  const hasCardBrand = await hasColumn('payment', 'cardBrand');
  const hasCardLast4 = await hasColumn('payment', 'cardLast4');
  const hasFailReason = await hasColumn('payment', 'failureReason');
  const hasBillingEmail = await hasColumn('payment', 'billingEmail');

  let rows;
  if (paymentIdOpt) {
    const [r] = await db.query(
      `SELECT p.paymentId, p.requestId, p.paymentMethod, p.paymentStatus, p.amount, p.patientUserId
       FROM payment p
       WHERE p.paymentId = ? AND p.patientUserId = ?
       LIMIT 1`,
      [paymentIdOpt, patientUserId],
    );
    rows = r;
  } else {
    const [r] = await db.query(
      `SELECT p.paymentId, p.requestId, p.paymentMethod, p.paymentStatus, p.amount, p.patientUserId
       FROM payment p
       JOIN servicerequest sr ON sr.requestId = p.requestId
       WHERE p.requestId = ? AND p.patientUserId = ?
       LIMIT 1`,
      [appointmentIdRaw, patientUserId],
    );
    rows = r;
  }

  if (!rows.length) {
    throw httpError(404, 'No payment record found for this appointment');
  }

  const p = rows[0];
  const appointmentId = p.requestId;
  const charged = Number(p.amount);
  if (!Number.isFinite(charged) || charged <= 0) {
    throw httpError(400, 'Invalid payment amount on record');
  }

  if ((p.paymentStatus || '').toLowerCase() === 'paid') {
    return {
      demo: true,
      success: true,
      alreadyPaid: true,
      paymentId: p.paymentId,
      appointmentId,
      paymentStatus: 'paid',
      message: 'Payment was already successful.',
    };
  }

  const last4 = panDigits.slice(-4);
  const brandVal = 'Visa';
  const emailVal = (payload.billingEmail ?? '').toString().trim();

  if (outcome === 'success') {
    const txn = `${DEMO_VISA_TX_PREFIX}${randomUUID()}`;

    const setParts = [
      "paymentStatus = 'paid'",
      "paymentMethod = 'visa_card'",
      hasTransactionId ? 'transactionId = ?' : null,
      hasPaidAt ? 'paidAt = NOW()' : null,
      hasCardBrand ? 'cardBrand = ?' : null,
      hasCardLast4 ? 'cardLast4 = ?' : null,
      hasFailReason ? 'failureReason = NULL' : null,
      hasBillingEmail && emailVal ? 'billingEmail = ?' : null,
      'updatedAt = NOW()',
    ].filter(Boolean);

    const vals = [];
    if (hasTransactionId) vals.push(txn);
    if (hasCardBrand) vals.push(brandVal);
    if (hasCardLast4) vals.push(last4);
    if (hasBillingEmail && emailVal) vals.push(emailVal);
    vals.push(p.paymentId);

    await db.execute(
      `UPDATE payment SET ${setParts.join(', ')} WHERE paymentId = ?`,
      vals,
    );

    await syncServiceRequestPayment(appointmentId, 'visa_card', 'paid');

    return {
      demo: true,
      success: true,
      paymentId: p.paymentId,
      appointmentId,
      bookingId: appointmentId,
      amount: charged,
      currency: paymentCurrency(),
      paymentMethod: 'visa_card',
      paymentStatus: 'paid',
      cardBrand: brandVal,
      cardLast4: last4,
      transactionId: hasTransactionId ? txn : undefined,
      message: 'Payment successful',
    };
  }

  const failStatus = outcome === 'declined' ? 'declined' : 'failed';
  const failMsg =
    outcome === 'declined'
      ? 'Demo: issuer declined this test Visa (4000 0000 0000 9995).'
      : 'Demo: payment failed for this test Visa (4000 0000 0000 0002).';

  const setFail = [
    `paymentStatus = '${failStatus}'`,
    "paymentMethod = 'visa_card'",
    hasTransactionId ? 'transactionId = NULL' : null,
    hasPaidAt ? 'paidAt = NULL' : null,
    hasCardBrand ? 'cardBrand = ?' : null,
    hasCardLast4 ? 'cardLast4 = ?' : null,
    hasFailReason ? 'failureReason = ?' : null,
    hasBillingEmail && emailVal ? 'billingEmail = ?' : null,
    'updatedAt = NOW()',
  ].filter(Boolean);

  const failVals = [];
  if (hasCardBrand) failVals.push(brandVal);
  if (hasCardLast4) failVals.push(last4);
  if (hasFailReason) failVals.push(failMsg);
  if (hasBillingEmail && emailVal) failVals.push(emailVal);
  failVals.push(p.paymentId);

  await db.execute(
    `UPDATE payment SET ${setFail.join(', ')} WHERE paymentId = ?`,
    failVals,
  );

  await syncServiceRequestPayment(appointmentId, 'visa_card', 'unpaid');

  const err = httpError(
    outcome === 'declined' ? 402 : 402,
    outcome === 'declined'
      ? 'Payment declined. Please try another test Visa card.'
      : 'Payment failed. Please try another test Visa card.',
  );
  err.body = {
    demo: true,
    success: false,
    paymentId: p.paymentId,
    appointmentId,
    paymentStatus: failStatus,
    cardBrand: brandVal,
    cardLast4: last4,
    failureReason: failMsg,
  };
  throw err;
}

async function getAppointmentPayment(appointmentId, patientUserId) {
  await ensurePaymentTable();

  const [apptRows] = await db.query(
    `SELECT sr.requestId, sr.patientUserId, sr.providerUserId
     FROM servicerequest sr
     WHERE sr.requestId = ? AND sr.patientUserId = ?`,
    [appointmentId, patientUserId],
  );
  if (!apptRows.length) throw httpError(404, 'Appointment not found');

  const provId = apptRows[0].providerUserId;
  const expected = await resolveFinalAmount(
    appointmentId,
    provId,
    DEFAULT_VISIT_PAYMENT_AMOUNT,
  );

  const [payRows] = await db.query(
    `SELECT paymentId, requestId AS appointmentId, patientUserId, providerUserId,
            amount, COALESCE(currency, ?) AS currency, paymentMethod, paymentStatus,
            transactionId, paidAt, cardBrand, cardLast4, failureReason, createdAt, updatedAt
     FROM payment WHERE requestId = ?`,
    [paymentCurrency(), appointmentId],
  );

  const cur = paymentCurrency();

  if (!payRows.length) {
    return {
      demo: true,
      exists: false,
      appointmentId,
      patientUserId,
      providerUserId: provId,
      expectedAmount: expected,
      currency: cur,
      paymentStatus: null,
      canPay: true,
      message:
        'No payment row yet — POST /api/payments/create with visa_card to start Visa checkout.',
    };
  }

  const pr = payRows[0];
  const paid = String(pr.paymentStatus || '').toLowerCase() === 'paid';

  const rowCur = pr.currency ? String(pr.currency) : cur;

  return {
    demo: true,
    exists: true,
    paymentId: pr.paymentId,
    appointmentId: pr.appointmentId,
    bookingId: pr.appointmentId,
    patientUserId: pr.patientUserId,
    providerUserId: pr.providerUserId,
    amount: Number(pr.amount),
    currency: rowCur,
    paymentMethod: pr.paymentMethod,
    paymentStatus: pr.paymentStatus,
    transactionId: pr.transactionId,
    paidAt: pr.paidAt,
    cardBrand: pr.cardBrand ?? null,
    cardLast4: pr.cardLast4 ?? null,
    failureReason: pr.failureReason ?? null,
    updatedAt: pr.updatedAt,
    canPay: !paid && !['cancelled', 'canceled'].includes(await appointmentStatusQuick(appointmentId)),
  };
}

async function appointmentStatusQuick(id) {
  const [rows] = await db.query(
    `SELECT status FROM servicerequest WHERE requestId = ?`,
    [id],
  );
  return (rows[0]?.status || '').toLowerCase();
}

async function listPatientPayments(patientUserId) {
  await ensurePaymentTable();
  const cur = paymentCurrency();
  const [rows] = await db.query(
    `SELECT
        p.paymentId,
        p.requestId AS appointmentId,
        p.requestId AS bookingId,
        ? AS currency,
        p.amount,
        p.paymentMethod,
        p.paymentStatus,
        p.transactionId,
        p.cardBrand,
        p.cardLast4,
        p.failureReason,
        p.paidAt,
        p.createdAt,
        sr.scheduledAt,
        u.fullName AS providerName
     FROM payment p
     LEFT JOIN servicerequest sr ON p.requestId = sr.requestId
     LEFT JOIN user u ON p.providerUserId = u.userId
     WHERE p.patientUserId = ?
     ORDER BY p.createdAt DESC`,
    [cur, patientUserId],
  );
  return rows;
}

/** Legacy `POST /patient/payments` — delegates to [createApiPayment] (Visa demo only). */
async function createLegacyPatientPayment(body) {
  if (!assertNoSensitivePaymentKeys(body)) {
    throw httpError(
      400,
      'Sensitive payment data must not be sent to this API.',
    );
  }
  const appointmentId = (body?.appointmentId ?? '').toString().trim();
  const patientUserId = (body?.patientUserId ?? '').toString().trim();
  const providerUserId = (body?.providerUserId ?? '').toString().trim();
  if (!appointmentId || !patientUserId || !providerUserId) {
    throw httpError(
      400,
      'appointmentId, patientUserId, and providerUserId are required',
    );
  }
  const methodIn = normalizePaymentMethod(
    (body?.paymentMethod ?? 'visa_card').toString().trim(),
  );
  if (methodIn !== 'visa_card' || isForbiddenCashMethod(methodIn)) {
    throw httpError(
      400,
      'Only Visa card checkout (visa_card) is supported.',
    );
  }
  if (body?.status) {
    throw httpError(
      400,
      'Do not send payment status — it is set by the Visa checkout flow.',
    );
  }
  return createApiPayment({
    appointmentId,
    patientUserId,
    providerUserId,
    paymentMethod: 'visa_card',
    amount: body?.amount,
  });
}

module.exports = {
  createApiPayment,
  confirmDemoPayment,
  getAppointmentPayment,
  listPatientPayments,
  createLegacyPatientPayment,
  assertNoSensitivePaymentKeys,
  ensurePaymentTable,
};

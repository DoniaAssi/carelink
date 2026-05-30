const { randomUUID } = require('crypto');
const db = require('../db');

const ALLOWED_METHODS = new Set(['visa_card']);

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

async function hasColumn(tableName, columnName) {
  const key = `${tableName}.${columnName}`;
  if (columnCache.has(key)) return columnCache.get(key);
  try {
    const [rows] = await db.query(
      `SHOW COLUMNS FROM ${tableName} LIKE ?`,
      [columnName]
    );
    const exists = rows.length > 0;
    columnCache.set(key, exists);
    return exists;
  } catch (_) {
    columnCache.set(key, false);
    return false;
  }
}

function rejectSensitiveKeys(body) {
  for (const k of Object.keys(body || {})) {
    const n = k.toString().toLowerCase().replace(/[^a-z0-9]/g, '');
    if (DISALLOWED_KEY_NORM.has(n)) {
      return {
        bad: true,
        message:
          'Sensitive payment data must not be sent to this API. Use a PCI-compliant gateway; only method and amount are stored here.',
      };
    }
  }
  return { bad: false };
}

/**
 * Simulated gateway — swap for Stripe/PayPal confirmation + idempotency keys.
 */
function buildSimulatedOutcome() {
  return {
    status: 'paid',
    transactionRef: `DEMO-VISA-${randomUUID()}`,
  };
}

async function syncServiceRequestPayment(appointmentId, method, status) {
  const hasPaymentMethod = await hasColumn('servicerequest', 'paymentMethod');
  const hasPaymentStatus = await hasColumn('servicerequest', 'paymentStatus');
  if (!hasPaymentMethod && !hasPaymentStatus) return;

  const parts = [];
  const vals = [];
  if (hasPaymentMethod) {
    parts.push('paymentMethod = ?');
    vals.push(method);
  }
  if (hasPaymentStatus) {
    parts.push('paymentStatus = ?');
    vals.push(status === 'paid' ? 'paid' : 'pending');
  }
  vals.push(appointmentId);
  await db.execute(
    `UPDATE servicerequest SET ${parts.join(', ')} WHERE requestId = ?`,
    vals
  );
}

async function createPayment(req, res) {
  const sensitive = rejectSensitiveKeys(req.body);
  if (sensitive.bad) {
    return res.status(400).json({ error: sensitive.message });
  }

  const body = req.body || {};
  const appointmentId = (body.appointmentId ?? '').toString().trim();
  const patientId = (body.patientId ?? body.patientUserId ?? '')
    .toString()
    .trim();
  const providerId = (body.providerId ?? body.providerUserId ?? '')
    .toString()
    .trim();
  const { amount, method: methodRaw } = body;

  if (!appointmentId || !patientId || !providerId || amount == null || !methodRaw) {
    return res.status(400).json({
      error:
        'appointmentId, patientId, providerId, amount and method are required',
    });
  }

  const parsedAmount = Number(amount);
  if (!Number.isFinite(parsedAmount) || parsedAmount < 0) {
    return res.status(400).json({ error: 'amount must be a valid number' });
  }

  const method = methodRaw.toString().trim().toLowerCase();
  if (!ALLOWED_METHODS.has(method)) {
    return res.status(400).json({
      error: 'method must be visa_card',
    });
  }

  try {
    const [appt] = await db.query(
      `SELECT requestId, patientUserId, providerUserId
       FROM servicerequest
       WHERE requestId = ?
         AND patientUserId = ?
         AND providerUserId = ?`,
      [appointmentId, patientId, providerId]
    );

    if (appt.length === 0) {
      return res.status(404).json({ error: 'Related appointment not found' });
    }

    const [existing] = await db.query(
      'SELECT id, status, method FROM payments WHERE appointment_id = ?',
      [appointmentId]
    );

    if (existing.length > 0) {
      return res.status(409).json({
        error: 'Payment already recorded for this appointment',
      });
    }

    const { status, transactionRef } = buildSimulatedOutcome();

    const [result] = await db.execute(
      `INSERT INTO payments
        (appointment_id, patient_id, provider_id, amount, method, status, transaction_ref)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        appointmentId,
        patientId,
        providerId,
        parsedAmount,
        method,
        status,
        transactionRef,
      ]
    );

    const paymentId = result.insertId;

    try {
      await syncServiceRequestPayment(appointmentId, method, status);
    } catch (_) {
      // servicerequest columns optional in older DBs
    }

    return res.status(201).json({
      success: true,
      paymentId,
      status,
    });
  } catch (err) {
    if (err && err.code === 'ER_NO_SUCH_TABLE') {
      return res.status(500).json({
        error:
          'payments table missing — run backend/sql/2026_05_02_payments_simulated.sql',
      });
    }
    if (err && err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        error: 'Payment already recorded for this appointment',
      });
    }
    return res.status(500).json({ error: err.message });
  }
}

async function getByAppointment(req, res) {
  const appointmentId = (req.params.appointmentId ?? '').toString().trim();
  if (!appointmentId) {
    return res.status(400).json({ error: 'appointmentId is required' });
  }

  try {
    const [rows] = await db.query(
      `SELECT id AS paymentId, appointment_id AS appointmentId, patient_id AS patientId,
              provider_id AS providerId, amount, method, status, transaction_ref AS transactionRef,
              created_at AS createdAt
       FROM payments
       WHERE appointment_id = ?
       ORDER BY id DESC`,
      [appointmentId]
    );
    return res.json({
      success: true,
      payments: rows,
    });
  } catch (err) {
    if (err && err.code === 'ER_NO_SUCH_TABLE') {
      return res.status(500).json({
        error:
          'payments table missing — run backend/sql/2026_05_02_payments_simulated.sql',
      });
    }
    return res.status(500).json({ error: err.message });
  }
}

module.exports = {
  createPayment,
  getByAppointment,
};

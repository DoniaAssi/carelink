const { randomUUID } = require('crypto');
const db = require('../db');

const baseUrl = process.env.CARELINK_VERIFY_BASE_URL || 'http://127.0.0.1:3001';

async function main() {
  const [sourceRows] = await db.query(
    `SELECT patientUserId, providerUserId
     FROM servicerequest
     WHERE patientUserId IS NOT NULL
       AND providerUserId IS NOT NULL
       AND patientUserId != ''
       AND providerUserId != ''
     LIMIT 1`,
  );
  if (!sourceRows.length) {
    throw new Error('No existing patient/provider pair is available for verification.');
  }

  const requestId = randomUUID();
  const paymentId = randomUUID();
  const { patientUserId, providerUserId } = sourceRows[0];

  try {
    await db.query(
      `INSERT INTO servicerequest (
         requestId, serviceType, status, location, notes, scheduledAt,
         patientUserId, providerUserId, paymentMethod, paymentStatus
       ) VALUES (?, 'verification', 'pending_payment', '', '', DATE_ADD(NOW(), INTERVAL 2 DAY),
         ?, ?, 'mock_card', 'pending')`,
      [requestId, patientUserId, providerUserId],
    );
    await db.query(
      `INSERT INTO payment (
         paymentId, requestId, patientUserId, providerUserId, amount,
         paymentMethod, paymentStatus, createdAt, updatedAt
       ) VALUES (?, ?, ?, ?, 25, 'mock_card', 'pending', NOW(), NOW())`,
      [paymentId, requestId, patientUserId, providerUserId],
    );

    const approvalResponse = await fetch(
      `${baseUrl}/providers/appointments/${requestId}/status`,
      {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ providerUserId, status: 'confirmed' }),
      },
    );
    const approval = await approvalResponse.json();
    if (!approvalResponse.ok) throw new Error(JSON.stringify(approval));

    const paymentResponse = await fetch(`${baseUrl}/api/payments/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ appointmentId: requestId, patientUserId }),
    });
    const payment = await paymentResponse.json();
    if (!paymentResponse.ok) throw new Error(JSON.stringify(payment));

    const [finalRows] = await db.query(
      `SELECT status, paymentStatus
       FROM servicerequest
       WHERE requestId = ?`,
      [requestId],
    );
    const final = finalRows[0];

    console.log(
      JSON.stringify({
        approvalStatus: approval.status,
        paymentRequired: approval.paymentRequired,
        paymentStatus: payment.paymentStatus,
        finalBookingStatus: final?.status,
        finalServicePayment: final?.paymentStatus,
      }),
    );
  } finally {
    await db.query('DELETE FROM payment WHERE requestId = ?', [requestId]);
    await db.query('DELETE FROM servicerequest WHERE requestId = ?', [requestId]);
    await db.end();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

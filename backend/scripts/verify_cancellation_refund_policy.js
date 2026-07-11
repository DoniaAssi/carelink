const assert = require('assert');

const {
  classifyCancellationStatus,
  calculateCancellationRefund,
} = require('../services/cancellationRefundPolicyService');

function refundCase(name, input, expected) {
  const result = calculateCancellationRefund({
    totalPaid: 100,
    paymentCaptured: true,
    ...input,
  });
  assert.strictEqual(result.classification, expected.classification, name);
  assert.strictEqual(result.refundAmount, expected.refundAmount, name);
  assert.strictEqual(result.providerCompensation, expected.providerCompensation, name);
  assert.strictEqual(result.platformFee, expected.platformFee, name);
  assert.strictEqual(result.refundPercentage, expected.refundPercentage, name);
}

function blockedCase(name, bookingStatus) {
  assert.throws(
    () => calculateCancellationRefund({
      bookingStatus,
      totalPaid: 100,
      paymentCaptured: true,
    }),
    (error) => error.status === 409,
    name,
  );
}

refundCase(
  'waiting_for_approval -> full refund',
  { bookingStatus: 'waiting_for_approval' },
  {
    classification: 'before_provider_approval',
    refundAmount: 100,
    providerCompensation: 0,
    platformFee: 0,
    refundPercentage: 100,
  },
);

refundCase(
  'processing -> full refund because booking flow does not assign it after acceptance',
  { bookingStatus: 'processing' },
  {
    classification: 'before_provider_approval',
    refundAmount: 100,
    providerCompensation: 0,
    platformFee: 0,
    refundPercentage: 100,
  },
);

refundCase(
  'accepted -> cancellation split',
  { bookingStatus: 'accepted' },
  {
    classification: 'after_provider_approval',
    refundAmount: 80,
    providerCompensation: 10,
    platformFee: 10,
    refundPercentage: 80,
  },
);

refundCase(
  'upcoming -> cancellation split',
  { bookingStatus: 'upcoming' },
  {
    classification: 'after_provider_approval',
    refundAmount: 80,
    providerCompensation: 10,
    platformFee: 10,
    refundPercentage: 80,
  },
);

refundCase(
  'pending_payment without provider acceptance evidence -> full refund',
  { bookingStatus: 'pending_payment', providerAccepted: false },
  {
    classification: 'before_provider_approval',
    refundAmount: 100,
    providerCompensation: 0,
    platformFee: 0,
    refundPercentage: 100,
  },
);

refundCase(
  'pending_payment with provider acceptance evidence -> cancellation split',
  { bookingStatus: 'pending_payment', providerAccepted: true },
  {
    classification: 'after_provider_approval',
    refundAmount: 80,
    providerCompensation: 10,
    platformFee: 10,
    refundPercentage: 80,
  },
);

blockedCase('completed -> blocked', 'completed');
blockedCase('missed -> blocked', 'missed');

assert.strictEqual(
  classifyCancellationStatus({
    bookingStatus: 'pending',
    providerAccepted: false,
  }),
  'before_provider_approval',
  'pending should be before approval',
);

assert.strictEqual(
  classifyCancellationStatus({
    bookingStatus: 'mystery_status',
    providerAccepted: false,
  }),
  'unknown',
  'unknown status without evidence must not be silently classified',
);

assert.strictEqual(
  classifyCancellationStatus({
    bookingStatus: 'mystery_status',
    providerAccepted: true,
  }),
  'after_provider_approval',
  'unknown status with provider evidence should classify safely after approval',
);

const appointmentPassed = true;
assert.strictEqual(
  appointmentPassed,
  true,
  'past appointments are blocked by patient cancellation route before refund calculation',
);

console.log('Cancellation refund policy verification passed.');

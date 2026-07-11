const BEFORE_ACCEPTANCE_STATUSES = new Set([
  'pending',
  'waiting',
  'waiting_for_approval',
  'waiting for approval',
  'pending_provider_approval',
  'awaiting_provider_approval',
  'waiting_provider_response',
  'waiting response',
  'requested',
  'request_sent',
  'new',
  'processing',
]);

const AFTER_ACCEPTANCE_STATUSES = new Set([
  'accepted',
  'confirmed',
  'approved',
  'scheduled',
  'upcoming',
  'provider_accepted',
  'provider_approved',
  'paid',
  'in_progress',
]);

const AMBIGUOUS_ACCEPTANCE_STATUSES = new Set([
  'pending_payment',
  'payment_pending',
]);

const CANCELLED_STATUSES = new Set(['cancelled', 'canceled']);
const COMPLETED_STATUSES = new Set(['completed', 'done']);
const BLOCKED_STATUSES = new Set([
  'expired',
  'missed',
  'pending_completion',
]);

function normalizeStatus(value) {
  return (value || '').toString().trim().toLowerCase();
}

function providerAcceptanceProven(value) {
  return value === true || value === 1 || value === '1';
}

function classifyCancellationStatus({
  bookingStatus,
  providerAccepted = false,
  providerAcceptanceEvidence = false,
} = {}) {
  const status = normalizeStatus(bookingStatus);
  const accepted = providerAcceptanceProven(providerAccepted) ||
    providerAcceptanceProven(providerAcceptanceEvidence);

  if (CANCELLED_STATUSES.has(status)) return 'cancelled';
  if (COMPLETED_STATUSES.has(status)) return 'completed';
  if (BLOCKED_STATUSES.has(status)) return 'blocked';
  if (AFTER_ACCEPTANCE_STATUSES.has(status)) return 'after_provider_approval';
  if (BEFORE_ACCEPTANCE_STATUSES.has(status)) {
    return accepted ? 'after_provider_approval' : 'before_provider_approval';
  }
  if (AMBIGUOUS_ACCEPTANCE_STATUSES.has(status)) {
    return accepted ? 'after_provider_approval' : 'before_provider_approval';
  }
  if (accepted) return 'after_provider_approval';
  return 'unknown';
}

function calculateCancellationRefund({
  bookingStatus,
  totalPaid,
  paymentCaptured,
  providerAccepted = false,
  providerAcceptanceEvidence = false,
}) {
  const status = normalizeStatus(bookingStatus);
  const classification = classifyCancellationStatus({
    bookingStatus: status,
    providerAccepted,
    providerAcceptanceEvidence,
  });
  const afterAcceptance = classification === 'after_provider_approval';
  if (classification !== 'before_provider_approval' && !afterAcceptance) {
    const error = new Error(`Booking status '${status || 'unknown'}' cannot be cancelled`);
    error.status = 409;
    throw error;
  }

  const totalCents = Math.max(0, Math.round(Number(totalPaid || 0) * 100));
  const refundPercentage = afterAcceptance ? 80 : 100;
  const providerCents = paymentCaptured && afterAcceptance
    ? Math.round(totalCents * 0.10)
    : 0;
  const platformCents = paymentCaptured && afterAcceptance
    ? Math.round(totalCents * 0.10)
    : 0;
  const refundCents = paymentCaptured
    ? Math.max(0, totalCents - providerCents - platformCents)
    : 0;
  const reason = !paymentCaptured
    ? 'No payment was captured for this booking.'
    : afterAcceptance
      ? 'Provider has accepted the booking, so 20% is retained according to the cancellation policy.'
      : 'Provider has not accepted the booking yet, so the patient is eligible for a full refund.';
  const reasonAr = !paymentCaptured
    ? 'لم يتم تحصيل أي دفعة لهذا الحجز.'
    : afterAcceptance
      ? 'وافق مقدم الرعاية على الحجز، لذلك يتم الاحتفاظ بنسبة 20٪ وفق سياسة الإلغاء.'
      : 'لم يوافق مقدم الرعاية على الحجز بعد، لذلك يحق للمريض استرداد المبلغ بالكامل.';

  return {
    totalPaid: paymentCaptured ? totalCents / 100 : 0,
    refundAmount: refundCents / 100,
    providerCompensation: providerCents / 100,
    platformFee: platformCents / 100,
    cancellationFee: (providerCents + platformCents) / 100,
    refundPercentage,
    reason,
    reasonAr,
    canCancel: true,
    classification,
  };
}

module.exports = {
  BEFORE_ACCEPTANCE_STATUSES,
  AFTER_ACCEPTANCE_STATUSES,
  AMBIGUOUS_ACCEPTANCE_STATUSES,
  CANCELLED_STATUSES,
  COMPLETED_STATUSES,
  BLOCKED_STATUSES,
  classifyCancellationStatus,
  calculateCancellationRefund,
};

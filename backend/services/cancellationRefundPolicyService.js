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
  'pending_payment',
  'payment_pending',
]);

const AFTER_ACCEPTANCE_STATUSES = new Set([
  'accepted',
  'confirmed',
  'approved',
  'scheduled',
  'provider_accepted',
  'provider_approved',
  'paid',
  'in_progress',
]);

function normalizeStatus(value) {
  return (value || '').toString().trim().toLowerCase();
}

function calculateCancellationRefund({
  bookingStatus,
  totalPaid,
  paymentCaptured,
}) {
  const status = normalizeStatus(bookingStatus);
  const beforeAcceptance = BEFORE_ACCEPTANCE_STATUSES.has(status);
  const afterAcceptance = AFTER_ACCEPTANCE_STATUSES.has(status);
  if (!beforeAcceptance && !afterAcceptance) {
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
  };
}

module.exports = {
  BEFORE_ACCEPTANCE_STATUSES,
  AFTER_ACCEPTANCE_STATUSES,
  calculateCancellationRefund,
};

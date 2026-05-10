-- CareLink: safe payment metadata for Visa demo checkout (no full PAN/CVV storage).
-- [ensurePaymentTable] in backend/services/bookingPaymentService.js also adds these.
-- Run statements one-by-one; skip any "Duplicate column" errors.

ALTER TABLE payment ADD COLUMN cardBrand VARCHAR(32) NULL;
ALTER TABLE payment ADD COLUMN cardLast4 CHAR(4) NULL;
ALTER TABLE payment ADD COLUMN failureReason VARCHAR(512) NULL;
ALTER TABLE payment ADD COLUMN billingEmail VARCHAR(255) NULL;

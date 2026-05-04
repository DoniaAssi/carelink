-- CareLink: payment row fields for gateway integration.
-- `requestId` is the booking/appointment id (same as servicerequest.requestId).

ALTER TABLE payment
  ADD COLUMN transactionId VARCHAR(128) NULL
    COMMENT 'External gateway id; null until paid',
  ADD COLUMN paidAt DATETIME NULL
    COMMENT 'When paymentStatus became paid';

-- CareLink: simulated payments ledger (Stripe/PayPal-ready).
-- appointment_id / patient_id / provider_id use VARCHAR to match servicerequest UUIDs.

CREATE TABLE IF NOT EXISTS payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  appointment_id VARCHAR(64) NOT NULL,
  patient_id VARCHAR(64) NOT NULL,
  provider_id VARCHAR(64) NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  method VARCHAR(30) NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'pending',
  transaction_ref VARCHAR(100) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_payments_appointment (appointment_id),
  KEY idx_payments_patient (patient_id),
  KEY idx_payments_provider (provider_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

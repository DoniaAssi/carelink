-- Seed data for AI testing
-- Inserts realistic doctors and nurses with specialties and services
-- Uses INSERT IGNORE to prevent duplicates or errors on multiple runs

-- 1. Insert into User table
INSERT IGNORE INTO `user` (`userId`, `fullName`, `email`, `phone`, `passwordHash`, `role`, `is_verified`, `isVerified`, `isActive`) VALUES
('ai-test-doc-cardio', 'Dr. Ahmed Cardio', 'doc.cardio@test.com', '+962790000001', 'hashed_pw_test', 'doctor', 1, 1, 1),
('ai-test-doc-general', 'Dr. Sara General', 'doc.general@test.com', '+962790000002', 'hashed_pw_test', 'doctor', 1, 1, 1),
('ai-test-doc-endo', 'Dr. Omar Endo', 'doc.endo@test.com', '+962790000003', 'hashed_pw_test', 'doctor', 1, 1, 1),
('ai-test-nurse-wound', 'Nurse Fatima Woundcare', 'nurse.wound@test.com', '+962790000004', 'hashed_pw_test', 'nurse', 1, 1, 1),
('ai-test-nurse-elderly', 'Nurse Ali Elderly', 'nurse.elderly@test.com', '+962790000005', 'hashed_pw_test', 'nurse', 1, 1, 1);

-- 2. Insert into CareProvider table
-- Note: Nurses have empty string for specialization as per system rules.
INSERT IGNORE INTO `careprovider` 
(`userId`, `specialization`, `serviceType`, `experienceYears`, `overallRating`, `ratingsCount`, `isAvailable`, `approvalStatus`, `status`, `hourly_rate`, `consultationFee`, `gpsLat`, `gpsLng`) VALUES
('ai-test-doc-cardio', 'Cardiology', 'Consultation', 15, 4.8, 120, 1, 'approved', 'approved', 0.00, 50.00, 31.9500000, 35.9100000),
('ai-test-doc-general', 'Family Medicine', 'Consultation', 8, 4.5, 80, 1, 'approved', 'approved', 0.00, 30.00, 31.9600000, 35.9000000),
('ai-test-doc-endo', 'Endocrinology', 'Consultation', 12, 4.9, 95, 1, 'approved', 'approved', 0.00, 45.00, 31.9400000, 35.9200000),
('ai-test-nurse-wound', '', 'Home Nursing, Wound Care, Injections', 5, 4.7, 50, 1, 'approved', 'approved', 15.00, 0.00, 31.9550000, 35.9150000),
('ai-test-nurse-elderly', '', 'Elderly Care, Medication Administration', 10, 4.6, 110, 1, 'approved', 'approved', 20.00, 0.00, 31.9650000, 35.9050000);

-- 3. Insert into specific Doctor and Nurse tables
INSERT IGNORE INTO `doctor` (`userId`) VALUES
('ai-test-doc-cardio'),
('ai-test-doc-general'),
('ai-test-doc-endo');

INSERT IGNORE INTO `nurse` (`userId`) VALUES
('ai-test-nurse-wound'),
('ai-test-nurse-elderly');

-- 4. Insert into AvailabilitySlot table
INSERT IGNORE INTO `availabilityslot` (`slot_id`, `day`, `startTime`, `endTime`, `providerUserId`) VALUES
('ai-slot-doc-cardio-mon', 'monday', '08:00:00', '16:00:00', 'ai-test-doc-cardio'),
('ai-slot-doc-cardio-tue', 'tuesday', '08:00:00', '16:00:00', 'ai-test-doc-cardio'),

('ai-slot-doc-general-wed', 'wednesday', '09:00:00', '17:00:00', 'ai-test-doc-general'),
('ai-slot-doc-general-thu', 'thursday', '09:00:00', '17:00:00', 'ai-test-doc-general'),

('ai-slot-doc-endo-sun', 'sunday', '10:00:00', '18:00:00', 'ai-test-doc-endo'),
('ai-slot-doc-endo-mon', 'monday', '10:00:00', '18:00:00', 'ai-test-doc-endo'),

('ai-slot-nurse-wound-mon', 'monday', '07:00:00', '15:00:00', 'ai-test-nurse-wound'),
('ai-slot-nurse-wound-tue', 'tuesday', '07:00:00', '15:00:00', 'ai-test-nurse-wound'),
('ai-slot-nurse-wound-wed', 'wednesday', '07:00:00', '15:00:00', 'ai-test-nurse-wound'),

('ai-slot-nurse-elderly-sun', 'sunday', '08:00:00', '20:00:00', 'ai-test-nurse-elderly'),
('ai-slot-nurse-elderly-mon', 'monday', '08:00:00', '20:00:00', 'ai-test-nurse-elderly'),
('ai-slot-nurse-elderly-tue', 'tuesday', '08:00:00', '20:00:00', 'ai-test-nurse-elderly');

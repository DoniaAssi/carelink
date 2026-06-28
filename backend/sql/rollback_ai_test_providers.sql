-- Rollback script for AI testing seed data
-- Safely deletes test users and their related data

DELETE FROM `availabilityslot` WHERE `providerUserId` IN (
  'ai-test-doc-cardio',
  'ai-test-doc-general',
  'ai-test-doc-endo',
  'ai-test-nurse-wound',
  'ai-test-nurse-elderly'
);

DELETE FROM `doctor` WHERE `userId` IN (
  'ai-test-doc-cardio',
  'ai-test-doc-general',
  'ai-test-doc-endo'
);

DELETE FROM `nurse` WHERE `userId` IN (
  'ai-test-nurse-wound',
  'ai-test-nurse-elderly'
);

DELETE FROM `careprovider` WHERE `userId` IN (
  'ai-test-doc-cardio',
  'ai-test-doc-general',
  'ai-test-doc-endo',
  'ai-test-nurse-wound',
  'ai-test-nurse-elderly'
);

DELETE FROM `user` WHERE `userId` IN (
  'ai-test-doc-cardio',
  'ai-test-doc-general',
  'ai-test-doc-endo',
  'ai-test-nurse-wound',
  'ai-test-nurse-elderly'
);

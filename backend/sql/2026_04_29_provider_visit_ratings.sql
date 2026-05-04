-- تقييم المريض لمقدم الخدمة بعد إكمال الزيارة (للوحة التوصيات و overallRating).

CREATE TABLE IF NOT EXISTS providervisitrating (
  ratingId CHAR(36) NOT NULL PRIMARY KEY,
  requestId CHAR(36) NOT NULL,
  patientUserId CHAR(36) NOT NULL,
  providerUserId CHAR(36) NOT NULL,
  stars TINYINT NOT NULL,
  comment TEXT NULL,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_pvr_request (requestId),
  KEY idx_pvr_provider (providerUserId),
  KEY idx_pvr_patient (patientUserId)
);

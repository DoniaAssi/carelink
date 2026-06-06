-- patientmedicalfile: patient-uploaded medical documents with AI processing fields.
CREATE TABLE IF NOT EXISTS patientmedicalfile (
  id            CHAR(36)        NOT NULL PRIMARY KEY,
  patientUserId CHAR(36)        NOT NULL,
  title         VARCHAR(255)    NOT NULL,
  category      VARCHAR(100)    NOT NULL DEFAULT 'other',
  description   TEXT            NULL,
  uploadDate    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fileUrl       VARCHAR(500)    NULL,
  filePath      VARCHAR(500)    NULL,
  originalName  VARCHAR(255)    NULL,
  mimeType      VARCHAR(100)    NOT NULL DEFAULT 'application/octet-stream',
  fileSize      BIGINT          NOT NULL DEFAULT 0,
  uploadedBy    CHAR(36)        NULL,
  uploadedByRole VARCHAR(32)   NOT NULL DEFAULT 'patient',
  aiProcessed   TINYINT(1)      NOT NULL DEFAULT 0,
  aiStatus      VARCHAR(32)     NOT NULL DEFAULT 'pending',
  ocrText       LONGTEXT        NULL,
  aiSummary     TEXT            NULL,
  analysisTags  TEXT            NULL,
  createdAt     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_pmf_patient (patientUserId),
  KEY idx_pmf_status  (aiStatus)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

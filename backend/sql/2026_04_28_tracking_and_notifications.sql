-- In-app notifications + live provider position on service requests (visits).

CREATE TABLE IF NOT EXISTS usernotification (
  notificationId CHAR(36) NOT NULL PRIMARY KEY,
  userId CHAR(36) NOT NULL,
  type VARCHAR(64) NOT NULL DEFAULT 'general',
  title VARCHAR(255) NOT NULL,
  body TEXT NULL,
  relatedRequestId CHAR(36) NULL,
  isRead TINYINT(1) NOT NULL DEFAULT 0,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_un_user (userId),
  KEY idx_un_created (createdAt)
);

ALTER TABLE servicerequest
  ADD COLUMN IF NOT EXISTS providerCurrentLat DECIMAL(10,7) NULL,
  ADD COLUMN IF NOT EXISTS providerCurrentLng DECIMAL(10,7) NULL,
  ADD COLUMN IF NOT EXISTS providerLocationUpdatedAt DATETIME NULL;

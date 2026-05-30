const { randomUUID } = require('crypto');
const db = require('./db');

async function ensureNotificationTable() {
  await db.execute(`
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
}

/**
 * @param {{ userId: string, type?: string, title: string, body?: string, relatedRequestId?: string|null }} opts
 */
async function insertNotification(opts) {
  await ensureNotificationTable();
  const id = randomUUID();
  const type = (opts.type || 'general').toString().slice(0, 64);
  const title = (opts.title || 'Notification').toString().slice(0, 255);
  const body = opts.body != null ? String(opts.body) : '';
  await db.execute(
    `INSERT INTO usernotification
     (notificationId, userId, type, title, body, relatedRequestId, isRead, createdAt)
     VALUES (?, ?, ?, ?, ?, ?, 0, NOW())`,
    [
      id,
      opts.userId,
      type,
      title,
      body,
      opts.relatedRequestId || null
    ]
  );
  return id;
}

module.exports = { insertNotification };

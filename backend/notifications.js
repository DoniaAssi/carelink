const { randomUUID } = require('crypto');
const db = require('./db');

/**
 * @param {{ userId: string, type?: string, title: string, body?: string, relatedRequestId?: string|null }} opts
 */
async function insertNotification(opts) {
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

const bcrypt = require('bcrypt');
const { randomUUID } = require('crypto');
const db = require('../db');

async function ensureDemoAdmin() {
  if (process.env.NODE_ENV === 'production') return;
  if (process.env.CARELINK_SEED_DEMO_ADMIN === '0') return;

  const [rows] = await db.query(
    "SELECT userId FROM user WHERE role = 'admin' LIMIT 1",
  );
  if (rows.length > 0) return;

  const userId = randomUUID();
  const email = process.env.CARELINK_DEMO_ADMIN_EMAIL || 'admin@carelink.com';
  const password = process.env.CARELINK_DEMO_ADMIN_PASSWORD || 'Admin12345';
  const hash = await bcrypt.hash(password, 10);

  const [columns] = await db.query("SHOW COLUMNS FROM user LIKE 'isActive'");
  if (columns.length > 0) {
    await db.query(
      `INSERT INTO user
        (userId, fullName, email, phone, passwordHash, role, isActive)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [userId, 'CareLink Admin', email, '0000000000', hash, 'admin', 1],
    );
  } else {
    await db.query(
      `INSERT INTO user
        (userId, fullName, email, phone, passwordHash, role)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [userId, 'CareLink Admin', email, '0000000000', hash, 'admin'],
    );
  }

  console.log(`[CareLink] Demo admin created: ${email} / ${password}`);
}

module.exports = { ensureDemoAdmin };

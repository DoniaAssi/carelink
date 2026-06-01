const fs = require('fs');
const path = require('path');
const db = require('../db');

async function migrateBase64Images() {
  try {
    console.log('[Migration] Checking for base64 profile images in MySQL user table...');
    const [rows] = await db.execute(
      "SELECT userId, profileImageUrl FROM user WHERE profileImageUrl LIKE 'data:image%'"
    );

    if (rows.length === 0) {
      console.log('[Migration] No base64 profile images found to migrate.');
      return;
    }

    console.log(`[Migration] Found ${rows.length} rows to migrate.`);
    const uploadsDir = path.join(__dirname, '..', 'uploads');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }

    for (const row of rows) {
      const { userId, profileImageUrl } = row;
      const matches = profileImageUrl.match(/^data:image\/([a-zA-Z0-9-+]+);base64,(.+)$/);
      if (!matches || matches.length !== 3) {
        console.warn(`[Migration] User ${userId} has invalid data URI format.`);
        continue;
      }

      const ext = matches[1];
      const base64Data = matches[2].replace(/\s/g, ''); // strip whitespace
      const buffer = Buffer.from(base64Data, 'base64');
      const filename = `profile_${userId}_${Date.now()}.${ext}`;
      const filePath = path.join(uploadsDir, filename);

      await fs.promises.writeFile(filePath, buffer);
      const relativeUrl = `/uploads/${filename}`;

      await db.execute(
        'UPDATE user SET profileImageUrl = ? WHERE userId = ?',
        [relativeUrl, userId]
      );
      console.log(`[Migration] User ${userId} migrated successfully. Saved to ${relativeUrl}`);
    }
    console.log('[Migration] Completed migration of base64 images.');
  } catch (err) {
    console.error('[Migration] Error during image migration:', err);
  }
}

module.exports = migrateBase64Images;

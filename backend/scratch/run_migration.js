const db = require('../db');
const fs = require('fs');
const path = require('path');

async function run() {
  try {
    const sqlPath = path.join(__dirname, '..', 'sql', '2026_06_01_add_emergency_contact.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    console.log('Running SQL:', sql);
    await db.query(sql);
    console.log('Migration completed successfully!');
  } catch (err) {
    if (err.message.includes('Duplicate column')) {
      console.log('Column already exists, skipping.');
    } else {
      console.error('Error running migration:', err.message);
    }
  } finally {
    process.exit(0);
  }
}

run();

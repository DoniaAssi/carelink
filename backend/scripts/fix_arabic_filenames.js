const db = require('../db');

async function run() {
  console.log('Fixing corrupted Arabic filenames...');
  const [rows] = await db.query('SELECT id, originalName FROM patientmedicalfile WHERE originalName LIKE "%Ø%"');
  console.log(`Found ${rows.length} potentially corrupted records.`);
  
  let fixedCount = 0;
  for (let row of rows) {
    try {
      const fixedName = Buffer.from(row.originalName, 'latin1').toString('utf8');
      await db.query('UPDATE patientmedicalfile SET originalName = ? WHERE id = ?', [fixedName, row.id]);
      console.log(`Fixed ID ${row.id}: ${row.originalName} -> ${fixedName}`);
      fixedCount++;
    } catch (e) {
      console.error(`Error fixing ID ${row.id}:`, e.message);
    }
  }
  console.log(`Fixed ${fixedCount} records successfully.`);
  process.exit(0);
}

run();

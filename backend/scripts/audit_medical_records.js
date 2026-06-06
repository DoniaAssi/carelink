const db = require('../db');

async function run() {
  const [legacy] = await db.query('SELECT * FROM patient_medical_records');
  const [canonical] = await db.query('SELECT * FROM patientmedicalfile');

  console.log('--- DATA AUDIT REPORT ---');
  console.log(`patient_medical_records rows: ${legacy.length}`);
  console.log(`patientmedicalfile rows:      ${canonical.length}`);

  const legacyIds = legacy.map(r => r.id);
  const canonicalIds = canonical.map(r => r.id);

  const onlyLegacy = legacy.filter(r => !canonicalIds.includes(r.id));
  const onlyCanonical = canonical.filter(r => !legacyIds.includes(r.id));

  console.log(`\nRecords ONLY in patient_medical_records: ${onlyLegacy.length}`);
  if (onlyLegacy.length > 0) {
    console.log(onlyLegacy.map(r => `  - ID: ${r.id} | File: ${r.file_name} | Date: ${r.created_at}`).join('\n'));
  }

  console.log(`\nRecords ONLY in patientmedicalfile:      ${onlyCanonical.length}`);
  if (onlyCanonical.length > 0) {
    console.log(onlyCanonical.map(r => `  - ID: ${r.id} | File: ${r.originalName} | Date: ${r.createdAt}`).join('\n'));
  }

  process.exit(0);
}

run().catch(e => {
  console.error(e);
  process.exit(1);
});

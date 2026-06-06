const db = require('../db');

async function migrate() {
  console.log('Starting migration from patient_medical_records to patientmedicalfile...');

  const [legacyRecords] = await db.query('SELECT * FROM patient_medical_records');
  console.log(`Found ${legacyRecords.length} records in legacy table.`);

  if (legacyRecords.length === 0) {
    console.log('No records to migrate. Exiting.');
    process.exit(0);
  }

  let migratedCount = 0;
  let skippedCount = 0;
  let errorCount = 0;

  for (const record of legacyRecords) {
    try {
      // Check if file already exists in new table by ID
      const [existing] = await db.query('SELECT id FROM patientmedicalfile WHERE id = ?', [record.id]);
      if (existing.length > 0) {
        console.log(`Record ${record.id} already migrated. Skipping.`);
        skippedCount++;
        continue;
      }

      // Convert attachments JSON to single originalName if possible
      let originalName = record.file_name || 'Legacy Upload';
      if (!record.file_name && record.attachments) {
        try {
          const arr = JSON.parse(record.attachments);
          if (Array.isArray(arr) && arr.length > 0) {
            originalName = arr[0];
          }
        } catch (e) {}
      }

      // Ensure tags is valid JSON or null for CHECK constraint
      let validTags = null;
      if (record.tags && record.tags.trim()) {
        try {
          const t = JSON.parse(record.tags);
          validTags = JSON.stringify(t);
        } catch(e) {}
      }

      // Derive relative path
      let relativePath = record.file_url || '';
      if (relativePath.includes('/uploads/')) {
        relativePath = relativePath.substring(relativePath.indexOf('uploads/'));
      }

      // Insert into canonical table
      await db.execute(
        `INSERT INTO patientmedicalfile (
          id, patientUserId, title, category, description, uploadDate,
          fileUrl, filePath, originalName, mimeType, fileSize,
          uploadedBy, uploadedByRole, aiProcessed, aiStatus, aiSummary,
          ocrText, analysisTags, createdAt, updatedAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
        [
          record.id,
          record.patient_id,
          record.title || 'Untitled',
          record.category || 'other',
          record.description || null,
          record.created_at || new Date(),
          record.file_url || '',
          relativePath,
          originalName,
          record.file_extension ? `application/${record.file_extension}` : 'application/octet-stream',
          record.file_size || 0,
          record.patient_id, // Defaulting to patient ID since uploaded_by was string "patient"
          'patient',
          record.ai_ready || 0,
          record.extracted_text_status || 'pending',
          record.medical_summary || null,
          record.extracted_text || null,
          validTags,
          record.created_at || new Date()
        ]
      );
      
      migratedCount++;
      console.log(`Migrated record ${record.id}.`);
    } catch (err) {
      console.error(`Error migrating record ${record.id}:`, err.message);
      errorCount++;
    }
  }

  console.log('--- Migration Report ---');
  console.log(`Total legacy records: ${legacyRecords.length}`);
  console.log(`Successfully migrated: ${migratedCount}`);
  console.log(`Skipped (already exists): ${skippedCount}`);
  console.log(`Errors: ${errorCount}`);
  console.log('Migration complete.');
  process.exit(0);
}

migrate();

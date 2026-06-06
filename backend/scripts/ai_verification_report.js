'use strict';

/**
 * Medical Records AI Verification Report
 * Reads directly from DB + filesystem. No code changes.
 * Run: node backend/scripts/ai_verification_report.js
 */

const path = require('path');
const fs   = require('fs');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const db = require('../db');
const uploadsDir = path.join(__dirname, '..', 'uploads');

const DIVIDER  = '═'.repeat(80);
const SECTION  = '─'.repeat(80);

function yn(val) { return (val !== null && val !== undefined && val !== '' && val !== 0) ? 'YES' : 'NO'; }
function len(val) { return val ? val.length : 0; }
function trunc(str, n = 120) { if (!str) return '(null)'; return str.length > n ? str.substring(0, n) + '...' : str; }

async function run() {
  console.log('\n' + DIVIDER);
  console.log('  CARELINK — MEDICAL RECORDS AI VERIFICATION REPORT');
  console.log('  Generated:', new Date().toISOString());
  console.log(DIVIDER + '\n');

  // ── 1. Table Structure ─────────────────────────────────────────────────────
  console.log('◉ SECTION 1: DATABASE TABLE COLUMNS\n');
  try {
    const [cols] = await db.query(`SHOW COLUMNS FROM patientmedicalfile`);
    const aiCols = ['aiStatus', 'aiProcessed', 'ocrText', 'aiSummary', 'analysisTags', 'filePath', 'mimeType'];
    for (const col of aiCols) {
      const found = cols.find(c => c.Field === col);
      console.log(`  ${col.padEnd(18)} ${found ? '✓ EXISTS  type=' + found.Type : '✗ MISSING'}`);
    }
  } catch(e) {
    console.log('  ERROR reading table columns:', e.message);
  }
  console.log();

  // ── 2. All Records ─────────────────────────────────────────────────────────
  console.log(SECTION);
  console.log('◉ SECTION 2: ALL UPLOADED RECORDS\n');
  
  let rows = [];
  try {
    [rows] = await db.query(`
      SELECT 
        id, title, patientUserId,
        filePath, mimeType, fileSize,
        aiStatus, aiProcessed,
        ocrText, aiSummary, analysisTags,
        uploadDate
      FROM patientmedicalfile
      ORDER BY uploadDate DESC
    `);
  } catch(e) {
    console.log('  ERROR querying patientmedicalfile:', e.message);
    process.exit(1);
  }

  console.log(`  Total records found: ${rows.length}\n`);

  if (rows.length === 0) {
    console.log('  No records in database.\n');
  }

  const statCounts = { pending: 0, processing: 0, processed: 0, failed: 0, other: 0 };
  const failedRecords = [];

  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    const status = (r.aiStatus || 'unknown').toLowerCase();
    statCounts[statCounts[status] !== undefined ? status : 'other']++;

    // File system check
    const filePath = r.filePath || '';
    const fileName = path.basename(filePath);
    const diskPath  = path.join(uploadsDir, fileName);
    const fileOnDisk = fileName ? fs.existsSync(diskPath) : false;
    const ext = path.extname(filePath).toLowerCase();

    // mimeType check
    const mime = (r.mimeType || '').toLowerCase();
    const isPdf   = mime.includes('pdf') || ext === '.pdf';
    const isImage = mime.startsWith('image/') || ['.jpg','.jpeg','.png','.gif','.webp','.bmp','.tiff'].includes(ext);
    const isText  = mime.includes('text') || ext === '.txt';
    const isSupportedForExtraction = isPdf || isText;

    // Tags check
    let tagsOk = 'NO';
    try {
      const t = r.analysisTags;
      if (t && t !== '[]' && t !== 'null') {
        const parsed = typeof t === 'string' ? JSON.parse(t) : t;
        tagsOk = Array.isArray(parsed) && parsed.length > 0 ? `YES (${parsed.length} tags)` : 'NO (empty)';
      }
    } catch(_) { tagsOk = 'NO (invalid JSON)'; }

    const statusIcon = { processed: '✅', pending: '⏳', processing: '🔄', failed: '❌' }[status] || '❓';

    console.log(`  Record ${i + 1}/${rows.length}`);
    console.log(`  ┌─ id:             ${r.id}`);
    console.log(`  ├─ title:          ${r.title || '(untitled)'}`);
    console.log(`  ├─ patient:        ${r.patientUserId}`);
    console.log(`  ├─ uploaded:       ${r.uploadDate || '(unknown)'}`);
    console.log(`  ├─ file path:      ${filePath || '(none)'}`);
    console.log(`  ├─ file on disk:   ${fileOnDisk ? '✓ YES' : '✗ NO  ← PROBLEM'}`);
    console.log(`  ├─ mime type:      ${r.mimeType || '(none)'}`);
    console.log(`  ├─ file ext:       ${ext || '(none)'}`);
    console.log(`  ├─ type:           ${isPdf ? 'PDF' : isImage ? 'IMAGE' : isText ? 'TEXT' : 'UNKNOWN/UNSUPPORTED'}`);
    console.log(`  ├─ aiStatus:       ${statusIcon} ${r.aiStatus || 'NULL'}`);
    console.log(`  ├─ aiProcessed:    ${r.aiProcessed !== null ? r.aiProcessed : 'NULL'}`);
    console.log(`  ├─ ocrText len:    ${len(r.ocrText)} chars`);
    console.log(`  ├─ aiSummary:      ${yn(r.aiSummary)}`);
    console.log(`  ├─ analysisTags:   ${tagsOk}`);
    console.log(`  └─ rec. engine:    ${(r.ocrText || r.aiSummary) ? 'YES — has AI data' : 'NO — no AI data to consume'}`);
    console.log();

    if (status === 'failed' || status === 'pending') {
      failedRecords.push({ r, fileOnDisk, ext, mime, isPdf, isImage, isText });
    }
  }

  // ── 3. Status Summary ──────────────────────────────────────────────────────
  console.log(SECTION);
  console.log('◉ SECTION 3: STATUS SUMMARY\n');
  console.log(`  ✅ processed:  ${statCounts.processed}`);
  console.log(`  ⏳ pending:    ${statCounts.pending}`);
  console.log(`  🔄 processing: ${statCounts.processing}`);
  console.log(`  ❌ failed:     ${statCounts.failed}`);
  console.log(`  ❓ other:      ${statCounts.other}`);
  console.log();

  // ── 4. Failed / Pending Root Cause Analysis ────────────────────────────────
  if (failedRecords.length > 0) {
    console.log(SECTION);
    console.log('◉ SECTION 4: ROOT CAUSE ANALYSIS (failed / still-pending)\n');

    for (const { r, fileOnDisk, ext, mime, isPdf, isImage, isText } of failedRecords) {
      const status = (r.aiStatus || '').toLowerCase();
      console.log(`  ── Record: "${r.title}" (${r.id})`);
      console.log(`     Status:    ${r.aiStatus}`);
      console.log(`     File:      ${r.filePath}`);
      console.log(`     Mime:      ${mime}`);
      console.log(`     Ext:       ${ext}`);
      console.log(`     On Disk:   ${fileOnDisk ? 'YES' : 'NO'}`);
      
      const causes = [];
      if (!fileOnDisk) {
        causes.push('FILE NOT FOUND ON DISK — filePath stored in DB does not match any file in uploads/');
        causes.push('  → filePath value: "' + r.filePath + '"');
        causes.push('  → Expected disk path: ' + path.join(uploadsDir, path.basename(r.filePath || '')));
      }
      if (!mime && !ext) {
        causes.push('NO MIME TYPE AND NO EXTENSION — cannot determine file type to process');
      }
      if (isImage) {
        causes.push('IMAGE FILE — OCR not implemented (intentional: returns "processed" with message)');
        if ((r.aiStatus || '') === 'failed') {
          causes.push('  → Bug: image files should set aiStatus=processed, not failed');
          causes.push('  → In processRecordAi() line ~418: image branch sets aiStatus="failed"');
        }
      }
      if (!isPdf && !isImage && !isText && fileOnDisk) {
        causes.push('UNSUPPORTED FILE FORMAT — only PDF, plain text, and images are handled');
        causes.push(`  → Actual mime: "${mime}", ext: "${ext}"`);
      }
      if (status === 'pending' && fileOnDisk) {
        causes.push('STILL PENDING — processRecordAi() was not called or crashed before updating status');
        causes.push('  → Check backend console for "Background AI processing failed:" error');
        causes.push('  → The background .catch() may have swallowed the error silently');
      }
      if (r.ocrText && r.ocrText.startsWith('Failed')) {
        causes.push(`EXTRACTION ERROR STORED IN ocrText: "${r.ocrText}"`);
      }

      if (causes.length === 0) {
        causes.push('Cause unclear — check server logs for the time of upload');
      }

      console.log('     Root causes:');
      for (const c of causes) console.log(`       • ${c}`);
      console.log();
    }
  }

  // ── 5. filePath Storage Bug Check ──────────────────────────────────────────
  console.log(SECTION);
  console.log('◉ SECTION 5: FILEPATH STORAGE ANALYSIS\n');
  for (const r of rows) {
    const fp = r.filePath || '';
    const isAbsolute  = fp.startsWith('http');
    const isRelative  = fp.startsWith('uploads/');
    const fileName    = path.basename(fp);
    const diskExists  = fileName ? fs.existsSync(path.join(uploadsDir, fileName)) : false;
    const icon = diskExists ? '✓' : '✗';
    console.log(`  ${icon} "${r.title}" → filePath="${fp}" → on disk: ${diskExists}`);
    if (isAbsolute) console.log(`      ⚠ Stored as ABSOLUTE URL — processRecordAi uses basename only, OK`);
    if (!isRelative && !isAbsolute && fp) console.log(`      ⚠ Unusual path format: "${fp}"`);
  }

  // ── 6. Image-branch Bug ────────────────────────────────────────────────────
  console.log('\n' + SECTION);
  console.log('◉ SECTION 6: KNOWN CODE BUGS IDENTIFIED\n');
  
  const controllerPath = path.join(__dirname, '..', 'controllers', 'medicalRecordController.js');
  const code = fs.readFileSync(controllerPath, 'utf8');

  console.log('  Bug #1 — Image files set aiStatus="failed" instead of "processed_no_ocr"');
  const imageBugLine = code.split('\n').findIndex(l => l.includes("mime.startsWith('image/')")) + 1;
  console.log(`  Location: medicalRecordController.js line ~${imageBugLine}`);
  console.log(`  Code:     aiStatus = 'failed';  // should be 'processed' or 'no_ocr'`);
  console.log(`  Impact:   Every image upload is marked FAILED permanently`);
  console.log();

  console.log('  Bug #2 — mimeType stored incorrectly as "application/pdf", "application/jpg" etc.');
  console.log('  Location: medicalRecordService.js insertPatientMedicalRecord() line ~299-302');
  console.log(`  Code:     mimeType = \`application/\${data.file_extension}\``);
  console.log(`  Expected: Use the actual mime type from multer (req.file.mimetype)`);
  console.log(`  Impact:   mime.startsWith('image/') never matches → falls through to UNSUPPORTED`);
  console.log(`  Example:  An image "photo.jpg" gets mimeType="application/jpg" not "image/jpeg"`);
  console.log();

  console.log('  Bug #3 — filePath stores relative path like "uploads/xxxx-file.pdf"');
  console.log('           processRecordAi() reads record.file_url (aliased from filePath)');
  console.log('           path.join(uploadsDir, path.basename(relativePath)) should work for most cases');
  console.log('           BUT if filePath starts with "/" or is an absolute URL the basename may be wrong');
  console.log();

  console.log('  Bug #4 — updatePatientMedicalRecordAi is called with { aiStatus: "processing" }');
  console.log('           but only aiStatus/aiProcessed/ocrText/aiSummary are in the UPDATE statement');
  console.log('           This is OK but aiSummary is never generated (always NULL)');
  console.log('           Impact: aiSummary always NULL → "AI Summary" section is always empty');
  console.log();

  console.log(DIVIDER);
  console.log('  END OF REPORT');
  console.log(DIVIDER + '\n');

  process.exit(0);
}

run().catch(err => {
  console.error('Report script error:', err);
  process.exit(1);
});

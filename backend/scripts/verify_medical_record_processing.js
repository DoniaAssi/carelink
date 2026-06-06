const fs = require('fs');
const path = require('path');

const db = require('../db');
const medicalRecordService = require('../services/medicalRecordService');
const { processRecordAi } = require('../controllers/medicalRecordController');

const uploadsDir = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(uploadsDir, { recursive: true });

const patientId = `ai_verify_${Date.now()}`;
const validPdfFixture = path.join(
  __dirname,
  '..',
  'node_modules',
  'pdf-parse',
  'test',
  'data',
  '01-valid.pdf'
);

const files = [
  {
    title: 'AI Verify Real PDF',
    fileName: 'ai-verify-real.pdf',
    mimeType: 'application/pdf',
    bytes: fs.readFileSync(validPdfFixture),
  },
  {
    title: 'AI Verify JPG',
    fileName: 'ai-verify.jpg',
    mimeType: 'image/jpeg',
    bytes: Buffer.from([
      0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46,
      0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48,
      0x00, 0x48, 0x00, 0x00, 0xff, 0xd9,
    ]),
  },
  {
    title: 'AI Verify PNG',
    fileName: 'ai-verify.png',
    mimeType: 'image/png',
    bytes: Buffer.from([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
      0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    ]),
  },
  {
    title: 'AI Verify TXT',
    fileName: 'ai-verify.txt',
    mimeType: 'text/plain',
    bytes: Buffer.from('Patient reports controlled hypertension. Follow up with cardiology if symptoms worsen.'),
  },
  {
    title: 'AI Verify Invalid PDF',
    fileName: 'ai-verify-invalid.pdf',
    mimeType: 'application/pdf',
    bytes: Buffer.from('This is not a real PDF file. It only has a .pdf extension.'),
  },
];

async function main() {
  const ids = [];

  for (const file of files) {
    const diskName = `${Date.now()}-${Math.random().toString(36).slice(2)}-${file.fileName}`;
    fs.writeFileSync(path.join(uploadsDir, diskName), file.bytes);

    const row = await medicalRecordService.insertPatientMedicalRecord({
      patient_id: patientId,
      title: file.title,
      category: 'Verification',
      description: 'Automated AI processing verification record',
      file_url: `/uploads/${diskName}`,
      file_name: file.fileName,
      file_extension: path.extname(file.fileName).slice(1),
      mime_type: file.mimeType,
      file_size: file.bytes.length,
      ai_ready: 0,
      extracted_text_status: 'pending',
      tags: [],
    });

    ids.push(row.id);
    await processRecordAi(row.id);
  }

  const [rows] = await db.query(
    `SELECT
       title,
       mimeType,
       aiStatus,
       aiProcessed,
       LENGTH(ocrText) AS ocrTextLength,
       aiSummary,
       analysisTags
     FROM patientmedicalfile
     WHERE id IN (?)
     ORDER BY title`,
    [ids]
  );

  console.table(rows);
  await db.end();
}

main().catch(async (err) => {
  console.error(err);
  try {
    await db.end();
  } catch (_) {}
  process.exit(1);
});

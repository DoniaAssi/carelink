const db = require('../db');
const medicalRecordService = require('../services/medicalRecordService');

async function test() {
  const patientId = 'ff269512-c653-40a9-a669-fc997b83d892';
  
  const data = {
    patient_id: patientId,
    uploaded_by: 'patient',
    record_type: 'attachment',
    title: 'Final Test Fix',
    description: 'Verifying analysisTags fix',
    category: 'Test',
    attachments: ['final_test.pdf'],
    used_for_ai_matching: true,
    ai_ready: false,
    extracted_text_status: 'pending',
    tags: [],
    file_url: '/uploads/final_test.pdf',
    file_name: 'final_test.pdf',
    file_extension: 'pdf',
    file_size: 2048,
  };

  try {
    const row = await medicalRecordService.insertPatientMedicalRecord(data);
    console.log("SUCCESS - ID:", row.id);
    
    const [dbRows] = await db.query('SELECT id, title, fileUrl, filePath, analysisTags FROM patientmedicalfile WHERE id = ?', [row.id]);
    console.log("DB RECORD:", dbRows[0]);
  } catch (e) {
    console.error("DB EXCEPTION:", e);
  }
  process.exit(0);
}

test();

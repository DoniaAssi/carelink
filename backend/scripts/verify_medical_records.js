const fs = require('fs');
const path = require('path');
const db = require('../db');
const medicalRecordService = require('../services/medicalRecordService');

async function runTests() {
  console.log('--- STARTING MEDICAL RECORDS VERIFICATION ---');
  const dummyPatientId = 'ff269512-c653-40a9-a669-fc997b83d892'; // Patient from legacy data
  
  console.log('Running direct DB insertion test (simulated upload)...');
  const newRow = await medicalRecordService.insertPatientMedicalRecord({
    patient_id: dummyPatientId,
    title: 'Direct DB Test',
    file_name: 'test.pdf',
    file_url: '/uploads/test.pdf',
    file_extension: 'pdf',
    file_size: 1024
  });
  console.log(`Inserted mock file: ID=${newRow.id}, file_url=${newRow.file_url}`);
  
  console.log('\\nTesting List for Patient (Refresh App simulation)...');
  const list = await medicalRecordService.listPatientMedicalRecordsForPatient(dummyPatientId);
  console.log(`Found ${list.length} records for patient.`);
  
  // Check URLs
  list.forEach(r => {
    console.log(`Record [${r.title}] URL: ${r.file_url}`);
  });

  console.log('\\nTesting Delete (Delete file simulation)...');
  await medicalRecordService.deletePatientMedicalRecord(newRow.id);
  
  const listAfterDelete = await medicalRecordService.listPatientMedicalRecordsForPatient(dummyPatientId);
  console.log(`Found ${listAfterDelete.length} records for patient after deletion.`);

  console.log('\\n--- FINAL DATABASE VERIFICATION ---');
  const [legacy] = await db.query('SELECT COUNT(*) as c FROM patient_medical_records');
  const [canonical] = await db.query('SELECT COUNT(*) as c FROM patientmedicalfile');
  console.log(`patient_medical_records rows: ${legacy[0].c}`);
  console.log(`patientmedicalfile rows: ${canonical[0].c}`);

  console.log('VERIFICATION COMPLETE.');
  process.exit(0);
}

runTests().catch(console.error);

const fs = require('fs');
const path = require('path');

async function testLifecycle() {
  console.log('--- STARTING FILE LIFECYCLE AUDIT ---\n');
  const baseUrl = 'http://localhost:3000';
  const patientId = 'ff269512-c653-40a9-a669-fc997b83d892';
  const headers = { 'x-user-id': patientId, 'x-user-role': 'patient' };

  // 1. Create dummy files
  fs.writeFileSync('test_jpg.jpg', 'fake-image-bytes');
  fs.writeFileSync('test_pdf.pdf', '%PDF-1.4 fake-pdf-bytes');
  fs.writeFileSync('ملف_عربي.txt', 'نص عربي للتجربة'); // Arabic file

  const files = [
    { name: 'test_jpg.jpg', type: 'image/jpeg' },
    { name: 'test_pdf.pdf', type: 'application/pdf' },
    { name: 'ملف_عربي.txt', type: 'text/plain' }
  ];

  let uploadedIds = [];

  for (let file of files) {
    console.log(`\n[UPLOAD TEST] Uploading ${file.name}...`);
    const formData = new FormData();
    formData.append('patientId', patientId);
    formData.append('title', `Test ${file.name}`);
    
    const fileBytes = fs.readFileSync(file.name);
    const blob = new Blob([fileBytes], { type: file.type });
    formData.append('file', blob, file.name);

    try {
      const res = await fetch(`${baseUrl}/medical-records/upload`, { method: 'POST', headers, body: formData });
      if (!res.ok) throw new Error(`HTTP ${res.status} - ${await res.text()}`);
      const data = await res.json();
      console.log(`SUCCESS: Uploaded ${file.name} -> ID: ${data.id}, URL: ${data.file_url}`);
      uploadedIds.push(data.id);
    } catch (e) {
      console.error(`FAILED: ${e.message}`);
    }
  }

  // 2. View/List Records
  console.log(`\n[VIEW TEST] Fetching list for patient...`);
  try {
    const res = await fetch(`${baseUrl}/medical-records/patient/${patientId}`, { headers });
    const data = await res.json();
    console.log(`SUCCESS: Fetched ${data.length} records.`);
    
    // Check if the uploaded ones are there
    for (let id of uploadedIds) {
      const record = data.find(r => r.id === id);
      if (record) {
        console.log(`- Verified ID ${id} in list. originalName: ${record.file_name}, file_url: ${record.file_url}`);
        
        // 3. Open URL
        console.log(`  [OPEN TEST] Fetching URL: ${record.file_url}`);
        const openRes = await fetch(record.file_url);
        if (openRes.ok) {
           console.log(`  SUCCESS: HTTP 200, Downloaded ${openRes.headers.get('content-length') || 0} bytes`);
        } else {
           console.error(`  FAILED: HTTP ${openRes.status}`);
        }
      } else {
        console.error(`- Error: ID ${id} missing from list.`);
      }
    }
  } catch (e) {
    console.error(`FAILED: ${e.message}`);
  }

  // 4. Delete files
  console.log(`\n[DELETE TEST] Deleting uploaded files...`);
  for (let id of uploadedIds) {
    try {
      const res = await fetch(`${baseUrl}/medical-records/upload/${id}`, { method: 'DELETE', headers });
      if (res.ok) {
        console.log(`SUCCESS: Deleted ID ${id}`);
      } else {
        console.error(`FAILED: ID ${id} - ${await res.text()}`);
      }
    } catch (e) {
       console.error(`FAILED: ${e.message}`);
    }
  }

  // Cleanup local dummies
  fs.unlinkSync('test_jpg.jpg');
  fs.unlinkSync('test_pdf.pdf');
  fs.unlinkSync('ملف_عربي.txt');
  console.log('\n--- AUDIT COMPLETE ---');
}

testLifecycle();

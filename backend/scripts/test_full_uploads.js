const fs = require('fs');
const db = require('../db');

async function testMultipleUploads() {
  const file1 = __dirname + '/test_upload_image.jpg';
  const file2 = __dirname + '/test_upload_doc.pdf';
  const file3 = __dirname + '/تجربة_رفع.txt'; // Arabic filename

  fs.writeFileSync(file1, 'fake jpg data');
  fs.writeFileSync(file2, 'fake pdf data');
  fs.writeFileSync(file3, 'fake txt data');

  async function uploadFile(path, filename) {
    const fileBlob = new Blob([fs.readFileSync(path)]);
    const formData = new FormData();
    formData.append('patientId', 'ff269512-c653-40a9-a669-fc997b83d892');
    formData.append('title', 'Test ' + filename);
    formData.append('file', fileBlob, filename);

    const res = await fetch('http://localhost:3000/medical-records/upload', {
      method: 'POST',
      headers: {
        'x-user-id': 'ff269512-c653-40a9-a669-fc997b83d892',
        'x-user-role': 'patient'
      },
      body: formData
    });
    
    if (res.status === 201) {
      const data = await res.json();
      console.log(`SUCCESS: ${filename} -> ID: ${data.id}`);
      
      // Verify DB row
      const [rows] = await db.query('SELECT id, analysisTags, originalName FROM patientmedicalfile WHERE id = ?', [data.id]);
      console.log(`DB VERIFY:`, rows[0]);
    } else {
      console.error(`FAILED: ${filename} -> STATUS: ${res.status}`);
      console.error(await res.text());
    }
  }

  await uploadFile(file1, 'test_upload_image.jpg');
  await uploadFile(file2, 'test_upload_doc.pdf');
  await uploadFile(file3, 'تجربة_رفع.txt');

  process.exit(0);
}

testMultipleUploads();

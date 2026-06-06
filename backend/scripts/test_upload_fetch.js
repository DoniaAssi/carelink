const fs = require('fs');

async function testUpload() {
  const filePath = __dirname + '/test_upload_3.txt';
  fs.writeFileSync(filePath, 'Hello world');
  
  const fileBlob = new Blob([fs.readFileSync(filePath)], { type: 'text/plain' });

  const formData = new FormData();
  formData.append('patientId', 'ff269512-c653-40a9-a669-fc997b83d892');
  formData.append('patient_id', 'ff269512-c653-40a9-a669-fc997b83d892');
  formData.append('title', 'Test Upload Title');
  formData.append('category', 'Labs');
  formData.append('notes', 'My notes');
  formData.append('description', 'My notes');
  formData.append('usedForAiMatching', 'true');
  formData.append('used_for_ai_matching', 'true');
  formData.append('aiReady', 'false');
  formData.append('ai_ready', 'false');
  formData.append('source', 'patient_upload');
  formData.append('file', fileBlob, 'test_upload_3.txt');

  try {
    const res = await fetch('http://localhost:3000/medical-records/upload', {
      method: 'POST',
      headers: {
        'x-user-id': 'ff269512-c653-40a9-a669-fc997b83d892',
        'x-user-role': 'patient'
      },
      body: formData
    });
    
    const text = await res.text();
    console.log("STATUS:", res.status);
    console.log("BODY:", text);
  } catch (err) {
    console.error("FETCH ERROR:", err);
  }
}

testUpload();

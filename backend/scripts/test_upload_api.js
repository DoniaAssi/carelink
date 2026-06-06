const fs = require('fs');
const path = require('path');
const FormData = require('form-data');
const http = require('http');

async function run() {
  const dummyFilePath = path.join(__dirname, 'test_upload_2.txt');
  fs.writeFileSync(dummyFilePath, 'This is a test file for verification.');

  const form = new FormData();
  form.append('patient_id', 'ff269512-c653-40a9-a669-fc997b83d892');
  form.append('title', 'Test API Upload');
  form.append('category', 'Test');
  form.append('notes', 'Some notes');
  form.append('usedForAiMatching', 'true');
  form.append('aiReady', 'false');
  form.append('file', fs.createReadStream(dummyFilePath), { filename: 'test_upload_2.txt' });

  const req = http.request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/medical-records/upload',
    method: 'POST',
    headers: {
      ...form.getHeaders(),
      'x-user-id': 'ff269512-c653-40a9-a669-fc997b83d892',
      'x-user-role': 'patient',
    }
  }, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      console.log('STATUS:', res.statusCode);
      console.log('BODY:', data);
    });
  });

  req.on('error', (e) => {
    console.error('Request Error:', e);
  });

  form.pipe(req);
}

run();

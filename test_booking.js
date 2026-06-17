const http = require('http');

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/patient/appointments',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  }
};

const req = http.request(options, (res) => {
  let data = '';
  res.on('data', chunk => { data += chunk; });
  res.on('end', () => {
    console.log('Status:', res.statusCode);
    console.log('Response:', data);
  });
});

req.on('error', e => {
  console.error(`Problem with request: ${e.message}`);
});

req.write(JSON.stringify({
  patientUserId: 'ce5d4b6a-958d-4b97-9e9b-2fe6b19a83c7',
  providerUserId: '22222222-ai11-4000-8000-000000000011',
  date: '2026-06-22',
  time: '09:00',
  serviceType: 'Consultation',
  status: 'pending'
}));
req.end();

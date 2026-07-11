const db = require('./db');
(async () => {
  try {
    try {
      await db.execute('INSERT INTO user (userId, role) VALUES (?, ?)', ['test-patient', 'patient']);
      await db.execute('INSERT INTO user (userId, role) VALUES (?, ?)', ['test-provider', 'doctor']);
      await db.execute('INSERT INTO careprovider (userId) VALUES (?)', ['test-provider']);
    } catch(e) {}
    
    try {
      await db.execute(
        "INSERT INTO servicerequest (requestId, patientUserId, providerUserId, status) VALUES (?, ?, ?, 'confirmed')",
        ['test-appointment-123', 'test-patient', 'test-provider']
      );
      console.log('Dummy inserted.');
    } catch(e) { console.log('Dummy insert failed:', e.message); }
    
    const res = await fetch('http://localhost:3000/patient/appointments/test-appointment-123/reschedule', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        date: '2026-08-15', 
        time: '10:00:00',
        patientUserId: 'test-patient',
        providerUserId: 'test-provider'
      })
    });
    const json = await res.json();
    console.log(res.status, json);
  } catch(e) {
    console.error(e);
  } finally {
    process.exit(0);
  }
})();

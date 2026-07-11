const db = require('./db');

async function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function runTests() {
  console.log("=== STARTING RESCHEDULE TESTS ===");
  
  // 1. Setup Data
  try {
    await db.execute('INSERT IGNORE INTO user (userId, fullName, role) VALUES (?, ?, ?)', ['pt1', 'Test Patient', 'patient']);
    await db.execute('INSERT IGNORE INTO user (userId, fullName, role) VALUES (?, ?, ?)', ['pr1', 'Test Provider', 'doctor']);
    await db.execute('INSERT IGNORE INTO careprovider (userId) VALUES (?)', ['pr1']);
    
    // Cleanup previous test runs
    await db.execute("DELETE FROM servicerequest WHERE requestId IN ('req-1', 'req-2', 'req-3')");
    await db.execute("DELETE FROM usernotification WHERE relatedRequestId IN ('req-1', 'req-2', 'req-3')");
    
    // Scenario 1 Data
    await db.execute(
      "INSERT INTO servicerequest (requestId, patientUserId, providerUserId, status, scheduledAt) VALUES (?, ?, ?, ?, ?)",
      ['req-1', 'pt1', 'pr1', 'confirmed', '2026-08-01 09:00:00']
    );
    
    // Scenario 2 Data
    await db.execute(
      "INSERT INTO servicerequest (requestId, patientUserId, providerUserId, status, scheduledAt) VALUES (?, ?, ?, ?, ?)",
      ['req-2', 'pt1', 'pr1', 'pending', '2026-08-02 09:00:00']
    );

    // Scenario 3 Data
    await db.execute(
      "INSERT INTO servicerequest (requestId, patientUserId, providerUserId, status, scheduledAt, requestedRescheduleAt) VALUES (?, ?, ?, ?, ?, ?)",
      ['req-3', 'pt1', 'pr1', 'pending_reschedule', '2026-08-03 09:00:00', '2026-08-03 10:00:00']
    );

    console.log("Database seeded successfully.\n");
  } catch (err) {
    console.error("Error setting up data:", err);
    process.exit(1);
  }

  // Helper to fetch row
  async function getRow(reqId) {
    const [rows] = await db.query("SELECT requestId, status, scheduledAt, requestedRescheduleAt FROM servicerequest WHERE requestId = ?", [reqId]);
    return rows[0];
  }
  async function getNotifications(reqId) {
    const [rows] = await db.query("SELECT type, title, body FROM usernotification WHERE relatedRequestId = ?", [reqId]);
    return rows;
  }

  // --- SCENARIO 1: Confirmed -> Pending Reschedule ---
  console.log("=== SCENARIO 1: Confirmed Appointment ===");
  const payload1 = { date: '2026-08-10', time: '14:30:00' };
  const before1 = await getRow('req-1');
  console.log("DB BEFORE:", before1);
  console.log("PAYLOAD:", payload1);
  
  const res1 = await fetch('http://localhost:3000/patient/appointments/req-1/reschedule', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload1)
  });
  const status1 = res1.status;
  const body1 = await res1.json();
  console.log("HTTP STATUS:", status1);
  console.log("RESPONSE BODY:", body1);
  
  const after1 = await getRow('req-1');
  console.log("DB AFTER:", after1);
  const notifs1 = await getNotifications('req-1');
  console.log("NOTIFICATIONS:", notifs1);
  console.log("\n");

  // --- SCENARIO 2: Pending -> Pending (Updated directly) ---
  console.log("=== SCENARIO 2: Pending Appointment ===");
  const payload2 = { date: '2026-08-20', time: '11:00:00' };
  const before2 = await getRow('req-2');
  console.log("DB BEFORE:", before2);
  console.log("PAYLOAD:", payload2);
  
  const res2 = await fetch('http://localhost:3000/patient/appointments/req-2/reschedule', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload2)
  });
  const status2 = res2.status;
  const body2 = await res2.json();
  console.log("HTTP STATUS:", status2);
  console.log("RESPONSE BODY:", body2);
  
  const after2 = await getRow('req-2');
  console.log("DB AFTER:", after2);
  const notifs2 = await getNotifications('req-2');
  console.log("NOTIFICATIONS:", notifs2);
  console.log("\n");

  // --- SCENARIO 3: Already pending_reschedule ---
  console.log("=== SCENARIO 3: Already pending_reschedule ===");
  const payload3 = { date: '2026-08-30', time: '15:00:00' };
  const before3 = await getRow('req-3');
  console.log("DB BEFORE:", before3);
  console.log("PAYLOAD:", payload3);
  
  const res3 = await fetch('http://localhost:3000/patient/appointments/req-3/reschedule', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload3)
  });
  const status3 = res3.status;
  const body3 = await res3.json();
  console.log("HTTP STATUS:", status3);
  console.log("RESPONSE BODY:", body3);
  
  const after3 = await getRow('req-3');
  console.log("DB AFTER:", after3);
  console.log("\n=== TESTS COMPLETE ===");
  
  process.exit(0);
}

runTests();

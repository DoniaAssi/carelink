const db = require('./db');
(async () => {
  try {
    const appointmentId = '20c92279-f4df-402f-8686-da0fd0ae4dbc';
    const scheduledAt = '2026-08-15 10:00:00';
    console.log('Running query...');
    await db.execute(
      "UPDATE servicerequest SET requestedRescheduleAt = ?, status = 'pending_reschedule' WHERE requestId = ?",
      [scheduledAt, appointmentId]
    );
    console.log('Query succeeded!');
  } catch (err) {
    console.error('Error:', err);
  } finally {
    process.exit(0);
  }
})();

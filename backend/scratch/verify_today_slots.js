require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mysql = require('mysql2/promise');

(async () => {
  const c = await mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });
  const [now] = await c.query('SELECT NOW() AS dbNow, CURDATE() AS dbToday');
  console.log('JS now :', new Date().toString());
  console.log('DB now :', now[0].dbNow, '| DB today:', now[0].dbToday);

  const [slots] = await c.query(
    `SELECT a.providerUserId, u.fullName, u.role, cp.isAvailable, a.day,
            a.startTime, a.endTime
     FROM availabilityslot a
     LEFT JOIN user u ON u.userId = a.providerUserId
     LEFT JOIN careprovider cp ON cp.userId = a.providerUserId
     ORDER BY a.providerUserId, a.day, a.startTime`,
  );
  console.log('total availabilityslot rows:', slots.length);
  console.table(slots.slice(0, 60));
  await c.end();
})().catch((e) => { console.error('ERR:', e.message); process.exit(1); });

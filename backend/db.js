const mysql = require('mysql2');
const path = require('path');

require('dotenv').config({ path: path.join(__dirname, '.env') });

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'carelink',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

const pool = mysql.createPool(dbConfig);

pool.getConnection((err, connection) => {
  if (err) {
    console.error('Error connecting to MySQL:', err.message);
    console.error(
      `Check backend/.env: DB_HOST=${dbConfig.host}, DB_USER=${dbConfig.user}, DB_NAME=${dbConfig.database}, DB_PASSWORD=${dbConfig.password ? 'set' : 'empty'}`
    );
    return;
  }
  console.log('Connected to MySQL database');
  connection.release();
});

module.exports = pool.promise();

const path = require('path');
const dotenv = require('dotenv');
const nodemailer = require('nodemailer');

// 5. Verify backend/.env is loaded
const envPath = path.join(__dirname, '.env');
const result = dotenv.config({ path: envPath });

if (result.error) {
  console.error("Failed to load .env:", result.error);
} else {
  console.log(".env loaded successfully.");
}

// 4. Print runtime values
console.log("Runtime Values:");
console.log("MAIL_HOST:", process.env.MAIL_HOST);
console.log("MAIL_PORT:", process.env.MAIL_PORT);
console.log("MAIL_SECURE:", process.env.MAIL_SECURE);
console.log("MAIL_REQUIRE_REAL:", process.env.MAIL_REQUIRE_REAL);
console.log("NODE_ENV:", process.env.NODE_ENV);

// Logic from verificationDispatch.js
const user = (process.env.MAIL_USER || '').trim();
const pass = (process.env.MAIL_PASS || '').trim();
const host = (process.env.MAIL_HOST || '').trim();

let transport;
if (host) {
  const port = parseInt(process.env.MAIL_PORT || '587', 10);
  const secure =
    process.env.MAIL_SECURE === '1' ||
    process.env.MAIL_SECURE === 'true' ||
    String(process.env.MAIL_SECURE || '').toLowerCase() === 'yes' ||
    port === 465;

  transport = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass },
    ...(process.env.MAIL_TLS_REJECT_UNAUTHORIZED === '0'
      ? { tls: { rejectUnauthorized: false } }
      : {}),
  });
} else {
  const service = (process.env.MAIL_SERVICE || 'gmail').trim() || 'gmail';
  transport = nodemailer.createTransport({
    service,
    auth: { user, pass },
  });
}

// 1. & 3. The exact Nodemailer transport configuration currently used
console.log("\nTransport Configuration:");
const configToPrint = { ...transport.options };
if (configToPrint.auth) {
  configToPrint.auth = { user: configToPrint.auth.user, pass: '***REDACTED***' };
}
console.dir(configToPrint, { depth: null });

// 6. & 7. Test SMTP transport with verify() and get exact reason
console.log("\nTesting SMTP connection with verify()...");
transport.verify()
  .then(() => {
    console.log("Connection successful.");
  })
  .catch((err) => {
    console.error("\nSMTP VERIFY ERROR:");
    console.error(err);
    console.error("\nStack Trace:");
    console.error(err.stack);
  });

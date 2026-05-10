const path = require('path');
const envPath = path.join(__dirname, '.env');
require('dotenv').config({ path: envPath });

const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const providerRoutes = require('./routes/providers');
const patientRoutes = require('./routes/patient');
const medicalRecordRoutes = require('./routes/medicalRecordRoutes');
const paymentRoutes = require('./routes/payments');
const nurseRoutes = require('./routes/nurse');
const emailAuthFlowRoutes = require('./routes/emailAuthFlow');
const graduationAiDemoRoutes = require('./routes/graduationAiDemoRoutes');
const signupProof = require('./services/signupVerificationProof');

const app = express();

app.use(cors());
// Default 100kb is too small for data:image base64 profile photos.
app.use(express.json({ limit: '12mb' }));
app.use(express.urlencoded({ extended: true, limit: '12mb' }));

app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'CareLink backend is running',
  });
});

app.use('/api/email-auth', emailAuthFlowRoutes);
app.use('/demo/graduation-flow', graduationAiDemoRoutes);
app.use('/auth', authRoutes);
app.use('/providers', providerRoutes);
app.use('/patient', patientRoutes);
app.use('/medical-records', medicalRecordRoutes);
app.use('/payments', paymentRoutes);
app.use('/nurse', nurseRoutes);

const PORT = process.env.PORT || 3000;

const mailConfigured =
  !!(process.env.MAIL_USER && String(process.env.MAIL_USER).trim()) &&
  !!(process.env.MAIL_PASS && String(process.env.MAIL_PASS).trim());

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(
    '[CareLink] Email OTP: GET /api/email-auth/health — POST /api/email-auth/register',
  );
  if (!mailConfigured) {
    console.warn(
      '[CareLink] MAIL_USER / MAIL_PASS are empty — no verification email is sent.\n' +
        `         Edit this file (same folder as server.js), save, then restart:\n` +
        `         ${envPath}`,
    );
    console.warn(
      '[CareLink] Gmail: use an App Password (Account → Security → 2-Step → App passwords).',
    );
  } else {
    console.log(
      '[CareLink] Email (SMTP) is configured — signup verification codes will be sent to the user inbox.',
    );
  }
  const mailRequireReal = String(process.env.MAIL_REQUIRE_REAL || '')
    .toLowerCase()
    .trim();
  if (['1', 'true', 'yes'].includes(mailRequireReal)) {
    console.log(
      '[CareLink] MAIL_REQUIRE_REAL is on — verification email must succeed over SMTP (no simulated delivery).',
    );
  }
  const twilioReady =
    String(process.env.TWILIO_ACCOUNT_SID || '').trim() &&
    String(process.env.TWILIO_AUTH_TOKEN || '').trim() &&
    String(process.env.TWILIO_FROM_NUMBER || '').trim();
  if (!twilioReady) {
    console.warn(
      '[CareLink] Twilio env missing — phone OTP is simulated in development only.',
    );
  } else {
    console.log('[CareLink] Twilio is configured — SMS codes will be sent.');
  }
  signupProof.ensureTable().catch((e) => {
    console.error(
      '[CareLink] Could not ensure signup_verification_proof table:',
      e.message,
    );
  });
});
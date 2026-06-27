const path = require('path');

require('dotenv').config({ path: path.join(__dirname, '.env') });

console.log('[STARTUP] Checking Environment Variables:');
console.log(`- Loaded .env path: ${path.join(__dirname, '.env')}`);
console.log(`- MAIL_USER exists: ${!!process.env.MAIL_USER}`);
console.log(`- MAIL_FROM value: ${process.env.MAIL_FROM || 'not set'}`);
console.log(`- MAIL_HOST: ${process.env.MAIL_HOST || 'not set'}`);
console.log(`- MAIL_PORT: ${process.env.MAIL_PORT || 'not set'}`);
console.log(`- MAIL_REQUIRE_REAL: ${process.env.MAIL_REQUIRE_REAL || 'not set'}`);
console.log(`- NODE_ENV: ${process.env.NODE_ENV || 'not set'}`);
console.log('----------------------------------------');
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const providerRoutes = require('./routes/providers');
const patientRoutes = require('./routes/patient');
const doctorRoutes = require('./routes/doctor');
const medicalRecordRoutes = require('./routes/medicalRecordRoutes');
const paymentRoutes = require('./routes/payments');
const nurseRoutes = require('./routes/nurse');
const notificationsRoutes = require('./routes/notifications');
const emailAuthFlowRoutes = require('./routes/emailAuthFlow');
const graduationAiDemoRoutes = require('./routes/graduationAiDemoRoutes');
const ratingsApiRoutes = require('./routes/ratingsApi');
const paymentsApiRoutes = require('./routes/paymentsApi');
const adminRoutes = require('./routes/admin');
const recommendationRoutes = require('./routes/recommendationRoutes');
const signupProof = require('./services/signupVerificationProof');
const adminBootstrap = require('./services/adminBootstrap');

const app = express();

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '12mb' }));

// Serve uploaded files
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'CareLink backend is running',
  });
});

app.use('/api/email-auth', emailAuthFlowRoutes);
app.use('/api/ratings', ratingsApiRoutes);
app.use('/api/payments', paymentsApiRoutes);
app.use('/admin', adminRoutes);
app.use('/demo/graduation-flow', graduationAiDemoRoutes);
app.use('/auth', authRoutes);
app.use('/api/auth', authRoutes);
app.use('/providers', providerRoutes);
app.use('/patient', patientRoutes);
app.use('/doctor', doctorRoutes);
app.use('/medical-records', medicalRecordRoutes);
app.use('/api/medical-records', medicalRecordRoutes);
app.use('/api/recommendations', recommendationRoutes);
app.use('/payments', paymentRoutes);
app.use('/nurse', nurseRoutes);
app.use('/notifications', notificationsRoutes);

const PORT = process.env.PORT || 3000;

const mailConfigured =
  !!(process.env.MAIL_USER && String(process.env.MAIL_USER).trim()) &&
  !!(process.env.MAIL_PASS && String(process.env.MAIL_PASS).trim());

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(
    '[CareLink] Email OTP: GET /api/email-auth/health - POST /api/email-auth/register',
  );
  if (!mailConfigured) {
    console.warn(
      '[CareLink] MAIL_USER / MAIL_PASS are empty - no verification email is sent.\n' +
        '         Edit backend/.env, save, then restart.',
    );
    console.warn(
      '[CareLink] Gmail: use an App Password (Account -> Security -> 2-Step -> App passwords).',
    );
  } else {
    console.log(
      '[CareLink] Email (SMTP) is configured - signup verification codes will be sent to the user inbox.',
    );
  }
  const mailRequireReal = String(process.env.MAIL_REQUIRE_REAL || '')
    .toLowerCase()
    .trim();
  if (['1', 'true', 'yes'].includes(mailRequireReal)) {
    console.log(
      '[CareLink] MAIL_REQUIRE_REAL is on - verification email must succeed over SMTP (no simulated delivery).',
    );
  }
  const twilioReady =
    String(process.env.TWILIO_ACCOUNT_SID || '').trim() &&
    String(process.env.TWILIO_AUTH_TOKEN || '').trim() &&
    String(process.env.TWILIO_FROM_NUMBER || '').trim();
  if (!twilioReady) {
    console.warn(
      '[CareLink] Twilio env missing - phone OTP is simulated in development only.',
    );
  } else {
    console.log('[CareLink] Twilio is configured - SMS codes will be sent.');
  }
  signupProof.ensureTable().catch((e) => {
    console.error(
      '[CareLink] Could not ensure signup_verification_proof table:',
      e.message,
    );
  });
  adminBootstrap.ensureDemoAdmin().catch((e) => {
    console.error('[CareLink] Could not ensure demo admin:', e.message);
  });
});

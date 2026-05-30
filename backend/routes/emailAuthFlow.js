const express = require('express');
const jwt = require('jsonwebtoken');
const db = require('../db');
const emailOtp = require('../services/emailOtpService');
const { isConfiguredMail } = require('../services/verificationDispatch');
const {
  validateUnifiedSignupBody,
  savePendingRegistration,
  randomUUID,
} = require('../services/emailAuthUnifiedSignup');

const router = express.Router();

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function buildRegisterPayload(userId, email, role, mailResult, messageSuffix) {
  return {
    ok: true,
    userId,
    email,
    role,
    verificationSentTo: email,
    emailActuallySent: mailResult.channel === 'smtp',
    message:
      mailResult.channel === 'smtp'
        ? `Verification code sent to your email${messageSuffix}`
        : `We could not send email. Configure MAIL_* in the server environment and try resend.`,
  };
}

function issueOptionalJwt(user) {
  const secret = String(process.env.JWT_SECRET || '').trim();
  if (!secret) return null;
  return jwt.sign(
    {
      sub: user.userId,
      email: user.email,
      role: user.role,
    },
    secret,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' },
  );
}

/**
 * POST /register
 * Body: fullName, email, phone, password, role (patient|nurse|doctor),
 *       + patient: addressText, optional gpsLat/Lng, dateOfBirth, gender, chronicDiseases, allergies, currentMedications, profileImageUrl
 *       + nurse/doctor: specialization, optional licenseNumber, serviceType, experienceYears, addressText (clinic/affiliation), gpsLat/Lng, profileImageUrl
 */
router.post('/register', async (req, res) => {
  const parsed = validateUnifiedSignupBody(req.body);
  if (!parsed.ok) {
    return res.status(parsed.status).json({ error: parsed.error });
  }
  const v = parsed.d;

  try {
    const hasVerified = await emailOtp.userHasVerifiedColumn();

    const [existingRows] = await db.query(
      hasVerified
        ? 'SELECT userId, role, is_verified FROM user WHERE email = ? LIMIT 1'
        : 'SELECT userId, role FROM user WHERE email = ? LIMIT 1',
      [v.email],
    );

    let userId;
    let isResume = false;
    let httpStatus = 201;
    let suffix = '';

    if (existingRows.length > 0) {
      const ex = existingRows[0];
      const fullyRegistered =
        hasVerified && Number(ex.is_verified) === 1;
      if (fullyRegistered) {
        return res.status(409).json({
          error: 'Email already registered',
          detail: 'email_verified',
          hint: 'Sign in with this email, or use Forgot password.',
        });
      }
      const existingRole = String(ex.role || '').toLowerCase();
      if (existingRole !== v.role) {
        return res.status(409).json({
          error: 'This email is already pending registration with a different role',
          detail: 'role_mismatch',
          hint: `Use the same role as the pending account (${existingRole}), or a different email.`,
        });
      }
      userId = ex.userId;
      isResume = true;
      httpStatus = 200;
      suffix = ' (continuing previous signup)';
    } else {
      userId = randomUUID();
    }

    await savePendingRegistration(db, v, { isResume, userId });

    const { plainCode } = await emailOtp.issueOtpForEmail(v.email);
    const mailResult = await emailOtp.sendOtpEmail(v.email, plainCode);

    return res.status(httpStatus).json(
      buildRegisterPayload(userId, v.email, v.role, mailResult, suffix),
    );
  } catch (err) {
    if (err.statusCode === 429) {
      return res.status(429).json({
        error: err.message,
        retryAfterSeconds: err.retryAfterSeconds,
      });
    }
    console.error('email-auth register:', err);
    return res.status(500).json({ error: err.message || 'Registration failed' });
  }
});

router.post('/verify-email', async (req, res) => {
  const email = String(req.body.email || '').trim().toLowerCase();
  const code = String(req.body.code || '').trim();

  if (!email || !code) {
    return res.status(400).json({ error: 'email and code are required' });
  }
  if (!emailRegex.test(email)) {
    return res.status(400).json({ error: 'Invalid email format' });
  }

  try {
    await emailOtp.verifyOtpAndConsume(email, code);

    const hasVerified = await emailOtp.userHasVerifiedColumn();
    if (hasVerified) {
      await db.query('UPDATE user SET is_verified = 1 WHERE email = ?', [email]);
    }

    const [rows] = await db.query(
      'SELECT userId, fullName, email, phone, role FROM user WHERE email = ? LIMIT 1',
      [email],
    );

    if (rows.length === 0) {
      return res.status(400).json({ error: 'User not found' });
    }

    const user = rows[0];
    const token = issueOptionalJwt(user);

    return res.json({
      ok: true,
      verified: true,
      message: 'Email verified successfully',
      user,
      ...(token ? { token } : {}),
    });
  } catch (err) {
    const status = err.statusCode || 500;
    if (status >= 500) console.error('email-auth verify-email:', err);
    return res.status(status).json({ error: err.message });
  }
});

router.post('/resend-code', async (req, res) => {
  const email = String(req.body.email || '').trim().toLowerCase();
  if (!email || !emailRegex.test(email)) {
    return res.status(400).json({ error: 'Valid email is required' });
  }

  try {
    const [users] = await db.query(
      'SELECT userId, email FROM user WHERE email = ? LIMIT 1',
      [email],
    );
    if (users.length === 0) {
      return res.status(404).json({ error: 'No registration found for this email' });
    }

    const hasVerified = await emailOtp.userHasVerifiedColumn();
    if (hasVerified) {
      const [v] = await db.query(
        'SELECT is_verified FROM user WHERE email = ? LIMIT 1',
        [email],
      );
      if (v.length && Number(v[0].is_verified) === 1) {
        return res.status(400).json({ error: 'This email is already verified' });
      }
    }

    const { plainCode } = await emailOtp.issueOtpForEmail(email);
    const mailResult = await emailOtp.sendOtpEmail(email, plainCode);

    return res.json({
      ok: true,
      email,
      verificationSentTo: email,
      emailActuallySent: mailResult.channel === 'smtp',
      message:
        mailResult.channel === 'smtp'
          ? 'A new verification code was sent to your email'
          : 'Could not send email. Configure SMTP on the server, then try again.',
    });
  } catch (err) {
    if (err.statusCode === 429) {
      return res.status(429).json({
        error: err.message,
        retryAfterSeconds: err.retryAfterSeconds,
      });
    }
    console.error('email-auth resend:', err);
    return res.status(500).json({ error: err.message || 'Failed to resend code' });
  }
});

router.get('/health', (req, res) => {
  const smtpEnvConfigured = isConfiguredMail();
  res.json({
    ok: true,
    service: 'email-auth',
    smtpEnvConfigured,
    jwtConfigured: !!(process.env.JWT_SECRET && String(process.env.JWT_SECRET).trim()),
    hint: smtpEnvConfigured
      ? 'SMTP credentials are set in process.env (restart server after changing .env).'
      : 'Set MAIL_USER and MAIL_PASS in backend/.env — see server startup path in console.',
    build: '2026-06-unified-roles',
    endpoints: ['POST /register', 'POST /verify-email', 'POST /resend-code'],
  });
});

module.exports = router;

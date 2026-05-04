const express = require('express');
const bcrypt = require('bcrypt');
const { randomUUID, randomBytes } = require('crypto');
const { OAuth2Client } = require('google-auth-library');
const appleSigninAuth = require('apple-signin-auth');
const db = require('../db');
const verificationCodes = require('../services/verificationCodes');
const {
  dispatchEmailVerificationCode,
  dispatchSmsVerificationCode,
  isProduction,
  sendTransactionalEmail,
  isConfiguredMail,
} = require('../services/verificationDispatch');

const router = express.Router();
const googleClient = new OAuth2Client();
const columnCache = new Map();

const SIGNUP_PROOF_TTL_MS = 15 * 60 * 1000;

/** After successful email-code verification for signup: token -> { email, expiresAt } */
const emailVerificationSecrets = new Map();
/** After successful phone-code verification for signup: token -> { phone, expiresAt } */
const phoneVerificationSecrets = new Map();

function normalizePhoneDigits(phone) {
  return String(phone || '').replace(/\D/g, '');
}

function pruneEmailVerificationSecrets() {
  const now = Date.now();
  for (const [k, v] of emailVerificationSecrets.entries()) {
    if (v.expiresAt < now) emailVerificationSecrets.delete(k);
  }
}

function prunePhoneVerificationSecrets() {
  const now = Date.now();
  for (const [k, v] of phoneVerificationSecrets.entries()) {
    if (v.expiresAt < now) phoneVerificationSecrets.delete(k);
  }
}

function exposeDevVerificationCode() {
  if (isProduction()) return false;
  if (process.env.CARELINK_EXPOSE_DEV_CODES === '0') return false;
  return true;
}

async function performPasswordResetWithToken(token, newPassword) {
  const strongPasswordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;
  if (!newPassword || !strongPasswordRegex.test(newPassword)) {
    const err = new Error(
      'Password must be at least 8 chars and include upper, lower, and number'
    );
    err.statusCode = 400;
    throw err;
  }

  const [rows] = await db.query(
    'SELECT userId, resetTokenExpires FROM user WHERE resetToken = ?',
    [token]
  );

  if (rows.length === 0) {
    const err = new Error('Invalid or expired token');
    err.statusCode = 400;
    throw err;
  }

  const user = rows[0];
  if (!user.resetTokenExpires || new Date(user.resetTokenExpires) < new Date()) {
    const err = new Error('Invalid or expired token');
    err.statusCode = 400;
    throw err;
  }

  const hashedPassword = await bcrypt.hash(newPassword, 10);
  await db.query(
    'UPDATE user SET passwordHash = ?, resetToken = NULL, resetTokenExpires = NULL WHERE userId = ?',
    [hashedPassword, user.userId]
  );

  return { message: 'Password reset successful' };
}

router.get('/social/config', (req, res) => {
  res.json({
    googleClientId: process.env.GOOGLE_CLIENT_ID || '',
    googleServerClientId: process.env.GOOGLE_SERVER_CLIENT_ID || '',
    facebookAppId: process.env.FACEBOOK_APP_ID || '',
    appleClientId: process.env.APPLE_CLIENT_ID || '',
    appleRedirectUrl: process.env.APPLE_REDIRECT_URL || '',
  });
});

function normalizeRole(role) {
  const value = (role || '').toString().toLowerCase();
  if (['patient', 'doctor', 'nurse', 'admin'].includes(value)) {
    return value;
  }
  return 'patient';
}

async function hasColumn(tableName, columnName) {
  const key = `${tableName}.${columnName}`;
  if (columnCache.has(key)) return columnCache.get(key);

  try {
    const [rows] = await db.query(
      `SHOW COLUMNS FROM ${tableName} LIKE ?`,
      [columnName]
    );
    const exists = rows.length > 0;
    columnCache.set(key, exists);
    return exists;
  } catch (_) {
    columnCache.set(key, false);
    return false;
  }
}

function syntheticEmail(provider, providerId) {
  return `${provider}_${providerId}@carelink.social.local`;
}

function randomPhone() {
  const min = 1000000000;
  const max = 9999999999;
  return String(Math.floor(Math.random() * (max - min + 1)) + min);
}

async function createRoleRow(connection, userId, role) {
  if (role === 'patient') {
    await connection.query(
      'INSERT INTO patient (userId, gpsLat, gpsLng, addressText) VALUES (?, ?, ?, ?)',
      [userId, 0, 0, 'Social registration']
    );
    return;
  }

  if (role === 'doctor' || role === 'nurse') {
    await connection.query(
      'INSERT INTO careprovider (userId, specialization, overallRating, isAvailable, gpsLat, gpsLng) VALUES (?, ?, ?, ?, ?, ?)',
      [userId, 'General', 0.0, 1, null, null]
    );

    if (role === 'doctor') {
      await connection.query('INSERT INTO doctor (userId) VALUES (?)', [userId]);
    } else {
      await connection.query('INSERT INTO nurse (userId) VALUES (?)', [userId]);
    }
  }
}

async function getOrCreateSocialUser({
  provider,
  providerId,
  email,
  fullName,
  role,
}) {
  const normalizedRole = normalizeRole(role);
  const safeEmail = (email || '').trim().toLowerCase();
  const safeFullName = (fullName || 'CareLink User').trim() || 'CareLink User';

  if (!safeEmail) {
    throw new Error(`${provider} did not return an email`);
  }

  const [existingRows] = await db.query(
    'SELECT userId, fullName, email, phone, role FROM user WHERE email = ? LIMIT 1',
    [safeEmail]
  );

  if (existingRows.length > 0) {
    return existingRows[0];
  }

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();

    const userId = randomUUID();
    const generatedPasswordHash = await bcrypt.hash(
      randomBytes(24).toString('hex'),
      10
    );

    let phone = randomPhone();
    let tries = 0;
    while (tries < 5) {
      const [phoneRows] = await connection.query(
        'SELECT userId FROM user WHERE phone = ? LIMIT 1',
        [phone]
      );
      if (phoneRows.length === 0) break;
      phone = randomPhone();
      tries += 1;
    }

    await connection.query(
      'INSERT INTO user (userId, fullName, email, phone, passwordHash, role) VALUES (?, ?, ?, ?, ?, ?)',
      [userId, safeFullName, safeEmail, phone, generatedPasswordHash, normalizedRole]
    );

    await createRoleRow(connection, userId, normalizedRole);
    await connection.commit();

    return {
      userId,
      fullName: safeFullName,
      email: safeEmail,
      phone,
      role: normalizedRole,
      provider,
      providerId,
    };
  } catch (err) {
    if (connection) {
      await connection.rollback();
    }
    throw err;
  } finally {
    if (connection) {
      connection.release();
    }
  }
}

router.post('/register', async (req, res) => {
  console.log('REGISTER BODY:', req.body);

  const {
    fullName,
    email,
    phone,
    password,
    role,
    specialization,
    addressText,
    gpsLat,
    gpsLng,
    confirmPassword,
    dateOfBirth,
    gender,
    profileImageUrl,
    experienceYears,
    licenseNumber,
    serviceType,
    chronicDiseases,
    allergies,
    currentMedications,
    phoneVerificationToken,
    emailVerificationToken,
  } = req.body;

  const normalizedFullName = (fullName || '').toString().trim();
  const normalizedEmail = (email || '').toString().trim().toLowerCase();
  const normalizedPhone = (phone || '').toString().trim();
  const phoneDigits = normalizePhoneDigits(normalizedPhone);
  const normalizedPhoneVerification = (phoneVerificationToken || '').toString().trim();
  const normalizedEmailVerification = (emailVerificationToken || '').toString().trim();
  const normalizedRole = normalizeRole(role);
  const normalizedSpecialization = (specialization || '').toString().trim();
  const normalizedAddress = (addressText || '').toString().trim();
  const normalizedGender = (gender || '').toString().trim().toLowerCase();
  const normalizedLicense = (licenseNumber || '').toString().trim();
  const normalizedServiceType = (serviceType || '').toString().trim();
  const normalizedProfileImageUrl = (profileImageUrl || '').toString().trim();
  const normalizedPassword = (password || '').toString();
  const normalizedConfirmPassword = (confirmPassword || '').toString();
  const parsedExperience = Number.isFinite(Number(experienceYears))
    ? Number(experienceYears)
    : null;
  const parsedGpsLat =
    gpsLat == null || gpsLat === '' ? null : Number(gpsLat);
  const parsedGpsLng =
    gpsLng == null || gpsLng === '' ? null : Number(gpsLng);

  if (!normalizedFullName || !normalizedEmail || !normalizedPhone || !normalizedPassword || !normalizedRole) {
    return res.status(400).json({
      error: 'Missing required fields: fullName, email, phone, password, role'
    });
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(normalizedEmail)) {
    return res.status(400).json({ error: 'Invalid email format' });
  }

  if (!/^\d{8,15}$/.test(phoneDigits)) {
    return res.status(400).json({ error: 'Phone must be numeric and 8-15 digits' });
  }

  if (!normalizedPhoneVerification || !normalizedEmailVerification) {
    return res.status(400).json({
      error:
        'Email and phone must be verified. Complete verification codes for both.',
    });
  }

  pruneEmailVerificationSecrets();
  const emailVerifyEntry = emailVerificationSecrets.get(normalizedEmailVerification);
  if (!emailVerifyEntry || emailVerifyEntry.expiresAt < Date.now()) {
    return res.status(400).json({ error: 'Invalid or expired email verification' });
  }
  if ((emailVerifyEntry.email || '').toLowerCase() !== normalizedEmail) {
    return res.status(400).json({ error: 'Email verification does not match' });
  }
  emailVerificationSecrets.delete(normalizedEmailVerification);

  prunePhoneVerificationSecrets();
  const phoneVerifyEntry = phoneVerificationSecrets.get(normalizedPhoneVerification);
  if (!phoneVerifyEntry || phoneVerifyEntry.expiresAt < Date.now()) {
    return res.status(400).json({ error: 'Invalid or expired phone verification' });
  }
  if (normalizePhoneDigits(phoneVerifyEntry.phone) !== phoneDigits) {
    return res.status(400).json({ error: 'Phone verification does not match this number' });
  }
  phoneVerificationSecrets.delete(normalizedPhoneVerification);

  if (normalizedFullName.length < 2 || /^\d+$/.test(normalizedFullName)) {
    return res.status(400).json({ error: 'Invalid full name' });
  }

  const strongPasswordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;
  if (!strongPasswordRegex.test(normalizedPassword)) {
    return res.status(400).json({
      error: 'Password must be at least 8 chars and include upper, lower, and number'
    });
  }

  if (normalizedConfirmPassword && normalizedConfirmPassword !== normalizedPassword) {
    return res.status(400).json({ error: 'Password and confirmPassword do not match' });
  }

  const validRoles = ['patient', 'nurse', 'doctor', 'admin'];
  if (!validRoles.includes(normalizedRole)) {
    return res.status(400).json({
      error: 'Invalid role. Must be one of: patient, nurse, doctor, admin'
    });
  }

  if (normalizedRole === 'patient') {
    if (!normalizedAddress) {
      return res.status(400).json({
        error: 'Patients must provide addressText'
      });
    }
    if (normalizedGender) {
      const allowedGenders = ['male', 'female', 'other', 'prefer_not_to_say'];
      if (!allowedGenders.includes(normalizedGender)) {
        return res.status(400).json({
          error: 'gender must be one of: male, female, other, prefer_not_to_say'
        });
      }
    }
  } else if (normalizedRole === 'nurse' || normalizedRole === 'doctor') {
    if (!normalizedSpecialization) {
      return res.status(400).json({
        error: 'Nurses and providers must provide specialization'
      });
    }
    if (parsedExperience != null && (parsedExperience < 0 || parsedExperience > 80)) {
      return res.status(400).json({
        error: 'experienceYears must be between 0 and 80'
      });
    }
  }

  let connection;

  try {
    const [existingUser] = await db.query(
      'SELECT userId FROM user WHERE email = ?',
      [normalizedEmail]
    );

    if (existingUser.length > 0) {
      return res.status(409).json({ error: 'Email already exists' });
    }

    // Phone may match other accounts; email is the unique sign-in identity.

    const hashedPassword = await bcrypt.hash(normalizedPassword, 10);
    const userId = randomUUID();

    connection = await db.getConnection();
    await connection.beginTransaction();

    const hasProfileImageUrl = await hasColumn('user', 'profileImageUrl');
    if (hasProfileImageUrl) {
      await connection.query(
        `INSERT INTO user
           (userId, fullName, email, phone, passwordHash, role, profileImageUrl)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          userId,
          normalizedFullName,
          normalizedEmail,
          phoneDigits,
          hashedPassword,
          normalizedRole,
          normalizedProfileImageUrl || null
        ]
      );
    } else {
      await connection.query(
        'INSERT INTO user (userId, fullName, email, phone, passwordHash, role) VALUES (?, ?, ?, ?, ?, ?)',
        [userId, normalizedFullName, normalizedEmail, phoneDigits, hashedPassword, normalizedRole]
      );
    }

    if (normalizedRole === 'patient') {
      const hasPatientDob = await hasColumn('patient', 'dateOfBirth');
      const hasPatientGender = await hasColumn('patient', 'gender');
      const hasChronic = await hasColumn('patient', 'chronicDiseases');
      const hasAllergies = await hasColumn('patient', 'allergies');
      const hasMeds = await hasColumn('patient', 'currentMedications');

      const patientColumns = ['userId', 'gpsLat', 'gpsLng', 'addressText'];
      const patientValues = [
        userId,
        Number.isFinite(parsedGpsLat) ? parsedGpsLat : 0,
        Number.isFinite(parsedGpsLng) ? parsedGpsLng : 0,
        normalizedAddress
      ];

      if (hasPatientDob) {
        patientColumns.push('dateOfBirth');
        patientValues.push(dateOfBirth || null);
      }
      if (hasPatientGender) {
        patientColumns.push('gender');
        patientValues.push(normalizedGender || null);
      }
      if (hasChronic) {
        patientColumns.push('chronicDiseases');
        patientValues.push(
          (chronicDiseases ?? '').toString().trim() || null
        );
      }
      if (hasAllergies) {
        patientColumns.push('allergies');
        patientValues.push((allergies ?? '').toString().trim() || null);
      }
      if (hasMeds) {
        patientColumns.push('currentMedications');
        patientValues.push(
          (currentMedications ?? '').toString().trim() || null
        );
      }

      await connection.query(
        `INSERT INTO patient (${patientColumns.join(', ')})
         VALUES (${patientColumns.map(() => '?').join(', ')})`,
        patientValues
      );
    } else if (normalizedRole === 'doctor' || normalizedRole === 'nurse') {
      const hasExperienceYears = await hasColumn('careprovider', 'experienceYears');
      const hasLicenseNumber = await hasColumn('careprovider', 'licenseNumber');
      const hasServiceType = await hasColumn('careprovider', 'serviceType');
      const hasProviderAddress = await hasColumn('careprovider', 'providerAddress');

      const providerColumns = [
        'userId',
        'specialization',
        'overallRating',
        'isAvailable',
        'gpsLat',
        'gpsLng'
      ];
      const providerValues = [
        userId,
        normalizedSpecialization,
        0.0,
        1,
        Number.isFinite(parsedGpsLat) ? parsedGpsLat : null,
        Number.isFinite(parsedGpsLng) ? parsedGpsLng : null
      ];

      if (hasExperienceYears) {
        providerColumns.push('experienceYears');
        providerValues.push(parsedExperience ?? 0);
      }
      if (hasLicenseNumber) {
        providerColumns.push('licenseNumber');
        providerValues.push(normalizedLicense || null);
      }
      if (hasServiceType) {
        providerColumns.push('serviceType');
        providerValues.push(normalizedServiceType || null);
      }
      if (hasProviderAddress) {
        providerColumns.push('providerAddress');
        providerValues.push(normalizedAddress || null);
      }

      await connection.query(
        `INSERT INTO careprovider (${providerColumns.join(', ')})
         VALUES (${providerColumns.map(() => '?').join(', ')})`,
        providerValues
      );

      if (normalizedRole === 'doctor') {
        await connection.query(
          'INSERT INTO doctor (userId) VALUES (?)',
          [userId]
        );
      } else {
        await connection.query(
          'INSERT INTO nurse (userId) VALUES (?)',
          [userId]
        );
      }
    }

    await connection.commit();

    res.status(201).json({
      message: 'User registered successfully',
      userId,
      role: normalizedRole
    });
  } catch (err) {
    console.error('REGISTER ERROR:', err);

    if (connection) {
      await connection.rollback();
    }

    res.status(500).json({ error: err.message });
  } finally {
    if (connection) {
      connection.release();
    }
  }
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const normalizedEmail = (email || '').toString().trim().toLowerCase();

  if (!normalizedEmail || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    const [rows] = await db.query(
      'SELECT userId, fullName, email, phone, role, passwordHash FROM user WHERE email = ?',
      [normalizedEmail]
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = rows[0];
    const isValid = await bcrypt.compare(password, user.passwordHash);

    if (!isValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    delete user.passwordHash;

    res.json({
      message: 'Login successful',
      user
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

async function checkEmailExistsHandler(req, res) {
  const normalizedEmail = (req.body.email || '').toString().trim().toLowerCase();
  if (!normalizedEmail) {
    return res.status(400).json({ error: 'email is required' });
  }
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(normalizedEmail)) {
    return res.status(400).json({ error: 'Invalid email format' });
  }
  try {
    const [rows] = await db.query(
      'SELECT userId FROM user WHERE email = ? LIMIT 1',
      [normalizedEmail]
    );
    return res.json({ exists: rows.length > 0 });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
}

router.post('/check-email', checkEmailExistsHandler);
router.post('/validate-email', checkEmailExistsHandler);

router.post('/send-email-code', async (req, res) => {
  const purpose = ((req.body.purpose || 'signup') + '').toLowerCase();
  const normalizedEmail = (req.body.email || '').toString().trim().toLowerCase();
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!normalizedEmail || !emailRegex.test(normalizedEmail)) {
    return res.status(400).json({ error: 'Invalid email format' });
  }
  if (!['signup', 'password_reset'].includes(purpose)) {
    return res.status(400).json({ error: 'purpose must be signup or password_reset' });
  }

  try {
    if (purpose === 'signup') {
      const [rows] = await db.query(
        'SELECT userId FROM user WHERE email = ? LIMIT 1',
        [normalizedEmail],
      );
      if (rows.length > 0) {
        return res.status(409).json({ error: 'Email already registered' });
      }
    } else {
      const [rows] = await db.query(
        'SELECT userId FROM user WHERE email = ? LIMIT 1',
        [normalizedEmail],
      );
      if (rows.length === 0) {
        return res.json({
          message:
            'If this email is registered, a verification code was sent.',
        });
      }
    }

    const { plainCode } = await verificationCodes.startChallenge(
      'email',
      normalizedEmail,
      purpose,
    );
    const mailResult = await dispatchEmailVerificationCode({
      to: normalizedEmail,
      code: plainCode,
      purpose,
    });

    const payload = {
      ok: true,
      message: 'Verification code sent to your email',
    };
    if (exposeDevVerificationCode() || mailResult.channel === 'simulated') {
      payload.devVerificationCode = plainCode;
    }
    if (mailResult.sendError) {
      payload.emailDeliveryNote =
        'Email could not be sent via SMTP; use the verification code shown in the app or server log.';
    }
    return res.json(payload);
  } catch (err) {
    if (err.statusCode === 429) {
      return res.status(429).json({
        error: err.message,
        retryAfterSeconds: err.retryAfterSeconds,
      });
    }
    const status = err.statusCode || 500;
    return res.status(status).json({ error: err.message });
  }
});

router.post('/verify-email-code', async (req, res) => {
  const purpose = ((req.body.purpose || 'signup') + '').toLowerCase();
  const normalizedEmail = (req.body.email || '').toString().trim().toLowerCase();
  const rawCode = ((req.body.code || '') + '').trim();

  if (!normalizedEmail || !rawCode) {
    return res.status(400).json({ error: 'email and code are required' });
  }
  if (!['signup', 'password_reset'].includes(purpose)) {
    return res.status(400).json({ error: 'Invalid purpose' });
  }

  try {
    await verificationCodes.completeChallenge(
      'email',
      normalizedEmail,
      purpose,
      rawCode,
    );

    if (purpose === 'signup') {
      pruneEmailVerificationSecrets();
      const proof = randomBytes(32).toString('hex');
      emailVerificationSecrets.set(proof, {
        email: normalizedEmail,
        expiresAt: Date.now() + SIGNUP_PROOF_TTL_MS,
      });
      return res.json({
        verified: true,
        message: 'Email verified successfully',
        emailVerificationToken: proof,
      });
    }

    const [rows] = await db.query(
      'SELECT userId FROM user WHERE email = ? LIMIT 1',
      [normalizedEmail],
    );
    if (rows.length === 0) {
      return res.status(400).json({ error: 'Invalid or expired code' });
    }
    const u = rows[0];
    const resetToken = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 1000 * 60 * 15);
    await db.query(
      'UPDATE user SET resetToken = ?, resetTokenExpires = ? WHERE userId = ?',
      [resetToken, expiresAt, u.userId],
    );
    return res.json({
      verified: true,
      message: 'Email verified successfully',
      resetToken,
    });
  } catch (err) {
    const status = err.statusCode || 500;
    if (status >= 500) console.error('verify-email-code:', err);
    return res.status(status).json({ error: err.message });
  }
});

router.post('/send-phone-otp', async (req, res) => {
  const purpose = ((req.body.purpose || 'signup') + '').toLowerCase();
  const phoneDigits = normalizePhoneDigits((req.body.phone || '').toString());

  if (!/^\d{8,15}$/.test(phoneDigits)) {
    return res.status(400).json({ error: 'Invalid phone number' });
  }
  if (!['signup', 'password_reset'].includes(purpose)) {
    return res.status(400).json({ error: 'purpose must be signup or password_reset' });
  }

  try {
    if (purpose === 'signup') {
      const [rows] = await db.query(
        'SELECT userId FROM user WHERE phone = ? LIMIT 1',
        [phoneDigits],
      );
      if (rows.length > 0) {
        return res
          .status(409)
          .json({ error: 'Phone number already registered' });
      }
    } else {
      const [rows] = await db.query(
        'SELECT userId FROM user WHERE phone = ? LIMIT 1',
        [phoneDigits],
      );
      if (rows.length === 0) {
        return res.json({
          message:
            'If this phone is registered, a verification code was sent.',
        });
      }
    }

    const { plainCode } = await verificationCodes.startChallenge(
      'phone',
      phoneDigits,
      purpose,
    );
    await dispatchSmsVerificationCode({
      toDigits: phoneDigits,
      code: plainCode,
      purpose,
    });

    const payload = {
      ok: true,
      message: 'Verification code sent to your phone',
    };
    if (exposeDevVerificationCode()) {
      payload.devVerificationCode = plainCode;
    }
    return res.json(payload);
  } catch (err) {
    if (err.statusCode === 429) {
      return res.status(429).json({
        error: err.message,
        retryAfterSeconds: err.retryAfterSeconds,
      });
    }
    if (err.statusCode === 503) {
      return res.status(503).json({ error: err.message });
    }
    return res.status(500).json({ error: err.message });
  }
});

router.post('/verify-phone-otp', async (req, res) => {
  const phoneDigits = normalizePhoneDigits((req.body.phone || '').toString());
  const rawCode = ((req.body.code || '') + '').trim();
  const purpose = ((req.body.purpose || 'signup') + '').toLowerCase();

  if (!/^\d{8,15}$/.test(phoneDigits) || !rawCode) {
    return res.status(400).json({ error: 'phone and code are required' });
  }
  if (!['signup', 'password_reset'].includes(purpose)) {
    return res.status(400).json({ error: 'Invalid purpose' });
  }

  try {
    await verificationCodes.completeChallenge(
      'phone',
      phoneDigits,
      purpose,
      rawCode,
    );

    if (purpose === 'signup') {
      prunePhoneVerificationSecrets();
      const proof = randomBytes(32).toString('hex');
      phoneVerificationSecrets.set(proof, {
        phone: phoneDigits,
        expiresAt: Date.now() + SIGNUP_PROOF_TTL_MS,
      });
      return res.json({
        verified: true,
        message: 'Phone verified successfully',
        phoneVerificationToken: proof,
      });
    }

    const [rows] = await db.query(
      'SELECT userId, fullName, email FROM user WHERE phone = ? LIMIT 1',
      [phoneDigits],
    );
    if (rows.length === 0) {
      return res.status(400).json({ error: 'Invalid or expired code' });
    }
    const u = rows[0];
    const resetToken = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 1000 * 60 * 15);
    await db.query(
      'UPDATE user SET resetToken = ?, resetTokenExpires = ? WHERE userId = ?',
      [resetToken, expiresAt, u.userId],
    );
    return res.json({
      verified: true,
      message: 'Phone verified successfully',
      resetToken,
    });
  } catch (err) {
    const status = err.statusCode || 500;
    if (status >= 500) console.error('verify-phone-otp:', err);
    return res.status(status).json({ error: err.message });
  }
});

router.post('/reset-password', async (req, res) => {
  const token = (req.body.token || '').toString().trim();
  const { newPassword } = req.body;
  if (!token) {
    return res.status(400).json({ error: 'token is required' });
  }
  try {
    const result = await performPasswordResetWithToken(token, newPassword);
    return res.json(result);
  } catch (err) {
    const code = err.statusCode || 500;
    if (code >= 500) console.error('RESET PASSWORD ERROR:', err);
    return res.status(code).json({ error: err.message });
  }
});

router.post('/forgot-password', async (req, res) => {
  const { email } = req.body;
  const normalizedEmail = (email || '').toString().trim().toLowerCase();

  try {
    if (!normalizedEmail) {
      return res.status(400).json({ error: 'Email is required' });
    }

    const [rows] = await db.query(
      'SELECT userId, fullName, email FROM user WHERE email = ?',
      [normalizedEmail]
    );

    // لا نكشف إذا الإيميل موجود أو لا
    if (rows.length === 0) {
      return res.json({
        message: 'If this email exists, reset instructions have been sent.'
      });
    }

    const user = rows[0];
    const resetToken = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 1000 * 60 * 15); // 15 min

    await db.query(
      'UPDATE user SET resetToken = ?, resetTokenExpires = ? WHERE userId = ?',
      [resetToken, expiresAt, user.userId]
    );

    const resetLink = `http://localhost:3000/auth/reset-password/${resetToken}`;

    if (isConfiguredMail()) {
      try {
        await sendTransactionalEmail({
          to: user.email,
          subject: 'CareLink Password Reset',
          html: `
        <div style="font-family: Arial, sans-serif; padding: 16px;">
          <h2>Reset Your Password</h2>
          <p>Hello ${user.fullName},</p>
          <p>You requested to reset your CareLink password.</p>
          <p>Click the link below to continue:</p>
          <a href="${resetLink}" target="_blank">${resetLink}</a>
          <p>This link will expire in 15 minutes.</p>
          <p>If you did not request this, please ignore this email.</p>
        </div>
      `,
        });
      } catch (mailErr) {
        console.error('FORGOT PASSWORD MAIL:', mailErr);
      }
    } else {
      console.log(
        '[SIMULATED EMAIL] Password reset link for',
        user.email,
        resetLink,
      );
    }

    res.json({
      message: 'Check your email for reset instructions.',
    });
  } catch (err) {
    console.error('FORGOT PASSWORD ERROR:', err);
    res.status(500).json({ error: err.message });
  }
});

router.post('/reset-password/:token', async (req, res) => {
  const { token } = req.params;
  const { newPassword } = req.body;

  try {
    const result = await performPasswordResetWithToken(token, newPassword);
    res.json(result);
  } catch (err) {
    const code = err.statusCode || 500;
    if (code >= 500) console.error('RESET PASSWORD ERROR:', err);
    res.status(code).json({ error: err.message });
  }
});

router.post('/social/google', async (req, res) => {
  const { idToken, role } = req.body;

  if (!idToken) {
    return res.status(400).json({ error: 'idToken is required' });
  }

  if (!process.env.GOOGLE_CLIENT_ID) {
    return res.status(500).json({
      error: 'GOOGLE_CLIENT_ID is missing in backend environment',
    });
  }

  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    if (!payload?.sub) {
      return res.status(401).json({ error: 'Invalid Google token payload' });
    }

    if (!payload.email) {
      return res
        .status(400)
        .json({ error: 'Google account email is required for login' });
    }

    const user = await getOrCreateSocialUser({
      provider: 'google',
      providerId: payload.sub,
      email: payload.email,
      fullName: payload.name || payload.given_name || 'Google User',
      role,
    });

    return res.json({
      message: 'Login successful',
      user,
    });
  } catch (err) {
    return res.status(401).json({
      error: err.message || 'Google authentication failed',
    });
  }
});

router.post('/social/facebook', async (req, res) => {
  const { accessToken, role } = req.body;

  if (!accessToken) {
    return res.status(400).json({ error: 'accessToken is required' });
  }

  try {
    const response = await fetch(
      `https://graph.facebook.com/me?fields=id,name,email&access_token=${encodeURIComponent(
        accessToken
      )}`
    );

    if (!response.ok) {
      const bodyText = await response.text();
      return res.status(401).json({
        error: `Facebook token validation failed: ${bodyText}`,
      });
    }

    const fbUser = await response.json();
    if (!fbUser?.id) {
      return res.status(401).json({ error: 'Invalid Facebook user data' });
    }

    const user = await getOrCreateSocialUser({
      provider: 'facebook',
      providerId: fbUser.id,
      email: fbUser.email || syntheticEmail('facebook', fbUser.id),
      fullName: fbUser.name || 'Facebook User',
      role,
    });

    return res.json({
      message: 'Login successful',
      user,
    });
  } catch (err) {
    return res.status(401).json({
      error: err.message || 'Facebook authentication failed',
    });
  }
});

router.post('/social/apple', async (req, res) => {
  const { identityToken, role, fullName, email } = req.body;

  if (!identityToken) {
    return res.status(400).json({ error: 'identityToken is required' });
  }

  if (!process.env.APPLE_CLIENT_ID) {
    return res.status(500).json({
      error: 'APPLE_CLIENT_ID is missing in backend environment',
    });
  }

  try {
    const applePayload = await appleSigninAuth.verifyIdToken(identityToken, {
      audience: process.env.APPLE_CLIENT_ID,
      ignoreExpiration: false,
    });

    if (!applePayload?.sub) {
      return res.status(401).json({ error: 'Invalid Apple token payload' });
    }

    const resolvedName =
      (typeof fullName === 'string' && fullName.trim()) ||
      `${fullName?.givenName || ''} ${fullName?.familyName || ''}`.trim() ||
      'Apple User';

    const user = await getOrCreateSocialUser({
      provider: 'apple',
      providerId: applePayload.sub,
      email: email || applePayload.email || syntheticEmail('apple', applePayload.sub),
      fullName: resolvedName,
      role,
    });

    return res.json({
      message: 'Login successful',
      user,
    });
  } catch (err) {
    return res.status(401).json({
      error: err.message || 'Apple authentication failed',
    });
  }
});

module.exports = router;
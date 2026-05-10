const bcrypt = require('bcrypt');
const { randomUUID } = require('crypto');

const columnCache = new Map();

function normalizePhoneDigits(phone) {
  return String(phone || '').replace(/\D/g, '');
}

function normalizeRole(role) {
  const value = (role || '').toString().toLowerCase().trim();
  if (['patient', 'doctor', 'nurse'].includes(value)) return value;
  return '';
}

async function hasColumn(db, tableName, columnName) {
  const key = `${tableName}.${columnName}`;
  if (columnCache.has(key)) return columnCache.get(key);
  try {
    const [rows] = await db.query(
      `SHOW COLUMNS FROM ${tableName} LIKE ?`,
      [columnName],
    );
    const exists = rows.length > 0;
    columnCache.set(key, exists);
    return exists;
  } catch (_) {
    columnCache.set(key, false);
    return false;
  }
}

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const STRONG_PASSWORD =
  /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;

/**
 * Parse and validate POST /api/email-auth/register body (all roles).
 * @returns {{ ok: true, d: object } | { ok: false, status: number, error: string }}
 */
function validateUnifiedSignupBody(body) {
  const fullName = String(body.fullName || '').trim();
  const email = String(body.email || '').trim().toLowerCase();
  const password = String(body.password || '');
  const phone = String(body.phone || '').trim();
  const phoneDigits = normalizePhoneDigits(phone);
  const role = normalizeRole(body.role);

  const specialization = String(body.specialization || '').trim();
  const addressText = String(body.addressText || '').trim();
  const dateOfBirth = body.dateOfBirth != null ? String(body.dateOfBirth).trim() : '';
  const gender = String(body.gender || '').trim().toLowerCase();
  const profileImageUrl = String(body.profileImageUrl || '').trim();
  const experienceYearsRaw = body.experienceYears;
  const licenseNumber = String(body.licenseNumber || '').trim();
  const serviceType = String(body.serviceType || '').trim();
  const chronicDiseases = String(body.chronicDiseases || '').trim();
  const allergies = String(body.allergies || '').trim();
  const currentMedications = String(body.currentMedications || '').trim();
  const gpsLat =
    body.gpsLat == null || body.gpsLat === '' ? null : Number(body.gpsLat);
  const gpsLng =
    body.gpsLng == null || body.gpsLng === '' ? null : Number(body.gpsLng);

  if (!fullName || !email || !password || !role) {
    return {
      ok: false,
      status: 400,
      error: 'fullName, email, password, and role are required',
    };
  }
  if (!EMAIL_REGEX.test(email)) {
    return { ok: false, status: 400, error: 'Invalid email format' };
  }
  if (!/^\d{8,15}$/.test(phoneDigits)) {
    return {
      ok: false,
      status: 400,
      error: 'Phone must be numeric and 8-15 digits',
    };
  }
  if (!STRONG_PASSWORD.test(password)) {
    return {
      ok: false,
      status: 400,
      error:
        'Password must be at least 8 chars and include upper, lower, and number',
    };
  }
  if (fullName.length < 2 || /^\d+$/.test(fullName)) {
    return { ok: false, status: 400, error: 'Invalid full name' };
  }

  if (role === 'patient') {
    if (!addressText) {
      return {
        ok: false,
        status: 400,
        error: 'Patients must provide addressText',
      };
    }
    if (gender) {
      const allowed = ['male', 'female', 'other', 'prefer_not_to_say'];
      if (!allowed.includes(gender)) {
        return {
          ok: false,
          status: 400,
          error:
            'gender must be one of: male, female, other, prefer_not_to_say',
        };
      }
    }
  } else if (role === 'nurse' || role === 'doctor') {
    if (!specialization) {
      return {
        ok: false,
        status: 400,
        error: 'Nurses and doctors must provide specialization',
      };
    }
    const parsedExp = Number.isFinite(Number(experienceYearsRaw))
      ? Number(experienceYearsRaw)
      : null;
    if (parsedExp != null && (parsedExp < 0 || parsedExp > 80)) {
      return {
        ok: false,
        status: 400,
        error: 'experienceYears must be between 0 and 80',
      };
    }
  }

  const parsedExperience = Number.isFinite(Number(experienceYearsRaw))
    ? Number(experienceYearsRaw)
    : null;
  const parsedGpsLat = Number.isFinite(gpsLat) ? gpsLat : null;
  const parsedGpsLng = Number.isFinite(gpsLng) ? gpsLng : null;

  return {
    ok: true,
    d: {
      fullName,
      email,
      password,
      phoneDigits,
      role,
      specialization,
      addressText,
      dateOfBirth: dateOfBirth || null,
      gender: gender || null,
      profileImageUrl: profileImageUrl || null,
      experienceYears: parsedExperience,
      licenseNumber,
      serviceType,
      chronicDiseases,
      allergies,
      currentMedications,
      gpsLat: parsedGpsLat,
      gpsLng: parsedGpsLng,
    },
  };
}

/**
 * @param {import('mysql2/promise').Pool} db
 * @param {import('mysql2/promise').PoolConnection} connection
 */
async function upsertUserRow(db, connection, v, opts) {
  const { userId, isResume, hasVerifiedCol, hasProfileImageUrl } = opts;
  const hashedPassword = await bcrypt.hash(v.password, 10);

  if (isResume) {
    if (hasProfileImageUrl) {
      await connection.query(
        `UPDATE user SET fullName = ?, passwordHash = ?, phone = ?, role = ?, profileImageUrl = COALESCE(?, profileImageUrl)
         WHERE userId = ?`,
        [
          v.fullName,
          hashedPassword,
          v.phoneDigits,
          v.role,
          v.profileImageUrl || null,
          userId,
        ],
      );
    } else {
      await connection.query(
        'UPDATE user SET fullName = ?, passwordHash = ?, phone = ?, role = ? WHERE userId = ?',
        [v.fullName, hashedPassword, v.phoneDigits, v.role, userId],
      );
    }
    if (hasVerifiedCol) {
      await connection.query(
        'UPDATE user SET is_verified = 0 WHERE userId = ?',
        [userId],
      );
    }
    return;
  }

  if (hasVerifiedCol && hasProfileImageUrl) {
    await connection.query(
      `INSERT INTO user (userId, fullName, email, phone, passwordHash, role, is_verified, profileImageUrl)
       VALUES (?, ?, ?, ?, ?, ?, 0, ?)`,
      [
        userId,
        v.fullName,
        v.email,
        v.phoneDigits,
        hashedPassword,
        v.role,
        v.profileImageUrl || null,
      ],
    );
  } else if (hasVerifiedCol) {
    await connection.query(
      `INSERT INTO user (userId, fullName, email, phone, passwordHash, role, is_verified)
       VALUES (?, ?, ?, ?, ?, ?, 0)`,
      [
        userId,
        v.fullName,
        v.email,
        v.phoneDigits,
        hashedPassword,
        v.role,
      ],
    );
  } else if (hasProfileImageUrl) {
    await connection.query(
      `INSERT INTO user (userId, fullName, email, phone, passwordHash, role, profileImageUrl)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        userId,
        v.fullName,
        v.email,
        v.phoneDigits,
        hashedPassword,
        v.role,
        v.profileImageUrl || null,
      ],
    );
  } else {
    await connection.query(
      'INSERT INTO user (userId, fullName, email, phone, passwordHash, role) VALUES (?, ?, ?, ?, ?, ?)',
      [
        userId,
        v.fullName,
        v.email,
        v.phoneDigits,
        hashedPassword,
        v.role,
      ],
    );
  }
}

async function upsertPatientProfile(db, connection, v, userId, isResume) {
  const hasPatientDob = await hasColumn(db, 'patient', 'dateOfBirth');
  const hasPatientGender = await hasColumn(db, 'patient', 'gender');
  const hasChronic = await hasColumn(db, 'patient', 'chronicDiseases');
  const hasAllergies = await hasColumn(db, 'patient', 'allergies');
  const hasMeds = await hasColumn(db, 'patient', 'currentMedications');

  const lat = Number.isFinite(v.gpsLat) ? v.gpsLat : 0;
  const lng = Number.isFinite(v.gpsLng) ? v.gpsLng : 0;

  if (isResume) {
    const [pr] = await connection.query(
      'SELECT userId FROM patient WHERE userId = ? LIMIT 1',
      [userId],
    );
    const cols = ['gpsLat = ?', 'gpsLng = ?', 'addressText = ?'];
    const vals = [lat, lng, v.addressText];
    if (hasPatientDob) {
      cols.push('dateOfBirth = ?');
      vals.push(v.dateOfBirth);
    }
    if (hasPatientGender) {
      cols.push('gender = ?');
      vals.push(v.gender);
    }
    if (hasChronic) {
      cols.push('chronicDiseases = ?');
      vals.push(v.chronicDiseases || null);
    }
    if (hasAllergies) {
      cols.push('allergies = ?');
      vals.push(v.allergies || null);
    }
    if (hasMeds) {
      cols.push('currentMedications = ?');
      vals.push(v.currentMedications || null);
    }
    vals.push(userId);
    if (pr.length) {
      await connection.query(
        `UPDATE patient SET ${cols.join(', ')} WHERE userId = ?`,
        vals,
      );
    } else {
      const iCols = ['userId', 'gpsLat', 'gpsLng', 'addressText'];
      const iVals = [userId, lat, lng, v.addressText];
      if (hasPatientDob) {
        iCols.push('dateOfBirth');
        iVals.push(v.dateOfBirth);
      }
      if (hasPatientGender) {
        iCols.push('gender');
        iVals.push(v.gender);
      }
      if (hasChronic) {
        iCols.push('chronicDiseases');
        iVals.push(v.chronicDiseases || null);
      }
      if (hasAllergies) {
        iCols.push('allergies');
        iVals.push(v.allergies || null);
      }
      if (hasMeds) {
        iCols.push('currentMedications');
        iVals.push(v.currentMedications || null);
      }
      await connection.query(
        `INSERT INTO patient (${iCols.join(', ')}) VALUES (${iCols.map(() => '?').join(', ')})`,
        iVals,
      );
    }
    return;
  }

  const patientColumns = ['userId', 'gpsLat', 'gpsLng', 'addressText'];
  const patientValues = [userId, lat, lng, v.addressText];
  if (hasPatientDob) {
    patientColumns.push('dateOfBirth');
    patientValues.push(v.dateOfBirth);
  }
  if (hasPatientGender) {
    patientColumns.push('gender');
    patientValues.push(v.gender);
  }
  if (hasChronic) {
    patientColumns.push('chronicDiseases');
    patientValues.push(v.chronicDiseases || null);
  }
  if (hasAllergies) {
    patientColumns.push('allergies');
    patientValues.push(v.allergies || null);
  }
  if (hasMeds) {
    patientColumns.push('currentMedications');
    patientValues.push(v.currentMedications || null);
  }
  await connection.query(
    `INSERT INTO patient (${patientColumns.join(', ')})
     VALUES (${patientColumns.map(() => '?').join(', ')})`,
    patientValues,
  );
}

async function deleteProviderRows(connection, userId) {
  await connection.query('DELETE FROM doctor WHERE userId = ?', [userId]);
  await connection.query('DELETE FROM nurse WHERE userId = ?', [userId]);
  await connection.query('DELETE FROM careprovider WHERE userId = ?', [userId]);
}

async function upsertProviderProfile(db, connection, v, userId, role, isResume) {
  const hasExperienceYears = await hasColumn(db, 'careprovider', 'experienceYears');
  const hasLicenseNumber = await hasColumn(db, 'careprovider', 'licenseNumber');
  const hasServiceType = await hasColumn(db, 'careprovider', 'serviceType');
  const hasProviderAddress = await hasColumn(db, 'careprovider', 'providerAddress');

  if (isResume) {
    await deleteProviderRows(connection, userId);
  }

  const providerColumns = [
    'userId',
    'specialization',
    'overallRating',
    'isAvailable',
    'gpsLat',
    'gpsLng',
  ];
  const providerValues = [
    userId,
    v.specialization,
    0.0,
    1,
    Number.isFinite(v.gpsLat) ? v.gpsLat : null,
    Number.isFinite(v.gpsLng) ? v.gpsLng : null,
  ];

  if (hasExperienceYears) {
    providerColumns.push('experienceYears');
    providerValues.push(v.experienceYears ?? 0);
  }
  if (hasLicenseNumber) {
    providerColumns.push('licenseNumber');
    providerValues.push(v.licenseNumber || null);
  }
  if (hasServiceType) {
    providerColumns.push('serviceType');
    providerValues.push(v.serviceType || null);
  }
  if (hasProviderAddress) {
    providerColumns.push('providerAddress');
    providerValues.push(v.addressText || null);
  }

  await connection.query(
    `INSERT INTO careprovider (${providerColumns.join(', ')})
     VALUES (${providerColumns.map(() => '?').join(', ')})`,
    providerValues,
  );

  if (role === 'doctor') {
    await connection.query('INSERT INTO doctor (userId) VALUES (?)', [userId]);
  } else {
    await connection.query('INSERT INTO nurse (userId) VALUES (?)', [userId]);
  }
}

/**
 * Remove stale role rows when switching profile shape (patient ↔ provider) on resume.
 */
async function clearConflictingRoleRows(connection, userId, newRole) {
  const [rows] = await connection.query(
    'SELECT role FROM user WHERE userId = ? LIMIT 1',
    [userId],
  );
  if (rows.length === 0) return;
  const old = String(rows[0].role || '').toLowerCase();
  if (old === newRole) return;
  if (old === 'patient' && (newRole === 'doctor' || newRole === 'nurse')) {
    await connection.query('DELETE FROM patient WHERE userId = ?', [userId]);
  } else if (
    (old === 'doctor' || old === 'nurse') &&
    newRole === 'patient'
  ) {
    await deleteProviderRows(connection, userId);
  }
}

/**
 * @param {import('mysql2/promise').Pool} db
 */
async function savePendingRegistration(db, v, options) {
  const { isResume, userId } = options;
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    const hasVerifiedCol = await hasColumn(db, 'user', 'is_verified');
    const hasProfileImageUrl = await hasColumn(db, 'user', 'profileImageUrl');

    if (isResume) {
      await clearConflictingRoleRows(connection, userId, v.role);
    }

    await upsertUserRow(db, connection, v, {
      userId,
      isResume,
      hasVerifiedCol,
      hasProfileImageUrl,
    });

    if (v.role === 'patient') {
      await upsertPatientProfile(db, connection, v, userId, isResume);
      if (!isResume) {
        await deleteProviderRows(connection, userId);
      }
    } else if (v.role === 'doctor' || v.role === 'nurse') {
      await upsertProviderProfile(
        db,
        connection,
        v,
        userId,
        v.role,
        isResume,
      );
      if (!isResume) {
        await connection.query('DELETE FROM patient WHERE userId = ?', [userId]);
      }
    }

    await connection.commit();
    return userId;
  } catch (e) {
    await connection.rollback();
    throw e;
  } finally {
    connection.release();
  }
}

module.exports = {
  validateUnifiedSignupBody,
  savePendingRegistration,
  normalizeRole,
  normalizePhoneDigits,
  hasColumn,
  randomUUID,
};

const nodemailer = require('nodemailer');

function isConfiguredMail() {
  return !!(
    process.env.MAIL_USER &&
    process.env.MAIL_PASS &&
    String(process.env.MAIL_USER).trim() &&
    String(process.env.MAIL_PASS).trim()
  );
}

function isProduction() {
  return process.env.NODE_ENV === 'production';
}

function mailFrom() {
  const fromName = (process.env.MAIL_FROM_NAME || 'CARELINK').trim();
  const fromEmail = (process.env.MAIL_FROM || process.env.MAIL_USER || '').trim();
  return fromEmail ? `"${fromName}" <${fromEmail}>` : '';
}

/**
 * @returns {import('nodemailer').Transporter | null}
 */
function createMailTransport() {
  if (!isConfiguredMail()) return null;

  const user = process.env.MAIL_USER.trim();
  const pass = process.env.MAIL_PASS.trim();
  const host = (process.env.MAIL_HOST || 'smtp.gmail.com').trim();
  const port = parseInt(process.env.MAIL_PORT || '587', 10);
  const secure = process.env.MAIL_SECURE === 'true' || process.env.MAIL_SECURE === '1' || port === 465;

  return nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass },
    ...((process.env.MAIL_TLS_REJECT_UNAUTHORIZED === '0' && !isProduction())
      ? { tls: { rejectUnauthorized: false } }
      : {}),
  });
}

function enforceRealDelivery() {
  return String(process.env.MAIL_REQUIRE_REAL || '').toLowerCase() === 'true' || process.env.MAIL_REQUIRE_REAL === '1';
}

function getSafeError() {
  const err = new Error('تعذر إرسال رمز التحقق. حاول مرة أخرى لاحقاً.');
  err.statusCode = 502;
  return err;
}

/**
 * Generic HTML email (password reset links, etc.)
 * @param {{ to: string, subject: string, html: string }} opts
 * @returns {Promise<{ channel: 'smtp' | 'simulated' }>}
 */
async function sendTransactionalEmail(opts) {
  const to = (opts.to || '').trim().toLowerCase();
  const subject = (opts.subject || '').trim();
  const html = opts.html || '';
  if (!to || !subject) {
    const err = new Error('sendTransactionalEmail: to and subject required');
    err.statusCode = 400;
    throw err;
  }

  const transport = createMailTransport();
  const from = mailFrom();

  if (!transport) {
    if (isProduction() || enforceRealDelivery()) {
      console.error('[EMAIL] Missing transport configuration');
      throw getSafeError();
    }
    console.log('[EMAIL SIMULATED transactional]', { to, subject });
    return { channel: 'simulated' };
  }

  try {
    await transport.sendMail({ from, to, subject, html });
    return { channel: 'smtp' };
  } catch (e) {
    console.error('[EMAIL] transactional sendMail failed:', e.message);
    if (isProduction() || enforceRealDelivery()) {
      throw getSafeError();
    }
    console.warn('[EMAIL DEV] Transactional not delivered; content was logged above.');
    return { channel: 'simulated' };
  }
}

/**
 * @param {{ to: string, code: string, purpose: 'signup' | 'password_reset' }} params
 * @returns {Promise<{ channel: 'smtp' | 'simulated'; sendError?: string }>}
 */
async function dispatchEmailVerificationCode(params) {
  const to = (params.to || '').trim().toLowerCase();
  const { code, purpose } = params;

  if (!to) {
    const err = new Error('Missing recipient email');
    err.statusCode = 400;
    throw err;
  }

  const subject =
    purpose === 'signup'
      ? 'CareLink — verify your email'
      : 'CareLink — reset your password';
  const html = `
    <div style="font-family: system-ui, sans-serif; padding: 16px; max-width: 480px;">
      <h2 style="margin: 0 0 12px;">Your verification code</h2>
      <p style="font-size: 16px; letter-spacing: 4px; font-weight: 700;">${code}</p>
      <p style="color: #555; font-size: 14px;">This code expires in 5 minutes.</p>
      <p style="color: #555; font-size: 13px;">If you did not request this, you can ignore this message.</p>
    </div>
  `;

  const transport = createMailTransport();
  const from = mailFrom();

  if (!transport) {
    if (isProduction() || enforceRealDelivery()) {
      console.error('[EMAIL] Missing transport configuration for verification code');
      throw getSafeError();
    }
    console.warn('[EMAIL DEV] No MAIL_USER/MAIL_PASS; verification code was not logged.');
    return { channel: 'simulated' };
  }

  try {
    await transport.sendMail({ from, to, subject, html });
    return { channel: 'smtp' };
  } catch (e) {
    console.error('[EMAIL] verification sendMail failed:', e.message);
    if (isProduction() || enforceRealDelivery()) {
      throw getSafeError();
    }
    console.warn('[EMAIL DEV] SMTP failed; verification code was not logged.');
    return { channel: 'simulated', sendError: e.message };
  }
}

/**
 @param {{ toDigits: string, code: string, purpose: 'signup' | 'password_reset' }} params
 @returns {Promise<{ channel: 'twilio' | 'simulated' | 'unconfigured' }>}
 */
async function dispatchSmsVerificationCode(params) {
  const { toDigits, code, purpose } = params;

  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  const fromNum = process.env.TWILIO_FROM_NUMBER;
  if (sid && token && fromNum && isProduction()) {
    console.warn(
      '[SMS] Twilio env set but client not wired — add twilio SDK call here.',
    );
    const err = new Error('SMS provider not fully configured');
    err.statusCode = 503;
    throw err;
  }

  if (sid && token && fromNum && !isProduction()) {
    console.log(
      '[DEV SMS stub] SMS verification requested; recipient and code were not logged.',
    );
    return { channel: 'simulated' };
  }

  if (!isProduction()) {
    console.log(
      '[SIMULATED SMS] Verification code generated but not logged.',
    );
    return { channel: 'simulated' };
  }

  const err = new Error(
    'SMS is not configured. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER.',
  );
  err.statusCode = 503;
  throw err;
}

module.exports = {
  createMailTransport,
  mailFrom,
  sendTransactionalEmail,
  dispatchEmailVerificationCode,
  dispatchSmsVerificationCode,
  isProduction,
  isConfiguredMail,
};

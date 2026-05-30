const nodemailer = require('nodemailer');

/**
 * Mail + SMS dispatch. Supports Gmail, any SMTP (MAIL_HOST), SendGrid-style, etc.
 *
 * Env (email):
 *   MAIL_USER, MAIL_PASS — required for real delivery
 *   MAIL_FROM — optional sender (default: MAIL_USER)
 *   MAIL_HOST, MAIL_PORT, MAIL_SECURE — optional; if set, use generic SMTP instead of Gmail
 *   MAIL_SERVICE — optional Nodemailer well-known service name (default: gmail when no MAIL_HOST)
 */

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
  const from = (process.env.MAIL_FROM || '').trim();
  if (from) return from;
  const user = (process.env.MAIL_USER || '').trim();
  return user ? `"CareLink" <${user}>` : '';
}

/**
 * @returns {import('nodemailer').Transporter | null}
 */
function createMailTransport() {
  if (!isConfiguredMail()) return null;

  const user = process.env.MAIL_USER.trim();
  const pass = process.env.MAIL_PASS.trim();
  const host = (process.env.MAIL_HOST || '').trim();

  if (host) {
    const port = parseInt(process.env.MAIL_PORT || '587', 10);
    const secure =
      process.env.MAIL_SECURE === '1' ||
      process.env.MAIL_SECURE === 'true' ||
      String(process.env.MAIL_SECURE || '').toLowerCase() === 'yes' ||
      port === 465;

    return nodemailer.createTransport({
      host,
      port,
      secure,
      auth: { user, pass },
      ...(process.env.MAIL_TLS_REJECT_UNAUTHORIZED === '0'
        ? { tls: { rejectUnauthorized: false } }
        : {}),
    });
  }

  const service = (process.env.MAIL_SERVICE || 'gmail').trim() || 'gmail';
  return nodemailer.createTransport({
    service,
    auth: { user, pass },
  });
}

/**
 * Generic HTML email (password reset links, etc.)
 * @param {{ to: string, subject: string, html: string }} opts
 * @returns {Promise<{ channel: 'smtp' | 'simulated' }>}
 */
async function sendTransactionalEmail(opts) {
  const to = (opts.to || '').trim();
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
    if (isProduction()) {
      const err = new Error(
        'Email is not configured. Set MAIL_USER and MAIL_PASS (and optionally MAIL_HOST).',
      );
      err.statusCode = 503;
      throw err;
    }
    console.log('[EMAIL SIMULATED transactional]', { to, subject });
    return { channel: 'simulated' };
  }

  try {
    await transport.sendMail({ from, to, subject, html });
    return { channel: 'smtp' };
  } catch (e) {
    console.error('[EMAIL] transactional sendMail failed:', e.message);
    if (isProduction()) {
      const err = new Error(
        `Could not send email (${e.message}). Verify MAIL_* and app passwords / SMTP.`,
      );
      err.statusCode = 502;
      throw err;
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
  const { to, code, purpose } = params;
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

  if (isProduction() && !transport) {
    const err = new Error(
      'Email is not configured. Set MAIL_USER, MAIL_PASS, and optionally MAIL_HOST for your SMTP provider.',
    );
    err.statusCode = 503;
    throw err;
  }

  if (transport) {
    try {
      await transport.sendMail({ from, to, subject, html });
      return { channel: 'smtp' };
    } catch (e) {
      console.error('[EMAIL] verification sendMail failed:', e.message);
      if (isProduction()) {
        const err = new Error(
          `Could not send verification email (${e.message}). For Gmail use an App Password; for other hosts set MAIL_HOST/MAIL_PORT.`,
        );
        err.statusCode = 502;
        throw err;
      }
      console.warn(
        `[EMAIL DEV] SMTP failed — use this code in the app: ${code} (to=${to})`,
      );
      return { channel: 'simulated', sendError: e.message };
    }
  }

  console.warn(
    `[EMAIL DEV] No MAIL_USER/MAIL_PASS — verification code for ${to}: ${code} purpose=${purpose}`,
  );
  return { channel: 'simulated' };
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
      `[DEV SMS stub] would send to ${toDigits} purpose=${purpose} (install twilio SDK to send)`,
    );
    return { channel: 'simulated' };
  }

  if (!isProduction()) {
    console.log(
      `[SIMULATED SMS] to=${toDigits} code=${code} purpose=${purpose} (set TWILIO_* for real SMS in production)`,
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
  sendTransactionalEmail,
  dispatchEmailVerificationCode,
  dispatchSmsVerificationCode,
  isProduction,
  isConfiguredMail,
};

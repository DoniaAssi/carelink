const path = require('path');

require('dotenv').config({ path: path.join(__dirname, '.env') });

const {
  createMailTransport,
  dispatchEmailVerificationCode,
  isConfiguredMail,
  mailFrom,
} = require('./services/verificationDispatch');

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function envFlag(name) {
  const value = process.env[name];
  return {
    exists: typeof value === 'string' && value.trim().length > 0,
    value: name === 'MAIL_PASS' ? undefined : value,
  };
}

function printRuntimeMailConfig() {
  const names = [
    'MAIL_USER',
    'MAIL_PASS',
    'MAIL_FROM',
    'MAIL_HOST',
    'MAIL_PORT',
    'MAIL_SECURE',
    'MAIL_REQUIRE_REAL',
    'MAIL_TLS_REJECT_UNAUTHORIZED',
  ];

  console.log(`ENV_LOADED_FROM ${path.join(__dirname, '.env')}`);
  for (const name of names) {
    const config = envFlag(name);
    if (name === 'MAIL_PASS') {
      console.log(`${name}_EXISTS ${config.exists ? 'yes' : 'no'}`);
    } else {
      console.log(
        `${name}_LOADED ${config.exists ? 'yes' : 'no'}${
          config.exists ? ` (${config.value})` : ''
        }`,
      );
    }
  }
}

function isGmailInvalidLogin(error) {
  const message = `${error && error.message ? error.message : error}`.toLowerCase();
  return (
    error?.responseCode === 535 ||
    message.includes('535') ||
    message.includes('invalid login') ||
    message.includes('username and password not accepted')
  );
}

function isCertificateError(error) {
  const message = `${error && error.message ? error.message : error}`.toLowerCase();
  return (
    message.includes('certificate') ||
    message.includes('self signed') ||
    message.includes('unable to verify') ||
    message.includes('unable_to_verify_leaf_signature')
  );
}

async function main() {
  const recipient = String(process.argv[2] || '').trim().toLowerCase();
  if (!EMAIL_PATTERN.test(recipient)) {
    console.error('Usage: node test-send-code.js recipient@gmail.com');
    process.exitCode = 2;
    return;
  }

  printRuntimeMailConfig();

  if (!isConfiguredMail()) {
    console.error('SMTP_CONFIG_ERROR MAIL_USER or MAIL_PASS is missing');
    process.exitCode = 1;
    return;
  }

  const transport = createMailTransport();
  if (!transport) {
    console.error('SMTP_CONFIG_ERROR mail transport was not created');
    process.exitCode = 1;
    return;
  }

  console.log(`EMAIL_FROM ${mailFrom()}`);
  console.log(`EMAIL_RECIPIENT ${recipient}`);

  try {
    await transport.verify();
    console.log('SMTP_VERIFY_OK');

    const code = String(Math.floor(100000 + Math.random() * 900000));
    const result = await dispatchEmailVerificationCode({
      to: recipient,
      code,
      purpose: 'signup',
    });

    if (result.channel !== 'smtp') {
      throw new Error(
        `Real delivery required, but mailer returned channel=${result.channel}`,
      );
    }

    console.log(`EMAIL_SENT_OK to ${recipient}`);
  } catch (error) {
    if (isGmailInvalidLogin(error)) {
      console.error(
        'SMTP_AUTH_535 Gmail rejected the login. The App Password is wrong or was not loaded.',
      );
    } else if (isCertificateError(error)) {
      console.error(
        'SMTP_CERTIFICATE_ERROR Set MAIL_TLS_REJECT_UNAUTHORIZED=0 for local testing.',
      );
    } else {
      console.error(
        `SMTP_SEND_FAILED ${error && error.message ? error.message : error}`,
      );
    }
    process.exitCode = 1;
  } finally {
    transport.close();
  }
}

main();

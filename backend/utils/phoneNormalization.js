const PALESTINE_MOBILE = /^(?:59|56)\d{7}$/;

function digitsOnly(value) {
  return String(value || '').replace(/\D/g, '');
}

function normalizePalestinePhone(value) {
  let digits = digitsOnly(value);
  if (digits.startsWith('00972')) digits = digits.slice(2);
  if (digits.startsWith('972')) digits = digits.slice(3);
  if (digits.startsWith('0')) digits = digits.slice(1);
  if (!PALESTINE_MOBILE.test(digits)) return null;
  return `+972${digits}`;
}

function normalizeSignupPhone(value) {
  const palestine = normalizePalestinePhone(value);
  if (palestine) return palestine;

  const raw = String(value || '').trim();
  const digits = digitsOnly(raw);
  if (
    digits.startsWith('972') ||
    digits.startsWith('00972') ||
    digits.startsWith('05')
  ) {
    return null;
  }
  if (!raw.startsWith('+') || digits.length < 8 || digits.length > 15) {
    return null;
  }
  return `+${digits}`;
}

module.exports = {
  digitsOnly,
  normalizePalestinePhone,
  normalizeSignupPhone,
};

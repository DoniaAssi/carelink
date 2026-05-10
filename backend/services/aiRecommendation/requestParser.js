'use strict';

function hasAny(blob, needles) {
  return needles.some((n) => blob.includes(n));
}

/**
 * @param {string} searchText
 * @param {string|null} [categoryKey]
 * @returns {import('./types.d.ts').RecommendationRequest}
 */
function fromInputs(searchText, categoryKey) {
  const q = (searchText || '').trim();
  const lower = q.toLowerCase();

  const isUrgent = hasAny(lower, [
    'urgent',
    'emergency',
    'severe',
    "can't breathe",
    'cant breathe',
    'bleeding',
  ]);

  const isComplexCase =
    hasAny(lower, [
      'chronic',
      'multiple',
      'complex',
      'post surgery',
      'post-surgery',
      'cancer',
      'transplant',
    ]) || lower.split(/\s+/).filter(Boolean).length > 18;

  const ck = categoryKey == null ? '' : categoryKey.trim().toLowerCase();
  const keywordFromCategory = CATEGORY_TO_KEYWORD[ck] ?? (ck.length ? ck : '');
  const keywordFromText = inferKeyword(lower);
  const requestedServiceKeyword = keywordFromCategory || keywordFromText;

  return {
    rawQuery: q,
    categoryKey: categoryKey || undefined,
    requestedDateTime: extractDateTime(lower),
    isUrgent,
    isComplexCase: !!(isComplexCase && !isUrgent),
    requestedServiceKeyword,
  };
}

const CATEGORY_TO_KEYWORD = Object.freeze({
  general: 'general',
  lungs: 'lung',
  dentist: 'dental',
  psychiatrist: 'psych',
  covid: 'covid',
  surgeon: 'surgery',
  cardiology: 'cardiology',
});

function inferKeyword(lower) {
  const pairs = [
    ['cardiology', 'cardiology'],
    ['cardio', 'cardiology'],
    ['heart', 'cardiology'],
    ['chest pain', 'cardiology'],
    ['pulmon', 'lung'],
    ['lung', 'lung'],
    ['dent', 'dental'],
    ['psych', 'psych'],
    ['covid', 'covid'],
    ['surgeon', 'surgery'],
    ['surgery', 'surgery'],
    ['general', 'general'],
  ];
  for (const [needle, kw] of pairs) {
    if (lower.includes(needle)) return kw;
  }
  return '';
}

/**
 * Parses weekday + optionally clock (12h / 24h).
 * @param {string} lower
 */
function extractDateTime(lower) {
  const jsDayFromName = {
    sunday: 0,
    monday: 1,
    tuesday: 2,
    wednesday: 3,
    thursday: 4,
    friday: 5,
    saturday: 6,
  };

  /** @type {number|null} */
  let dow = null;
  for (const n of ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']) {
    if (lower.includes(n)) {
      dow = jsDayFromName[n];
      break;
    }
  }

  /** @type {number|null} */
  let hour = null;
  /** @type {number|null} */
  let minute = null;
  const ampm = lower.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b/);
  if (ampm) {
    let h = parseInt(ampm[1], 10);
    minute = parseInt(ampm[2] || '0', 10);
    const isPm = ampm[3] === 'pm';
    if (isPm && h < 12) h += 12;
    if (!isPm && h === 12) h = 0;
    hour = h;
  } else {
    const iso = lower.match(/\b(\d{1,2}):(\d{2})\b/);
    if (iso) {
      hour = parseInt(iso[1], 10);
      minute = parseInt(iso[2], 10);
    } else {
      const pm = lower.match(/\b(\d{1,2})\s*pm\b/);
      if (pm) {
        let h = parseInt(pm[1], 10);
        if (h < 12) h += 12;
        hour = h;
        minute = 0;
      }
    }
  }

  if (dow == null && hour == null && minute == null) return undefined;

  const now = new Date();
  const cursor = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  if (dow !== null) {
    for (let i = 0; i < 14 && cursor.getDay() !== dow; i++) {
      cursor.setDate(cursor.getDate() + 1);
    }
  }

  cursor.setHours(hour != null ? hour : 14, minute != null ? minute : 0, 0, 0);
  return cursor;
}

module.exports = { fromInputs };

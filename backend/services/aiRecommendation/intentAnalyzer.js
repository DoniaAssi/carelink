function analyzeIntent(rawQuery, specialty) {
  const q = (rawQuery || '').toLowerCase().trim();
  const spec = (specialty || '').toLowerCase().trim();

  const matchedKeywords = new Set();
  const detectedSymptoms = new Set();
  const detectedNeeds = new Set();

  function checkMatch(words, callback) {
    for (const w of words) {
      if (q.includes(w)) {
        matchedKeywords.add(w);
        if (callback) callback(w);
      }
    }
  }

  // 1. Detect Emergency
  const emergencyKeywords = [
    'chest pain', 'cannot breathe', 'stroke', 'unconscious',
    'severe bleeding', 'heart attack', 'seizure', 'extreme shortness of breath',
    'emergency', 'heart stopped', 'not breathing'
  ];
  let isEmergency = false;
  checkMatch(emergencyKeywords, (w) => {
    isEmergency = true;
    detectedSymptoms.add(w);
  });

  // 2. Detect Urgency
  const urgentKeywords = ['urgent', 'severe', 'pain', 'immediate', 'bleeding', 'accident'];
  let urgency = 'normal';
  checkMatch(urgentKeywords, (w) => {
    if (!isEmergency) urgency = 'urgent';
    detectedSymptoms.add(w);
  });
  if (isEmergency) urgency = 'emergency';

  // 3. Detect Symptoms & Needs
  const needsMap = {
    'wound': 'Wound Care', 'stitch': 'Wound Care', 'cut': 'Wound Care', 'dressing': 'Wound Care',
    'surgery': 'Post-Surgery Care', 'operation': 'Post-Surgery Care',
    'sugar': 'Diabetes Management', 'diabet': 'Diabetes Management',
    'blood pressure': 'Blood Pressure', 'hypertens': 'Blood Pressure',
    'heart': 'Cardiac Care', 'cardiac': 'Cardiac Care',
    'breathe': 'Respiratory Care', 'lung': 'Respiratory Care', 'cough': 'Respiratory Care', 'asthma': 'Respiratory Care',
    'elder': 'Elderly Care', 'old': 'Elderly Care',
    'child': 'Pediatric Care', 'baby': 'Pediatric Care', 'kid': 'Pediatric Care',
    'tooth': 'Dental Care', 'teeth': 'Dental Care', 'dental': 'Dental Care',
    'depress': 'Mental Health Support', 'anxiety': 'Mental Health Support', 'mental': 'Mental Health Support',
    'nurse': 'Home Nursing', 'nursing': 'Home Nursing', 'injection': 'Home Nursing',
    'fever': 'Fever Management', 'temperature': 'Fever Management'
  };

  for (const [kw, need] of Object.entries(needsMap)) {
    if (q.includes(kw)) {
      matchedKeywords.add(kw);
      detectedNeeds.add(need);
      if (['fever', 'temperature', 'cough', 'pain', 'bleeding'].includes(kw)) {
        detectedSymptoms.add(kw);
      }
    }
  }

  if (detectedNeeds.size === 0 && q.length > 0) {
    detectedNeeds.add('General Consultation');
  }

  // 4. Provider Type Mapping
  let providerType = 'any';
  if (q.includes('doctor') || spec.includes('doctor')) providerType = 'doctor';
  if (q.includes('nurse') || q.includes('nursing') || spec.includes('nurs') || q.includes('wound') || q.includes('injection') || q.includes('dressing')) {
    providerType = 'nurse';
  }
  // If emergency, we always want doctor first unless specifically requesting nurse
  if (isEmergency && !q.includes('nurse')) providerType = 'doctor';

  // 5. Service Category & Keyword
  const categoryMap = {
    'cardiology': ['cardiology', 'heart', 'cardiac', 'chest pain', 'blood pressure'],
    'dental': ['dentist', 'dental', 'tooth', 'teeth'],
    'psychiatry': ['psych', 'mental', 'anxiety', 'depression', 'therapy'],
    'pulmonology': ['lung', 'breathe', 'respir', 'cough', 'asthma'],
    'surgery': ['surgeon', 'surgery', 'operation', 'post-surgery'],
    'general': ['general', 'family', 'gp', 'fever', 'sick'],
    'home nursing': ['home nursing', 'nurse', 'wound', 'elderly', 'post-surgery care', 'dressing', 'injection'],
    'endocrinology': ['diabet', 'sugar', 'thyroid', 'hormone'],
    'orthopedics': ['bone', 'joint', 'fracture', 'ortho', 'back pain'],
    'pediatrics': ['child', 'baby', 'kid', 'pediatric']
  };

  let serviceCategory = spec || 'General';
  let possibleSpecialty = spec;
  
  for (const [cat, words] of Object.entries(categoryMap)) {
    if (words.some(w => q.includes(w))) {
      serviceCategory = cat;
      possibleSpecialty = cat;
      break;
    }
  }
  
  serviceCategory = serviceCategory.split(' ').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');

  return {
    serviceCategory: serviceCategory,
    providerType: providerType,
    urgency: urgency,
    isEmergency: isEmergency,
    detectedNeeds: Array.from(detectedNeeds),
    detectedSymptoms: Array.from(detectedSymptoms),
    matchedKeywords: Array.from(matchedKeywords),
    possibleSpecialty: possibleSpecialty,
    priority: urgency.charAt(0).toUpperCase() + urgency.slice(1)
  };
}

module.exports = { analyzeIntent };

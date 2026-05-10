'use strict';

/**
 * Mirrors CareLink Flutter mock providers (deterministic graduation dataset).
 * @typedef {import('./types.d.ts').Provider} Provider
 */

/** @returns {Provider[]} */
function demoProviders() {
  return [
    mk('prov_cardio_001', 'Dr. Marcus Horizon', 'doctor', 'Cardiology', 4.8, 12, 31.9543, 35.9089, [
      { day: 'wednesday', startTime: '13:00', endTime: '17:00' },
      { day: 'thursday', startTime: '10:00', endTime: '14:00' },
    ]),
    mk('prov_pulmo_002', 'Dr. Lina Khoury', 'doctor', 'Pulmonology', 4.6, 9, 31.951, 35.915, [
      { day: 'wednesday', startTime: '09:00', endTime: '12:00' },
      { day: 'friday', startTime: '15:00', endTime: '18:00' },
    ]),
    mk('prov_dental_003', 'Dr. Omar Naser', 'doctor', 'Dentistry', 4.4, 6, 31.96, 35.9, [
      { day: 'saturday', startTime: '10:00', endTime: '13:00' },
    ]),
    mk('prov_psych_004', 'Dr. Yasmeen Radi', 'doctor', 'Psychiatry', 4.7, 11, 31.948, 35.922, [
      { day: 'monday', startTime: '11:00', endTime: '16:00' },
    ]),
    mk('prov_nurse_005', 'Nurse Dana Salim', 'nurse', 'Home Nursing', 4.9, 10, 31.9565, 35.907, [
      { day: 'wednesday', startTime: '08:00', endTime: '20:00' },
      { day: 'thursday', startTime: '08:00', endTime: '20:00' },
    ]),
    mk('prov_general_006', 'Dr. Kareem Fakhoury', 'doctor', 'General Practice', 4.3, 4, 31.9525, 35.9185, [
      { day: 'tuesday', startTime: '12:00', endTime: '18:00' },
    ]),
    mk('prov_surgeon_007', 'Dr. Hanna Mikhael', 'doctor', 'General Surgery', 4.5, 15, 31.946, 35.925, [
      { day: 'sunday', startTime: '09:00', endTime: '11:00' },
    ]),
    mk('prov_covid_008', 'Dr. Rami Saad', 'doctor', 'Internal Medicine', 4.2, 7, 31.9588, 35.8995, [
      { day: 'wednesday', startTime: '14:00', endTime: '18:00' },
    ]),
  ].map(wireProvider);
}

/**
 * Internal shape → Provider (specialization + rating keys align with engine).
 */
function mk(id, fullName, role, specialization, rating, expYears, lat, lng, slots) {
  return {
    id,
    fullName,
    role,
    specialization,
    rating,
    experienceYears: expYears,
    locationLatitude: lat,
    locationLongitude: lng,
    availableSlots: slots,
    serviceType: role === 'nurse' ? 'Home nursing,Wound care' : 'Telehealth',
  };
}

function wireProvider(raw) {
  return {
    id: raw.id,
    fullName: raw.fullName,
    role: raw.role,
    specialization: raw.specialization,
    rating: raw.rating,
    experienceYears: raw.experienceYears,
    locationLatitude: raw.locationLatitude,
    locationLongitude: raw.locationLongitude,
    availableSlots: raw.availableSlots,
    serviceType: raw.serviceType,
  };
}

/** @returns {import('./types.d.ts').PatientProfile} */
function demoNewPatient() {
  return {
    id: 'patient_new_demo',
    fullName: 'Demo Patient',
    age: 28,
    gender: 'female',
    locationLatitude: 31.9539,
    locationLongitude: 35.9106,
    chronicDiseases: [],
    allergies: [],
    medications: [],
    previousSurgeries: [],
    careSummaryText: '',
    previousProviderRatings: {},
    successfulVisitProviderIds: [],
    visitReportTexts: [],
    followUpHints: [],
    hasHistoryForWeighting: false,
  };
}

/** @returns {import('./types.d.ts').PatientProfile} */
function demoReturningHeartPatient() {
  return {
    id: 'patient_returning_demo',
    fullName: 'Sara Al-Masri',
    age: 54,
    gender: 'female',
    locationLatitude: 31.9539,
    locationLongitude: 35.9106,
    chronicDiseases: ['Ischemic heart disease'],
    allergies: ['Penicillin'],
    medications: ['Aspirin', 'Metoprolol'],
    previousSurgeries: ['Stent placement (2019)'],
    careSummaryText:
      'chronic heart disease congestive follow-up chest pain prior visit five star cardiologist cardiology consultation',
    previousProviderRatings: { prov_cardio_001: 5 },
    successfulVisitProviderIds: ['prov_cardio_001'],
    visitReportTexts: [
      'Patient reports chest tightness — follow-up with cardiology advised.',
    ],
    followUpHints: ['cardiology', 'follow-up'],
    hasHistoryForWeighting: true,
  };
}

module.exports = {
  demoProviders,
  demoNewPatient,
  demoReturningHeartPatient,
};

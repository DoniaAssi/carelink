'use strict';

const { recommendProviders } = require('./engine');
const { demoProviders } = require('./mockData');
const { fromInputs } = require('./requestParser');
const { MedicalRecordMemoryStore } = require('./medicalRecordMemoryStore');

/** Singleton in-memory persistence for graduation demo (restart clears state). */
const graduationDemoStore = new MedicalRecordMemoryStore();

/**
 * @param {import('./types.d.ts').PatientProfile} base
 */
function hydratePatientWithStore(base) {
  const fromUploadsAndReports = graduationDemoStore.getAiContextBlob(base.id);
  const care = [base.careSummaryText || '', fromUploadsAndReports].filter(Boolean).join(' ').trim();
  const locals = graduationDemoStore.getRecords(base.id);
  const hasHistory = !!base.hasHistoryForWeighting || locals.length > 0;

  return {
    ...base,
    careSummaryText: care,
    hasHistoryForWeighting: hasHistory,
  };
}

/**
 * @param {{ patient: import('./types.d.ts').PatientProfile, searchText?: string, categoryKey?: string|null, top?: number }} opts
 */
function getRecommendedProviders(opts) {
  const { patient, searchText = '', categoryKey = null, top = 16 } = opts;
  const request = fromInputs(searchText, categoryKey == null ? null : String(categoryKey));
  const hydrated = hydratePatientWithStore(patient);
  return recommendProviders(hydrated, request, demoProviders(), top);
}

/**
 * @param {{
 *   patientId: string,
 *   providerId: string,
 *   date: string,
 *   time: string,
 *   reason: string,
 *   price?: number,
 *   locationType?: 'home'|'clinic'|'hospital'
 * }} input
 */
function createAppointment(input) {
  return {
    id: `apt_${Date.now()}`,
    patientId: input.patientId,
    providerId: input.providerId,
    date: input.date,
    time: input.time,
    reason: input.reason,
    status: 'pending',
    paymentStatus: 'unpaid',
    price: input.price ?? 65,
    locationType: input.locationType ?? 'home',
    createdAt: new Date().toISOString(),
  };
}

function confirmPayment(apt) {
  return {
    ...apt,
    status: 'confirmed',
    paymentStatus: 'paid',
    paidAt: new Date().toISOString(),
  };
}

function attachVisitReportAfterBooking(patientId, appointmentId, payload) {
  return graduationDemoStore.add(patientId, {
    patientId,
    appointmentId,
    uploadedBy: 'doctor',
    type: 'visit_report',
    title: payload.title || 'Visit report',
    description: payload.description || '',
    diagnosis: payload.diagnosis || '',
    notes: payload.notes || '',
    prescription: payload.prescription || '',
    attachments: payload.attachments || [],
    usedByAi: true,
    privateLabel: true,
    uploadedAfterVisit: true,
  });
}

function patientUploadedOldReport(patientId, payload) {
  return graduationDemoStore.add(patientId, {
    patientId,
    uploadedBy: 'patient',
    type: 'old_report',
    title: payload.title || 'Patient uploaded record',
    description: payload.description || '',
    attachments: payload.attachments || [],
    usedByAi: true,
    privateLabel: true,
    uploadedAfterVisit: false,
  });
}

module.exports = {
  getRecommendedProviders,
  createAppointment,
  confirmPayment,
  attachVisitReportAfterBooking,
  patientUploadedOldReport,
  graduationDemoStore,
  MedicalRecordMemoryStore,
};

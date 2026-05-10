'use strict';

const crypto = require('crypto');

/**
 * @typedef {import('./types.d.ts').MedicalRecordEntry} MedicalRecordEntry
 */

class MedicalRecordMemoryStore {
  constructor() {
    /** @type {Map<string, MedicalRecordEntry[]>} */
    this._byPatient = new Map();
    /** @type {Map<string, string>} */
    this._boost = new Map();
  }

  /** @param {string} patientId */
  getRecords(patientId) {
    return [...(this._byPatient.get(patientId) || [])];
  }

  /** @param {string} patientId */
  getProfileBoost(patientId) {
    return this._boost.get(patientId) || '';
  }

  /**
   * Concatenate visit texts for scorer + optional boost snippet.
   * @param {string} patientId
   */
  getAiContextBlob(patientId) {
    const rows = this.getRecords(patientId);
    const text = rows
      .map((r) => `${r.title} ${r.diagnosis || ''} ${r.notes || ''} ${r.description || ''}`.trim())
      .join(' ')
      .toLowerCase();
    return `${text} ${(this._boost.get(patientId) || '').toLowerCase()}`.trim();
  }

  /**
   * Extra free-text fused into PatientProfile.careSummaryText for demos.
   * @param {string} patientId
   * @param {string} snippet
   */
  appendProfileBoost(patientId, snippet) {
    const cur = this._boost.get(patientId) || '';
    const next = `${cur} ${snippet}`.trim();
    this._boost.set(patientId, next);
  }

  /**
   * @param {string} patientId
   * @param {Partial<MedicalRecordEntry> & Pick<MedicalRecordEntry, 'patientId'|'uploadedBy'|'type'|'title'>} raw
   */
  add(patientId, raw) {
    /** @type {MedicalRecordEntry} */
    const entry = {
      id: crypto.randomUUID(),
      patientId,
      appointmentId: raw.appointmentId,
      uploadedBy: raw.uploadedBy,
      type: raw.type,
      title: raw.title,
      description: raw.description ?? '',
      diagnosis: raw.diagnosis ?? '',
      notes: raw.notes ?? '',
      prescription: raw.prescription ?? '',
      attachments: raw.attachments ?? [],
      createdAt: new Date().toISOString(),
      usedByAi: raw.usedByAi !== false,
      privateLabel: raw.privateLabel !== false,
      uploadedAfterVisit: !!raw.uploadedAfterVisit,
    };
    const list = this._byPatient.get(patientId) || [];
    list.push(entry);
    this._byPatient.set(patientId, list);
    const blob = `${entry.title} ${entry.diagnosis} ${entry.notes}`.trim();
    if (blob.length) this.appendProfileBoost(patientId, blob);
    return entry;
  }
}

module.exports = { MedicalRecordMemoryStore };

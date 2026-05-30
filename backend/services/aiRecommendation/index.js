'use strict';

/** Barrel export for `require('.../aiRecommendation')` in Node or future TS bundling. */

const engine = require('./engine');
const mockData = require('./mockData');
const requestParser = require('./requestParser');
const flow = require('./graduationFlowService');
const { MedicalRecordMemoryStore } = require('./medicalRecordMemoryStore');

module.exports = {
  ...engine,
  ...mockData,
  ...requestParser,
  ...flow,
  MedicalRecordMemoryStore,
};

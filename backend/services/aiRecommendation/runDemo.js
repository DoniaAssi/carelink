#!/usr/bin/env node
'use strict';

/**
 * Local graduation demo: recommend → book → pay → upload report → re-rank.
 * Run: node backend/services/aiRecommendation/runDemo.js
 *   or: npm run ai:demo (from backend/)
 */

const {
  getRecommendedProviders,
  createAppointment,
  confirmPayment,
  attachVisitReportAfterBooking,
  patientUploadedOldReport,
} = require('./graduationFlowService');
const { demoReturningHeartPatient, demoNewPatient } = require('./mockData');

function printHeader(title) {
  console.log('\n' + '='.repeat(60));
  console.log(title);
  console.log('='.repeat(60));
}

function runStep(name, fn) {
  printHeader(name);
  const out = fn();
  console.log(typeof out === 'string' ? out : JSON.stringify(out, null, 2));
  return out;
}

function main() {
  console.log('CareLink — JS/TS-style local AI recommendation + flow demo\n');

  const returning = demoReturningHeartPatient();
  const fresh = demoNewPatient();

  runStep('1) Pre-booking: patient uploads an old report (feeds AI blob)', () => {
    patientUploadedOldReport(returning.id, {
      title: 'Prior ECG summary',
      description: 'ST changes noted — cardiology follow-up recommended',
    });
    return { ok: true, patientId: returning.id };
  });

  runStep('2) AI ranking — returning heart patient, query "chest pain Wednesday 2pm"', () => {
    const top = getRecommendedProviders({
      patient: returning,
      searchText: 'chest pain follow-up Wednesday 2pm',
      top: 5,
    });
    return top.map((r) => ({
      match: r.matchPercentage + '%',
      name: r.provider.fullName,
      specialization: r.provider.specialization,
      finalScore: Number(r.finalScore.toFixed(4)),
      topReason: r.recommendationReasons[0],
      breakdown: r.scoreBreakdown,
    }));
  });

  runStep('3) Booking + payment confirmation (simulated)', () => {
    const ranked = getRecommendedProviders({
      patient: returning,
      searchText: 'cardiology',
      top: 1,
    });
    const best = ranked[0];
    if (!best) return { error: 'No provider' };
    const apt = createAppointment({
      patientId: returning.id,
      providerId: best.providerId,
      date: '2026-05-10',
      time: '14:00',
      reason: 'Chest pain follow-up',
      price: 85,
    });
    const paid = confirmPayment(apt);
    return { appointment: paid };
  });

  const aptId = 'apt_demo_ref';
  runStep('4) After visit: provider uploads report → history improves next ranking', () => {
    const report = attachVisitReportAfterBooking(returning.id, aptId, {
      title: 'Visit summary',
      diagnosis: 'Stable angina — continue cardiology care',
      notes: 'Patient stable. Reinforce lifestyle measures.',
      prescription: 'Continue beta-blocker; follow-up 4 weeks',
    });
    return { savedRecordId: report.id };
  });

  runStep('5) Re-rank same query for NEW patient (cold start) vs RETURNING (hybrid)', () => {
    const q = 'I need a cardiologist';
    const cold = getRecommendedProviders({ patient: fresh, searchText: q, top: 3 });
    const warm = getRecommendedProviders({ patient: returning, searchText: q, top: 3 });
    return {
      coldStartTop: cold.map((r) => ({ name: r.provider.fullName, pct: r.matchPercentage })),
      withHistoryTop: warm.map((r) => ({ name: r.provider.fullName, pct: r.matchPercentage })),
    };
  });

  printHeader('Done — use graduationFlowService from Express or import types in TypeScript');
}

main();

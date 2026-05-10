'use strict';

const express = require('express');
const {
  getRecommendedProviders,
  createAppointment,
  confirmPayment,
  attachVisitReportAfterBooking,
  patientUploadedOldReport,
  graduationDemoStore,
} = require('../services/aiRecommendation/graduationFlowService');
const { demoNewPatient, demoReturningHeartPatient } = require('../services/aiRecommendation/mockData');

const router = express.Router();

/** POST body: { variant?: "new"|"returning", searchText?: string, categoryKey?: string|null, top?: number } */
router.post('/ai/recommend', (req, res) => {
  try {
    const variant = req.body?.variant === 'new' ? 'new' : 'returning';
    const patient = variant === 'new' ? demoNewPatient() : demoReturningHeartPatient();
    const top = typeof req.body?.top === 'number' ? req.body.top : 12;
    const results = getRecommendedProviders({
      patient,
      searchText: req.body?.searchText ?? '',
      categoryKey: req.body?.categoryKey ?? null,
      top,
    });
    res.json({
      success: true,
      variant,
      count: results.length,
      results: results.map((r) => ({
        providerId: r.providerId,
        fullName: r.provider.fullName,
        specialization: r.provider.specialization,
        matchPercentage: r.matchPercentage,
        finalScore: r.finalScore,
        scoreBreakdown: r.scoreBreakdown,
        weights: r.weights,
        recommendationReasons: r.recommendationReasons,
      })),
    });
  } catch (e) {
    res.status(500).json({ success: false, error: String(e?.message || e) });
  }
});

/** POST body: { patientVariant, providerId, date, time, reason, price?, locationType? } */
router.post('/ai/book', (req, res) => {
  try {
    const pid = req.body?.providerId;
    const dt = req.body?.date;
    const tm = req.body?.time;
    if (!pid || !dt || !tm) {
      return res.status(400).json({
        success: false,
        error: 'providerId, date, and time are required',
      });
    }
    const patient =
      req.body?.patientVariant === 'new' ? demoNewPatient() : demoReturningHeartPatient();
    const apt = createAppointment({
      patientId: patient.id,
      providerId: String(pid),
      date: String(dt),
      time: String(tm),
      reason: req.body?.reason ?? '',
      price: req.body?.price,
      locationType: req.body?.locationType,
    });
    res.json({ success: true, appointment: apt });
  } catch (e) {
    res.status(400).json({ success: false, error: String(e?.message || e) });
  }
});

router.post('/ai/confirm-payment', (req, res) => {
  try {
    const apt = confirmPayment(req.body?.appointment);
    res.json({ success: true, appointment: apt });
  } catch (e) {
    res.status(400).json({ success: false, error: String(e?.message || e) });
  }
});

router.post('/ai/medical-record/upload', (req, res) => {
  try {
    const patient =
      req.body?.patientVariant === 'new' ? demoNewPatient() : demoReturningHeartPatient();
    const entry = patientUploadedOldReport(patient.id, req.body ?? {});
    res.json({ success: true, entry });
  } catch (e) {
    res.status(500).json({ success: false, error: String(e?.message || e) });
  }
});

router.post('/ai/visit-report', (req, res) => {
  try {
    const returning = demoReturningHeartPatient();
    const pid = req.body?.patientId || returning.id;
    const entry = attachVisitReportAfterBooking(
      pid,
      req.body?.appointmentId ?? 'demo',
      req.body ?? {},
    );
    res.json({ success: true, entry });
  } catch (e) {
    res.status(500).json({ success: false, error: String(e?.message || e) });
  }
});

router.get('/ai/store/:patientId', (req, res) => {
  res.json({
    success: true,
    records: graduationDemoStore.getRecords(req.params.patientId),
    profileBoostSnippet: graduationDemoStore.getProfileBoost(req.params.patientId),
  });
});

module.exports = router;

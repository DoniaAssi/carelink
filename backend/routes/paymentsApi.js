'use strict';

/**
 * Secure booking payments — **`payment`** table + DEMO confirm (no real PSP).
 */

const express = require('express');
const {
  createApiPayment,
  confirmDemoPayment,
  getAppointmentPayment,
  listPatientPayments,
} = require('../services/bookingPaymentService');

const router = express.Router();

router.post('/create', async (req, res) => {
  try {
    const out = await createApiPayment(req.body || {});
    res.status(201).json(out);
  } catch (err) {
    res.status(err.status || 500).json({ success: false, error: err.message });
  }
});

router.post('/confirm', async (req, res) => {
  try {
    const out = await confirmDemoPayment(req.body || {});
    res.status(200).json(out);
  } catch (err) {
    res.status(err.status || 500).json({ success: false, error: err.message });
  }
});

router.get('/appointment/:appointmentId', async (req, res) => {
  const patientUserId = (req.query.patientUserId || '').toString().trim();
  if (!patientUserId) {
    return res
      .status(400)
      .json({ error: 'patientUserId query parameter is required' });
  }
  try {
    const out = await getAppointmentPayment(
      req.params.appointmentId,
      patientUserId,
    );
    res.json(out);
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

router.get('/patient/:patientId', async (req, res) => {
  try {
    const rows = await listPatientPayments(req.params.patientId);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

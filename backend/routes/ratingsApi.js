'use strict';

const express = require('express');
const {
  submitPatientVisitRating,
  listRatingsForProvider,
  listRatingsForPatient,
} = require('../services/visitRatingService');

const router = express.Router();

/**
 * POST /api/ratings
 * Body: { patientUserId, appointmentId | bookingId, stars, comment? }
 * (provider is derived from servicerequest — do not trust providerId in body for auth.)
 */
router.post('/', async (req, res) => {
  try {
    const { patientUserId, stars, comment, appointmentId, bookingId } =
      req.body || {};
    const aid = appointmentId || bookingId;
    const result = await submitPatientVisitRating({
      appointmentId: aid,
      patientUserId,
      stars,
      comment,
    });
    res.status(201).json(result);
  } catch (err) {
    const code = err.status || 500;
    res.status(code).json({ error: err.message });
  }
});

router.get('/provider/:providerId', async (req, res) => {
  try {
    const { providerId } = req.params;
    const lim = req.query.limit ? Number(req.query.limit) : 100;
    const data = await listRatingsForProvider(providerId, lim);
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/patient/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;
    const lim = req.query.limit ? Number(req.query.limit) : 200;
    const data = await listRatingsForPatient(patientId, lim);
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

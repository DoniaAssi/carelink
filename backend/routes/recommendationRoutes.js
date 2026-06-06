'use strict';

const express = require('express');
const { getRecommendationsForPatient } = require('../services/recommendationService');

const router = express.Router();

function actor(req) {
  return {
    userId: (req.headers['x-user-id'] || req.headers['x-userid'] || '').toString().trim(),
    role: (req.headers['x-user-role'] || req.headers['x-userrole'] || '').toString().trim().toLowerCase(),
  };
}

/**
 * GET /api/recommendations/patient/:patientId
 *
 * Returns ranked care providers for the given patient, incorporating
 * their uploaded medical records (analysisTags, aiSummary, ocrText).
 *
 * Query params:
 *   search  - optional free-text filter / service keyword
 *   top     - max results (default 12)
 */
router.get('/patient/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;
    const { userId, role } = actor(req);

    if (role !== 'admin' && userId !== patientId) {
      return res.status(403).json({ error: 'You can only view your own recommendations.' });
    }

    const top = Math.min(50, Math.max(1, parseInt(req.query.top, 10) || 12));
    const searchText = (req.query.search || '').toString().trim();

    const result = await getRecommendationsForPatient(patientId, { searchText, top });

    if (result.error) {
      return res.status(404).json({ error: result.error });
    }

    res.json({ success: true, ...result });
  } catch (err) {
    console.error('[Recommendations] Error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

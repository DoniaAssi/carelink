const express = require('express');
const controller = require('../controllers/medicalRecordController');

const router = express.Router();

router.get('/patient/:patientId', controller.listForPatient);
router.get('/visit-report/:recordId', controller.getVisitReport);
router.post('/visit-report', controller.createVisitReport);

module.exports = router;

const express = require('express');
const {
  createPayment,
  getByAppointment,
} = require('../controllers/paymentsController');

const router = express.Router();

router.post('/create', createPayment);
router.get('/:appointmentId', getByAppointment);

module.exports = router;

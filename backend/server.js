const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const providerRoutes = require('./routes/providers');
const patientRoutes = require('./routes/patient');
const medicalRecordRoutes = require('./routes/medicalRecordRoutes');
const paymentRoutes = require('./routes/payments');
const nurseRoutes = require('./routes/nurse');

const app = express();

app.use(cors());
// Default 100kb is too small for data:image base64 profile photos.
app.use(express.json({ limit: '12mb' }));
app.use(express.urlencoded({ extended: true, limit: '12mb' }));

app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'CareLink backend is running',
  });
});

app.use('/auth', authRoutes);
app.use('/providers', providerRoutes);
app.use('/patient', patientRoutes);
app.use('/medical-records', medicalRecordRoutes);
app.use('/payments', paymentRoutes);
app.use('/nurse', nurseRoutes);

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
const medicalRecordService = require('../services/medicalRecordService');

function actor(req) {
  const userId = (
    req.headers['x-user-id'] ||
    req.headers['x-userid'] ||
    ''
  )
    .toString()
    .trim();
  const role = (
    req.headers['x-user-role'] ||
    req.headers['x-userrole'] ||
    ''
  )
    .toString()
    .trim()
    .toLowerCase();
  return { userId, role };
}

function forbid(res, message = 'Forbidden') {
  return res.status(403).json({ error: message });
}

function badRequest(res, message, errors) {
  return res.status(400).json({
    error: message,
    ...(errors ? { errors } : {}),
  });
}

async function assertVisitReportsTable(res) {
  const ok = await medicalRecordService.tableExists('visit_reports');
  if (!ok) {
    res.status(503).json({
      error:
        'visit_reports table missing. Run backend/sql migrations for visit_reports.',
    });
    return false;
  }
  return true;
}

function canPatientViewPatient(actorUserId, actorRole, patientId) {
  if (actorRole === 'admin') return true;
  return actorUserId && actorUserId === patientId;
}

/** GET /medical-records/patient/:patientId — official visit reports only */
exports.listForPatient = async (req, res) => {
  try {
    if (!(await assertVisitReportsTable(res))) return;
    const { patientId } = req.params;
    const { userId, role } = actor(req);
    if (!canPatientViewPatient(userId, role, patientId)) {
      return forbid(res, 'You can only view your own medical records.');
    }
    const rows = await medicalRecordService.listVisitReportsForPatient(
      patientId
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/** GET /medical-records/visit-report/:recordId */
exports.getVisitReport = async (req, res) => {
  try {
    if (!(await assertVisitReportsTable(res))) return;
    const { recordId } = req.params;
    const { userId, role } = actor(req);
    const row = await medicalRecordService.getVisitReportById(recordId);
    if (!row) return res.status(404).json({ error: 'Record not found' });
    if (!canPatientViewPatient(userId, role, row.patient_id)) {
      return forbid(res);
    }
    res.json(row);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/** POST /medical-records/visit-report — doctor / nurse / admin only */
exports.createVisitReport = async (req, res) => {
  try {
    if (!(await assertVisitReportsTable(res))) return;

    const { userId, role } = actor(req);
    if (!['doctor', 'nurse', 'admin'].includes(role)) {
      return forbid(res, 'Only care providers can file visit reports.');
    }

    const patientId = (req.body.patient_id ?? req.body.patientId ?? '')
      .toString()
      .trim();
    const providerId = (req.body.provider_id ?? req.body.providerId ?? '')
      .toString()
      .trim();
    const appointmentId = (
      req.body.appointment_id ??
      req.body.appointmentId ??
      ''
    )
      .toString()
      .trim();

    const errors = [];
    if (!patientId) errors.push('patient_id is required');
    if (!providerId) errors.push('provider_id is required');

    const diagnosis = (req.body.diagnosis ?? '').toString().trim();
    const treatment = (req.body.treatment_plan ?? req.body.treatmentPlan ?? '')
      .toString()
      .trim();
    if (!diagnosis && !treatment) {
      errors.push('diagnosis or treatment_plan must not be empty');
    }

    if (role !== 'admin' && userId !== providerId) {
      return forbid(res, 'provider_id must match signed-in provider.');
    }

    let follow_up_date = req.body.follow_up_date ?? req.body.followUpDate ?? null;
    if (follow_up_date) {
      follow_up_date = medicalRecordService.toDateOnly(follow_up_date);
      if (!follow_up_date) errors.push('follow_up_date must be valid when provided');
    }

    let visit_date = req.body.visit_date ?? req.body.visitDate ?? null;
    if (visit_date) {
      visit_date = medicalRecordService.toDateOnly(visit_date);
      if (!visit_date) errors.push('visit_date must be valid when provided');
    }

    if (errors.length) return badRequest(res, 'Validation failed', errors);

    const okLink = await medicalRecordService.appointmentLinksPatientProvider(
      appointmentId || null,
      patientId,
      providerId
    );
    if (!okLink) {
      return badRequest(
        res,
        'appointment_id does not match this patient and provider'
      );
    }

    const row = await medicalRecordService.insertVisitReport({
      patient_id: patientId,
      provider_id: providerId,
      appointment_id: appointmentId || null,
      vital_signs: req.body.vital_signs ?? req.body.vitalSigns ?? {},
      diagnosis,
      treatment_plan: treatment,
      recommendations: (req.body.recommendations ?? '').toString(),
      follow_up_required:
        req.body.follow_up_required === true ||
        req.body.follow_up_required === 1 ||
        req.body.followUpRequired === true,
      follow_up_date,
      visit_date: visit_date || undefined,
      medications_prescribed:
        req.body.medications_prescribed ?? req.body.medicationsPrescribed,
      allergies_noted: req.body.allergies_noted ?? req.body.allergiesNoted,
    });

    res.status(201).json(row);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

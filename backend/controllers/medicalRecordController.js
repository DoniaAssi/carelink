const medicalRecordService = require('../services/medicalRecordService');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const uploadsDir = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(uploadsDir, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, uploadsDir),
    filename: (req, file, cb) => {
      const safeName = path
        .basename(file.originalname)
        .replace(/[^a-zA-Z0-9._-]+/g, '-');
      cb(null, `${Date.now()}-${Math.random().toString(36).substring(2, 10)}-${safeName}`);
    },
  }),
  limits: { fileSize: 25 * 1024 * 1024 },
});

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

/** GET /medical-records/patient/:patientId — combined provider visit reports and patient uploads */
exports.listForPatient = async (req, res) => {
  try {
    const { patientId } = req.params;
    const { userId, role } = actor(req);
    if (!canPatientViewPatient(userId, role, patientId)) {
      return forbid(res, 'You can only view your own medical records.');
    }

    const visitReports = await medicalRecordService.listVisitReportsForPatient(
      patientId
    );
    const patientUploads = await medicalRecordService.listPatientMedicalRecordsForPatient(
      patientId
    );

    const combined = [...visitReports, ...patientUploads];
    combined.sort((a, b) => {
      const aTime = new Date(a.created_at || a.visit_date || '').getTime();
      const bTime = new Date(b.created_at || b.visit_date || '').getTime();
      return bTime - aTime;
    });

    res.json(combined);
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

function normalizeBoolean(value) {
  if (value === true || value === 1) return true;
  if (typeof value === 'string') {
    return ['true', '1', 'yes', 'on'].includes(value.toString().trim().toLowerCase());
  }
  return false;
}

function normalizeCategory(value) {
  return value?.toString().trim() || null;
}

function parseTags(value) {
  if (Array.isArray(value)) {
    return value
      .map((t) => (t != null ? t.toString().trim() : ''))
      .filter((t) => t !== '');
  }
  if (typeof value === 'string') {
    return value
      .split(/[,;\n]+/)
      .map((t) => t.trim())
      .filter((t) => t !== '');
  }
  return [];
}

exports.uploadPatientRecord = [upload.single('file'), async (req, res) => {
  try {
    if (!(await medicalRecordService.tableExists('patient_medical_records'))) {
      res.status(503).json({
        error:
          'patient_medical_records table missing. Run backend/sql migrations for patient_medical_records.',
      });
      return;
    }

    const { userId, role } = actor(req);
    const patientId = (req.body.patient_id ?? req.body.patientId ?? '').toString().trim();
    if (!patientId) {
      return badRequest(res, 'patient_id is required');
    }
    if (!['patient', 'admin'].includes(role) || (role === 'patient' && userId !== patientId)) {
      return forbid(res, 'You can only upload records for yourself.');
    }

    if (!req.file) {
      return badRequest(res, 'A file upload is required.');
    }

    const title = (req.body.title ?? '').toString().trim();
    if (!title) {
      return badRequest(res, 'title is required');
    }

    const recordType = (req.body.record_type ?? req.body.recordType ?? 'attachment').toString().trim();
    const category = normalizeCategory(req.body.category ?? req.body.category_en ?? req.body.categoryEn);
    const description = (req.body.description ?? req.body.notes ?? '').toString().trim();
    const usedForAiMatching = normalizeBoolean(req.body.used_for_ai_matching ?? req.body.usedForAiMatching ?? true);
    const aiReady = normalizeBoolean(req.body.ai_ready ?? req.body.aiReady ?? false);
    const extractedTextStatus = (req.body.extracted_text_status ?? req.body.extractedTextStatus ?? 'pending').toString().trim();
    const medicalSummary = (req.body.medical_summary ?? req.body.medicalSummary ?? '').toString().trim();
    const detectedCategory = (req.body.detected_category ?? req.body.detectedCategory ?? '').toString().trim();
    const tags = parseTags(req.body.tags ?? req.body.tagList ?? '');

    const fileExtension = path.extname(req.file.originalname).toLowerCase().replace('.', '');
    const baseUrl = process.env.BACKEND_URL || (req.protocol + '://' + req.get('host'));
    const fileUrl = baseUrl + '/uploads/' + req.file.filename;

    const row = await medicalRecordService.insertPatientMedicalRecord({
      patient_id: patientId,
      uploaded_by: 'patient',
      record_type: recordType || 'attachment',
      title,
      description,
      category,
      attachments: [req.file.filename],
      used_for_ai_matching: usedForAiMatching,
      ai_ready: aiReady,
      extracted_text_status: extractedTextStatus,
      medical_summary: medicalSummary,
      detected_category: detectedCategory,
      tags,
      private_label: true,
      uploaded_after_visit: false,
      file_url: fileUrl,
      file_name: req.file.originalname,
      file_extension: fileExtension,
      file_size: req.file.size,
      source: req.body.source || 'patient_upload',
      notes: req.body.notes || description,
    });

    res.status(201).json(row);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}];

exports.deletePatientMedicalRecord = async (req, res) => {
  try {
    const { recordId } = req.params;
    const { userId, role } = actor(req);
    const row = await medicalRecordService.getPatientMedicalRecordById(recordId);
    if (!row) return res.status(404).json({ error: 'Record not found' });
    if (role !== 'admin' && userId !== row.patient_id) {
      return forbid(res, 'You can only delete your own records.');
    }

    await medicalRecordService.deletePatientMedicalRecord(recordId);

    const deleteFile = (fileName) => {
      if (typeof fileName === 'string' && fileName.trim()) {
        const fullPath = path.join(uploadsDir, fileName);
        if (fs.existsSync(fullPath)) {
          try {
            fs.unlinkSync(fullPath);
            console.log(`Deleted file physically from storage: ${fullPath}`);
          } catch (e) {
            console.error(`Error deleting physical file: ${e.message}`);
          }
        }
      }
    };

    if (row.attachments) {
      if (Array.isArray(row.attachments)) {
        row.attachments.forEach(deleteFile);
      } else {
        try {
          const parsed = JSON.parse(row.attachments);
          if (Array.isArray(parsed)) {
            parsed.forEach(deleteFile);
          }
        } catch (_) {}
      }
    }

    if (row.file_url) {
      try {
        const parsedUrl = new URL(row.file_url);
        const fileName = path.basename(parsedUrl.pathname);
        deleteFile(fileName);
      } catch (_) {
        const fileName = path.basename(row.file_url);
        deleteFile(fileName);
      }
    }

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

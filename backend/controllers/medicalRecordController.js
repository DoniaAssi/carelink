const medicalRecordService = require('../services/medicalRecordService');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const pdfParse = require('pdf-parse');

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

function resolveUploadUrl(storedPath, originalName, baseUrl) {
  const cleanStored = (storedPath || '').toString().trim();
  const cleanOriginal = (originalName || '').toString().trim();

  const candidates = [];
  if (cleanStored) candidates.push(path.basename(cleanStored));
  if (cleanOriginal) candidates.push(path.basename(cleanOriginal));

  for (const candidate of candidates) {
    const fullPath = path.join(uploadsDir, candidate);
    if (fs.existsSync(fullPath)) return `${baseUrl}/uploads/${candidate}`;
  }

  if (cleanOriginal) {
    try {
      const match = fs
        .readdirSync(uploadsDir)
        .find(
          (name) =>
            name === cleanOriginal || name.endsWith(`-${cleanOriginal}`)
        );
      if (match) return `${baseUrl}/uploads/${match}`;
    } catch (_) {}
  }

  if (!cleanStored) return '';
  if (cleanStored.startsWith('http://') || cleanStored.startsWith('https://')) {
    return cleanStored;
  }
  const normalized = cleanStored.startsWith('/') ? cleanStored : `/${cleanStored}`;
  return `${baseUrl}${normalized}`;
}

/** GET /medical-records/patient/:patientId â€” combined provider visit reports and patient uploads */
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
    const baseUrl = process.env.BACKEND_URL || (req.protocol + '://' + req.get('host'));
    const patientUploads = await medicalRecordService.listPatientMedicalRecordsForPatient(
      patientId
    );
    patientUploads.forEach(u => {
      u.file_url = resolveUploadUrl(u.file_url, u.file_name, baseUrl);
    });

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

/** POST /medical-records/visit-report â€” doctor / nurse / admin only */
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
    if (!(await medicalRecordService.tableExists('patientmedicalfile'))) {
      res.status(503).json({
        error:
          'patientmedicalfile table missing. Run backend/sql migrations for patientmedicalfile.',
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
    const usedForAiMatching = true;
    const aiReady = false;
    const medicalSummary = (req.body.medical_summary ?? req.body.medicalSummary ?? '').toString().trim();
    const detectedCategory = (req.body.detected_category ?? req.body.detectedCategory ?? '').toString().trim();
    const tags = parseTags(req.body.tags ?? req.body.tagList ?? '');

    // Multer uses latin1 encoding by default, fix encoding for Arabic/non-ASCII characters
    const originalNameUtf8 = Buffer.from(req.file.originalname, 'latin1').toString('utf8');

    const fileExtension = path.extname(originalNameUtf8).toLowerCase().replace('.', '');
    const relativeUrl = '/uploads/' + req.file.filename;
    const baseUrl = process.env.BACKEND_URL || (req.protocol + '://' + req.get('host'));
    const absoluteUrl = baseUrl + relativeUrl;

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
      extracted_text_status: 'pending',
      medical_summary: medicalSummary,
      detected_category: detectedCategory,
      tags,
      private_label: true,
      uploaded_after_visit: false,
      file_url: relativeUrl,
      file_name: originalNameUtf8,
      file_extension: fileExtension,
      mime_type: req.file.mimetype,
      file_size: req.file.size,
      source: req.body.source || 'patient_upload',
      notes: req.body.notes || description,
    });

    // Send back absolute URL to the client for immediate use
    row.file_url = absoluteUrl;

    res.status(201).json(row);

    // Process AI asynchronously in the background
    processRecordAi(row.id).catch(err => console.error('Background AI processing failed:', err));
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
        const parsedUrl = new URL(row.file_url, 'http://dummy.com'); // Handles relative paths safely
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

/** POST /medical-records/:id/analyze - also called internally after upload */
function summarizeText(kind, text, extra = '') {
  const normalized = (text || '').replace(/\s+/g, ' ').trim();
  const preview = normalized.substring(0, 220);
  const suffix = normalized.length > 220 ? '...' : '';
  return `${kind} processed successfully. Content preview: "${preview}${suffix}"${extra}`;
}

function hasAny(text, terms) {
  return terms.some((term) => text.includes(term));
}

function extractAnalysisTags(text) {
  const normalized = (text || '').toLowerCase();
  const tags = [];

  function add(tag, terms) {
    if (hasAny(normalized, terms) && !tags.includes(tag)) {
      tags.push(tag);
    }
  }

  // Conditions
  add('diabetes', ['diabetes', 'diabetic', 'hba1c', 'glucose', 'blood sugar', 'metformin', 'insulin', 'fasting blood glucose']);
  add('hypertension', ['hypertension', 'blood pressure', 'amlodipine', '160/98', '155/95', '140/90']);
  add('cholesterol', ['cholesterol', 'ldl', 'atorvastatin', 'hyperlipidemia', 'lipid', 'triglyceride']);
  add('cardiovascular_risk', ['cardiovascular', 'cardiovascular risk', 'cholesterol', 'ldl', 'hypertension', 'blood pressure', 'cardiac risk']);

  // Specialties
  add('cardiology', ['cardiology', 'cardiologist', 'cardiac', 'heart', 'cardiovascular', 'chest pain', 'ecg', 'echocardiogram']);
  add('endocrinology', ['endocrinology', 'endocrinologist', 'diabetes', 'hba1c', 'glucose', 'thyroid', 'hormone']);

  // Care needs
  add('blood_pressure_monitoring', ['blood pressure', 'hypertension', 'bp monitoring', 'blood pressure monitoring']);
  add('home_nursing', ['home nursing', 'blood pressure monitoring', 'glucose monitoring', 'medication adherence', 'home care', 'elderly', 'fall risk', 'wound', 'dressing', 'post-operative', 'post surgery']);
  add('wound_care', ['wound', 'dressing', 'suture', 'laceration', 'post-operative', 'surgical wound', 'incision']);
  add('post_surgery_care', ['post surgery', 'post-operative', 'post-op', 'surgery', 'surgical', 'operation']);
  add('elderly_care', ['elderly', 'fall risk', 'mobility', 'geriatric', 'nursing home', 'dementia', 'frailty']);
  add('medication_followup', ['metformin', 'amlodipine', 'atorvastatin', 'medication adherence', 'medication monitoring', 'medications prescribed', 'continue prescribed medications', 'pill', 'dosage']);

  return tags;
}

function buildRuleBasedMedicalSummary(text, fallbackKind, extra = '') {
  const normalized = (text || '').replace(/\s+/g, ' ').trim();
  const lowerText = normalized.toLowerCase();
  if (!normalized) return summarizeText(fallbackKind, text, extra);

  const conditions = [];
  if (hasAny(lowerText, ['poorly controlled diabetes', 'diabetes', 'hba1c', 'glucose', 'blood sugar', 'fasting blood glucose'])) {
    conditions.push(hasAny(lowerText, ['poorly controlled']) ? 'poorly controlled diabetes' : 'diabetes');
  }
  if (hasAny(lowerText, ['hypertension', 'blood pressure'])) {
    conditions.push('hypertension');
  }
  if (hasAny(lowerText, ['high cholesterol', 'cholesterol', 'ldl', 'hyperlipidemia'])) {
    conditions.push('high cholesterol');
  }
  if (hasAny(lowerText, ['wound', 'surgical wound', 'dressing', 'post-operative', 'post surgery'])) {
    conditions.push('post-surgical wound care');
  }
  if (hasAny(lowerText, ['elderly', 'fall risk', 'mobility issues', 'geriatric'])) {
    conditions.push('elderly care needs');
  }

  const followUps = [];
  if (hasAny(lowerText, ['endocrinologist', 'endocrinology', 'diabetes', 'hba1c'])) {
    followUps.push('endocrinology');
  }
  if (hasAny(lowerText, ['cardiologist', 'cardiology', 'cardiovascular', 'hypertension', 'cholesterol'])) {
    followUps.push('cardiology');
  }

  const careNeeds = [];
  if (hasAny(lowerText, ['blood pressure monitoring', 'hypertension', 'blood pressure'])) {
    careNeeds.push('blood pressure monitoring');
  }
  if (hasAny(lowerText, ['glucose monitoring', 'blood sugar', 'hba1c', 'diabetes'])) {
    careNeeds.push('glucose monitoring');
  }
  if (hasAny(lowerText, ['medication adherence', 'medication monitoring', 'medications'])) {
    careNeeds.push('medication adherence');
  }
  if (hasAny(lowerText, ['wound', 'dressing', 'post-operative', 'surgical wound'])) {
    careNeeds.push('wound dressing and post-operative care');
  }

  const medications = [];
  if (lowerText.includes('metformin')) medications.push('metformin');
  if (lowerText.includes('amlodipine')) medications.push('amlodipine');
  if (lowerText.includes('atorvastatin')) medications.push('atorvastatin');
  if (lowerText.includes('insulin')) medications.push('insulin');

  const sentences = [];
  if (conditions.length) {
    sentences.push(`This record indicates ${joinHumanList(conditions)}.`);
  }
  if (followUps.length) {
    sentences.push(`Follow-up with ${joinHumanList(followUps)} is recommended.`);
  }
  if (careNeeds.length) {
    sentences.push(`Home nursing support may help with ${joinHumanList(careNeeds)}.`);
  }
  if (medications.length) {
    sentences.push(`Current medications mentioned include ${joinHumanList(medications)}.`);
  }

  return sentences.length ? sentences.join(' ') : summarizeText(fallbackKind, text, extra);
}

function joinHumanList(items) {
  if (items.length <= 1) return items[0] || '';
  if (items.length === 2) return `${items[0]} and ${items[1]}`;
  return `${items.slice(0, -1).join(', ')}, and ${items[items.length - 1]}`;
}

function readMagicBytes(fullPath, length = 8) {
  try {
    const fd = fs.openSync(fullPath, 'r');
    const buffer = Buffer.alloc(length);
    fs.readSync(fd, buffer, 0, length, 0);
    fs.closeSync(fd);
    return buffer;
  } catch (_) {
    return Buffer.alloc(0);
  }
}

async function processRecordAi(recordId) {
  if (!recordId) throw new Error('Record ID is required.');

  const record = await medicalRecordService.getPatientMedicalRecordById(recordId);
  if (!record) throw new Error(`Record not found: ${recordId}`);

  await medicalRecordService.updatePatientMedicalRecordAi(recordId, {
    aiStatus: 'processing',
    aiProcessed: 0,
    ocrText: null,
    aiSummary: null,
    analysisTags: [],
  });

  const relativePath = record.file_url;
  if (!relativePath) {
    await medicalRecordService.updatePatientMedicalRecordAi(recordId, {
      aiStatus: 'failed',
      aiProcessed: 0,
      ocrText: 'Processing failed: no file path stored for this record.',
      aiSummary: null,
      analysisTags: [],
    });
    throw new Error('No file path found for this record.');
  }

  const fullPath = path.join(__dirname, '..', 'uploads', path.basename(relativePath));
  if (!fs.existsSync(fullPath)) {
    await medicalRecordService.updatePatientMedicalRecordAi(recordId, {
      aiStatus: 'failed',
      aiProcessed: 0,
      ocrText: `Processing failed: file not found on disk (${path.basename(relativePath)}).`,
      aiSummary: null,
      analysisTags: [],
    });
    throw new Error('File not found on disk.');
  }

  const storedMime = (record.mime_type || record.file_extension || '').toLowerCase();
  const extName = path.extname(relativePath).toLowerCase();
  const magicBytes = readMagicBytes(fullPath);
  const isPdfMagic = magicBytes.slice(0, 4).toString('ascii') === '%PDF';
  const isPdfByExt = extName === '.pdf';
  const isImageMime = storedMime.startsWith('image/');
  const isImageExt = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff'].includes(extName);
  const isTextMime = storedMime.startsWith('text/') || storedMime === 'text/plain';
  const isTextExt = extName === '.txt';

  let aiStatus = 'processed';
  let aiProcessed = 1;
  let extractedText = null;
  let aiSummary = null;
  let analysisTags = [];

  if (isPdfMagic) {
    try {
      const dataBuffer = fs.readFileSync(fullPath);
      const data = await pdfParse(dataBuffer);
      extractedText = (data.text || '').trim();
      if (extractedText) {
        const pageInfo = data.numpages ? ` (${data.numpages} page${data.numpages !== 1 ? 's' : ''})` : '';
        aiSummary = buildRuleBasedMedicalSummary(extractedText, 'PDF document', pageInfo);
        analysisTags = extractAnalysisTags(extractedText);
      } else {
        extractedText = 'PDF processed but contains no selectable text (may be a scanned document).';
        aiSummary = 'PDF uploaded successfully. The document appears to be scanned or image-based; no text could be extracted automatically.';
      }
    } catch (err) {
      aiStatus = 'failed';
      aiProcessed = 0;
      extractedText = `Failed to extract text from PDF: ${err.message}`;
      aiSummary = null;
      console.error(`[AI] PDF parse error for record ${recordId}:`, err.message);
    }
  } else if (isPdfByExt) {
    aiStatus = 'failed';
    aiProcessed = 0;
    let header = '';
    try {
      header = fs.readFileSync(fullPath, 'utf8').substring(0, 200).replace(/\s+/g, ' ').trim();
    } catch (_) {}
    extractedText = `File has .pdf extension but is not a valid PDF document. File header: "${header}"`;
    aiSummary = null;
  } else if ((isImageMime || isImageExt) && !isPdfMagic) {
    aiStatus = 'processed';
    aiProcessed = 1;
    extractedText = 'Image uploaded successfully. OCR is not available yet.';
    aiSummary = 'Image record uploaded. Manual review may be required.';
    analysisTags = [];
  } else if ((isTextMime || isTextExt) && !isPdfMagic) {
    try {
      extractedText = fs.readFileSync(fullPath, 'utf8').trim();
      aiSummary = extractedText
        ? buildRuleBasedMedicalSummary(extractedText, 'Text file')
        : 'Text file uploaded successfully, but it is empty.';
      analysisTags = extractAnalysisTags(extractedText);
      if (!extractedText) extractedText = 'Text file processed but no text content was found.';
    } catch (err) {
      aiStatus = 'failed';
      aiProcessed = 0;
      extractedText = `Failed to read text file: ${err.message}`;
      aiSummary = null;
    }
  } else {
    aiStatus = 'failed';
    aiProcessed = 0;
    extractedText = `Unsupported file format for analysis. Type detected: mime="${storedMime}", ext="${extName}". Supported formats: PDF, JPEG, PNG, GIF, WEBP, TXT.`;
    aiSummary = null;
  }

  const updated = await medicalRecordService.updatePatientMedicalRecordAi(recordId, {
    aiStatus,
    aiProcessed,
    ocrText: extractedText,
    aiSummary,
    analysisTags,
  });

  console.log(`[AI] Record ${recordId} -> aiStatus="${aiStatus}", ocrLen=${(extractedText || '').length}, hasSummary=${!!aiSummary}`);
  return updated;
}

exports.analyzePatientRecord = async (req, res) => {
  try {
    const { recordId } = req.params;
    const updated = await processRecordAi(recordId);
    res.json(updated);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.reprocessPending = async (req, res) => {
  try {
    const db = require('../db');
    const [rows] = await db.query(
      `SELECT id, title, aiStatus FROM patientmedicalfile WHERE aiStatus IN ('pending', 'failed') ORDER BY uploadDate ASC`
    );

    const results = [];
    for (const row of rows) {
      try {
        const updated = await processRecordAi(row.id);
        results.push({ id: row.id, title: row.title, aiStatus: updated?.extracted_text_status || 'processed', result: 'processed' });
      } catch (err) {
        results.push({ id: row.id, title: row.title, result: 'error', error: err.message });
      }
    }

    res.json({
      message: rows.length ? `Reprocessed ${rows.length} record(s).` : 'No pending or failed records to reprocess.',
      count: rows.length,
      results,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.processRecordAi = processRecordAi;

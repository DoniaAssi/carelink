import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({
    super.key,
    this.patientId,
    this.userId,
    this.initialTab = 0,
  });
  final String? patientId;
  final String? userId;
  final int initialTab;
  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final MedicalRecordService _service = MedicalRecordService();
  List<MedicalRecordEntry> _records = [];
  bool _loading = true;
  String? _error;
  String? _patientId;
  bool _resolved = false;
  Timer? _refreshTimer;

  bool get _isArabic => localeController.isArabic;
  String _t(String en, String ar) => _isArabic ? ar : en;
  int get _processingCount => _records
      .where(
        (r) =>
            r.extractedTextStatus == 'pending' ||
            r.extractedTextStatus == 'processing',
      )
      .length;
  int get _readyCount =>
      _records.where((r) => r.extractedTextStatus == 'processed').length;
  int get _failedCount =>
      _records.where((r) => r.extractedTextStatus == 'failed').length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = args is Map<String, dynamic> ? args : null;
    _patientId =
        widget.patientId ??
        widget.userId ??
        map?['patientId']?.toString() ??
        map?['userId']?.toString();
    _resolved = true;
    _loadRecords();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final patientId = _patientId?.trim() ?? '';
    if (patientId.isEmpty) {
      setState(() {
        _loading = false;
        _error = _t(
          'Session expired. Please sign in again.',
          'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.',
        );
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.listForPatient(
        patientId,
        requesterUserId: patientId,
        requesterRole: 'patient',
      );
      final parsed = rows.map((row) => _entryFromRow(row, patientId)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _records = parsed;
        _loading = false;
      });
      _syncRefreshTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _silentLoadRecords() async {
    final patientId = _patientId?.trim() ?? '';
    if (patientId.isEmpty) return;
    try {
      final rows = await _service.listForPatient(
        patientId,
        requesterUserId: patientId,
        requesterRole: 'patient',
      );
      final parsed = rows.map((row) => _entryFromRow(row, patientId)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() => _records = parsed);
      _syncRefreshTimer();
    } catch (_) {}
  }

  void _syncRefreshTimer() {
    if (_processingCount > 0) {
      _refreshTimer ??= Timer.periodic(
        const Duration(seconds: 3),
        (_) => _silentLoadRecords(),
      );
      return;
    }
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  MedicalRecordEntry _entryFromRow(Map<String, dynamic> row, String patientId) {
    final uploadedBy = (row['uploaded_by'] ?? row['uploadedBy'] ?? 'doctor')
        .toString();
    if (uploadedBy == 'patient') {
      return MedicalRecordEntry(
        id: (row['id'] ?? row['recordId'] ?? '').toString(),
        patientId: patientId,
        uploadedBy: 'patient',
        type: _typeFrom(
          (row['record_type'] ?? row['recordType'] ?? 'attachment').toString(),
        ),
        title:
            (row['title'] ??
                    row['file_name'] ??
                    row['fileName'] ??
                    _t('Medical record', 'سجل طبي'))
                .toString(),
        description: (row['description'] ?? row['notes'] ?? '').toString(),
        notes: (row['notes'] ?? row['description'] ?? '').toString(),
        attachments: _stringList(row['attachments']),
        createdAt:
            DateTime.tryParse(
              (row['created_at'] ?? row['createdAt'] ?? '').toString(),
            ) ??
            DateTime.now(),
        usedByAi: true,
        privateLabel: row['private_label'] != false,
        uploadedAfterVisit: _bool(
          row['uploaded_after_visit'] ?? row['uploadedAfterVisit'],
        ),
        category: (row['category'] ?? '').toString(),
        fileUrl: row['file_url']?.toString() ?? row['fileUrl']?.toString(),
        fileName: row['file_name']?.toString() ?? row['fileName']?.toString(),
        fileExtension:
            row['file_extension']?.toString() ??
            row['fileExtension']?.toString(),
        fileSize: row['file_size'] != null
            ? int.tryParse(row['file_size'].toString())
            : null,
        aiReady: _bool(row['ai_ready'] ?? row['aiReady']),
        extractedTextStatus:
            (row['extracted_text_status'] ??
                    row['extractedTextStatus'] ??
                    'pending')
                .toString(),
        extractedText:
            row['extracted_text']?.toString() ??
            row['extractedText']?.toString(),
        medicalSummary:
            row['medical_summary']?.toString() ??
            row['medicalSummary']?.toString(),
        detectedCategory:
            row['detected_category']?.toString() ??
            row['detectedCategory']?.toString(),
        tags: _stringList(row['tags']),
        usedForAiMatching: true,
        source: (row['source'] ?? 'patient_upload').toString(),
      );
    }
    final diagnosis = (row['diagnosis'] ?? '').toString();
    return MedicalRecordEntry(
      id: (row['id'] ?? row['recordId'] ?? '').toString(),
      patientId: patientId,
      appointmentId:
          row['appointment_id']?.toString() ?? row['appointmentId']?.toString(),
      uploadedBy: uploadedBy,
      type: MedicalRecordEntryType.visitReport,
      title:
          (row['title'] ??
                  (diagnosis.isNotEmpty
                      ? diagnosis
                      : _t('Visit report', 'تقرير زيارة')))
              .toString(),
      description: (row['notes'] ?? '').toString(),
      notes: (row['notes'] ?? '').toString(),
      diagnosis: diagnosis,
      createdAt:
          DateTime.tryParse(
            (row['visit_date'] ?? row['created_at'] ?? row['createdAt'] ?? '')
                .toString(),
          ) ??
          DateTime.now(),
      usedByAi: true,
      aiReady: true,
      extractedTextStatus: 'processed',
      usedForAiMatching: true,
      uploadedAfterVisit: true,
    );
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {
        return [value];
      }
    }
    return const [];
  }

  bool _bool(Object? value) =>
      value == true || value == 1 || value?.toString().toLowerCase() == 'true';

  MedicalRecordEntryType _typeFrom(String raw) {
    switch (raw) {
      case 'visit_report':
        return MedicalRecordEntryType.visitReport;
      case 'lab_result':
        return MedicalRecordEntryType.labResult;
      case 'prescription':
        return MedicalRecordEntryType.prescription;
      case 'diagnosis':
        return MedicalRecordEntryType.diagnosis;
      case 'old_report':
        return MedicalRecordEntryType.oldReport;
      default:
        return MedicalRecordEntryType.attachment;
    }
  }

  String _cleanError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 170 ||
        lower.contains('<html') ||
        lower.contains('<!doctype')) {
      return _t(
        'Something went wrong. Please try again.',
        'حدث خطأ. يرجى المحاولة مرة أخرى.',
      );
    }
    return raw;
  }

  void _showSnack(String message, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? scheme.error : scheme.primary,
        content: Text(message),
      ),
    );
  }

  Future<void> _openUploadFlow() async {
    final patientId = _patientId?.trim() ?? '';
    if (patientId.isEmpty) {
      _showSnack(
        _t(
          'Session expired. Please sign in again.',
          'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.',
        ),
        error: true,
      );
      return;
    }

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'txt'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      if (file.size > 12 * 1024 * 1024) {
        _showSnack(
          _t(
            'File is too large. Maximum size is 12MB.',
            'حجم الملف كبير جدا. الحد الأقصى 12 ميغابايت.',
          ),
          error: true,
        );
        return;
      }

      final titleController = TextEditingController(
        text: file.name.split('.').first,
      );
      final notesController = TextEditingController();
      const categories = [
        'Radiology',
        'Lab Test',
        'Prescription',
        'Diagnosis',
        'Surgery Report',
        'Discharge Summary',
        'Other',
      ];
      String selectedCategory = 'Lab Test';

      if (!mounted) return;
      final save = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            final p = CarelinkPalette.of(context);
            final scheme = Theme.of(context).colorScheme;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: p.stroke,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _t('Upload Medical Record', 'رفع سجل طبي'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _pickedFileTile(file, p),
                      const SizedBox(height: 18),
                      _sheetTextField(
                        p: p,
                        controller: titleController,
                        label: _t('Title *', 'العنوان *'),
                        hint: _t('Record title', 'عنوان السجل'),
                      ),
                      const SizedBox(height: 14),
                      _sheetLabel(p, _t('Category *', 'التصنيف *')),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        dropdownColor: p.surface,
                        decoration: _sheetDecoration(p),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(_categoryText(c)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      _sheetTextField(
                        p: p,
                        controller: notesController,
                        label: _t('Notes (optional)', 'ملاحظات (اختياري)'),
                        hint: _t(
                          'Add context for this file',
                          'أضف ملاحظات لهذا الملف',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                side: BorderSide(color: p.stroke),
                              ),
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(_t('Cancel', 'إلغاء')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.primary,
                                foregroundColor: scheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                if (titleController.text.trim().isEmpty) {
                                  _showSnack(
                                    _t(
                                      'Please enter a valid title.',
                                      'يرجى إدخال عنوان صحيح.',
                                    ),
                                    error: true,
                                  );
                                  return;
                                }
                                Navigator.pop(context, true);
                              },
                              child: Text(
                                _t('Upload', 'رفع الملف'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

      if (save != true) return;
      setState(() => _loading = true);
      await _service.uploadPatientRecord(
        patientId: patientId,
        title: titleController.text.trim(),
        category: selectedCategory,
        notes: notesController.text.trim(),
        usedForAiMatching: true,
        aiReady: false,
        filePath: kIsWeb ? null : file.path,
        fileBytes: file.bytes,
        fileName: file.name,
      );
      await _loadRecords();
      if (mounted) {
        _showSnack(
          _t(
            'Medical record uploaded. Processing has started.',
            'تم رفع السجل الطبي وبدأت المعالجة.',
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(_t('Upload failed: $e', 'فشل الرفع: $e'), error: true);
    }
  }

  Future<void> _deleteRecord(MedicalRecordEntry record) async {
    final patientId = _patientId?.trim() ?? '';
    if (record.uploadedBy != 'patient') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final p = CarelinkPalette.of(context);
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: p.surface,
          title: Text(
            _t('Delete Record', 'حذف السجل'),
            style: TextStyle(color: p.inkDark),
          ),
          content: Text(
            _t(
              'Are you sure you want to delete this record?',
              'هل أنت متأكد أنك تريد حذف هذا السجل؟',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('Cancel', 'إلغاء')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: Text(_t('Delete', 'حذف')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      setState(() => _loading = true);
      await _service.deletePatientRecord(
        recordId: record.id,
        patientId: patientId,
      );
      await _loadRecords();
      if (mounted) _showSnack(_t('Record deleted.', 'تم حذف السجل.'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(
        _t(
          'Delete failed. Please try again.',
          'فشل الحذف. يرجى المحاولة مرة أخرى.',
        ),
        error: true,
      );
    }
  }

  Future<void> _viewFile(MedicalRecordEntry record) async {
    final url = _fileUrl(record);
    if (url == null) {
      _showSnack(_t('No file is attached.', 'لا يوجد ملف مرفق.'), error: true);
      return;
    }
    final ext = _extension(record, fallbackUrl: url);
    if (_isImageExt(ext)) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ImageViewerScreen(title: record.title, fileUrl: url),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _UnsupportedFileViewerScreen(entry: record, fileUrl: url),
      ),
    );
  }

  // Tag label lookup (human-readable)
  String _tagLabel(String tag) {
    const labels = {
      'diabetes': 'Diabetes',
      'hypertension': 'Hypertension',
      'cholesterol': 'Cholesterol',
      'cardiovascular_risk': 'Cardiovascular Risk',
      'cardiology': 'Cardiology',
      'endocrinology': 'Endocrinology',
      'blood_pressure_monitoring': 'BP Monitoring',
      'home_nursing': 'Home Nursing',
      'wound_care': 'Wound Care',
      'post_surgery_care': 'Post-Surgery',
      'elderly_care': 'Elderly Care',
      'medication_followup': 'Medication Follow-up',
    };
    return labels[tag.toLowerCase()] ??
        tag
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (w) =>
                  w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w,
            )
            .join(' ');
  }

  // Tag → condition / care-need / specialty bucket
  static const _conditionTags = {
    'diabetes',
    'hypertension',
    'cholesterol',
    'cardiovascular_risk',
  };
  static const _careNeedTags = {
    'blood_pressure_monitoring',
    'home_nursing',
    'wound_care',
    'post_surgery_care',
    'elderly_care',
    'medication_followup',
  };
  static const _specialtyTags = {'cardiology', 'endocrinology'};

  String _specialtyLabel(String tag) {
    const labels = {
      'cardiology': 'Cardiologist',
      'endocrinology': 'Endocrinologist',
    };
    return labels[tag] ?? _tagLabel(tag);
  }

  // P3: Redesigned summary modal
  void _viewSummary(MedicalRecordEntry record) {
    final summary = record.medicalSummary?.trim() ?? '';
    final hasSummary = summary.isNotEmpty;
    final ocrText = record.extractedText?.trim() ?? '';
    final hasOcr = ocrText.isNotEmpty;

    final conditions = record.tags
        .where((t) => _conditionTags.contains(t))
        .toList();
    final careNeeds = record.tags
        .where((t) => _careNeedTags.contains(t))
        .toList();
    final specialties = record.tags
        .where((t) => _specialtyTags.contains(t))
        .toList();
    // Infer home nursing provider if home_nursing tag is present
    final showHomeNursing = record.tags.contains('home_nursing');

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final p = CarelinkPalette.of(ctx);
        final scheme = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          minChildSize: 0.35,
          builder: (ctx, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: p.stroke,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text(
                    _t('Medical Summary', 'الملخص الطبي'),
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // AI Summary text
                  if (hasSummary) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        summary,
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ] else ...[
                    Text(
                      _t(
                        'No AI summary available yet.',
                        'لا يوجد ملخص ذكاء اصطناعي بعد.',
                      ),
                      style: TextStyle(color: p.inkMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                  ],
                  // Detected Conditions
                  if (conditions.isNotEmpty) ...[
                    _summarySection(
                      ctx,
                      p,
                      scheme,
                      _t('Detected Conditions', 'الحالات المكتشفة'),
                      Icons.monitor_heart_outlined,
                      Colors.red.shade700,
                      conditions.map(_tagLabel).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Detected Care Needs
                  if (careNeeds.isNotEmpty) ...[
                    _summarySection(
                      ctx,
                      p,
                      scheme,
                      _t('Detected Care Needs', 'احتياجات الرعاية المكتشفة'),
                      Icons.medical_services_outlined,
                      Colors.teal,
                      careNeeds.map(_tagLabel).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Recommended Specialists
                  if (specialties.isNotEmpty || showHomeNursing) ...[
                    _summarySection(
                      ctx,
                      p,
                      scheme,
                      _t('Recommended Specialists', 'التخصصات الموصى بها'),
                      Icons.person_search_outlined,
                      const Color(0xFF7C5CE7),
                      [
                        ...specialties.map(_specialtyLabel),
                        if (showHomeNursing &&
                            !specialties.contains('home_nursing'))
                          _t(
                            'Home Nursing Provider',
                            'مزود رعاية تمريضية منزلية',
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Advanced: OCR text (collapsed by default)
                  if (hasOcr)
                    _OcrExpandableSection(
                      ocrText: ocrText,
                      p: p,
                      scheme: scheme,
                      isArabic: _isArabic,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summarySection(
    BuildContext ctx,
    CarelinkPalette p,
    ColorScheme scheme,
    String title,
    IconData icon,
    Color color,
    List<String> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: p.inkDark,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _fileUrl(MedicalRecordEntry record) {
    final url = record.fileUrl?.trim();
    if (url != null && url.isNotEmpty) return _normalizeFileUrl(url);
    if (record.attachments.isNotEmpty) {
      return _normalizeFileUrl(record.attachments.first);
    }
    return null;
  }

  String _normalizeFileUrl(String raw) {
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.encodeFull(value);
    }
    if (value.startsWith('/uploads/')) {
      return Uri.encodeFull('${ApiService.baseUrl}$value');
    }
    if (value.startsWith('uploads/')) {
      return Uri.encodeFull('${ApiService.baseUrl}/$value');
    }
    return Uri.encodeFull('${ApiService.baseUrl}/uploads/$value');
  }

  String _extension(MedicalRecordEntry record, {String? fallbackUrl}) {
    final raw = record.fileExtension?.trim().toLowerCase() ?? '';
    if (raw.contains('/')) return raw.split('/').last;
    if (raw.isNotEmpty) return raw.replaceFirst('.', '');
    final url = fallbackUrl ?? record.fileUrl ?? record.fileName ?? '';
    final clean = url.split('?').first;
    final index = clean.lastIndexOf('.');
    return index == -1 ? '' : clean.substring(index + 1).toLowerCase();
  }

  bool _isImageExt(String ext) =>
      const {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(ext.toLowerCase());

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _categoryText(String category) {
    if (!_isArabic) return category;
    const labels = {
      'Radiology': 'أشعة',
      'Lab Test': 'تحاليل',
      'Prescription': 'وصفة طبية',
      'Diagnosis': 'تشخيص',
      'Surgery Report': 'تقرير عملية',
      'Discharge Summary': 'تقرير خروج',
      'Other': 'أخرى',
    };
    return labels[category] ?? category;
  }

  String _categoryLabel(MedicalRecordEntry record) {
    final category = record.category?.trim();
    if (category != null && category.isNotEmpty) return _categoryText(category);
    if (record.uploadedBy != 'patient') {
      return _t('Visit report', 'تقرير زيارة');
    }
    return _t('Medical file', 'ملف طبي');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        final p = CarelinkPalette.of(context);
        return Directionality(
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: p.pageBg,
            appBar: AppBar(
              backgroundColor: p.pageBg,
              elevation: 0,
              actions: [
                PatientHeaderActions(
                  showLanguage: true,
                  showTheme: true,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadRecords,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _buildSummaryRow(p),
                    const SizedBox(height: 12),
                    _buildUploadCard(p),
                    const SizedBox(height: 18),
                    _recordsHeader(p),
                    const SizedBox(height: 8),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _buildErrorState(p)
                    else if (_records.isEmpty)
                      _buildEmptyState(p)
                    else
                      ..._records.map((record) => _recordTile(p, record)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(CarelinkPalette p) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.35,
      padding: const EdgeInsets.only(bottom: 6),
      children: [
        _summaryPill(
          p,
          _t('Total', 'الإجمالي'),
          '${_records.length}',
          Icons.folder_copy_outlined,
          scheme.primary,
        ),
        _summaryPill(
          p,
          _t('Ready', 'جاهز'),
          '$_readyCount',
          Icons.check_circle_outline_rounded,
          Colors.green,
        ),
        _summaryPill(
          p,
          _t('Processing', 'قيد المعالجة'),
          '$_processingCount',
          Icons.sync_rounded,
          Colors.blue,
        ),
        _summaryPill(
          p,
          _t('Failed', 'فشل'),
          '$_failedCount',
          Icons.error_outline_rounded,
          scheme.error,
        ),
      ],
    );
  }

  Widget _summaryPill(
    CarelinkPalette p,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard(CarelinkPalette p) {
    final scheme = Theme.of(context).colorScheme;
    return PatientPressable(
      onTap: _openUploadFlow,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.stroke),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.upload_file_rounded,
                  color: scheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Upload Medical Record', 'رفع سجل طبي'),
                      style: TextStyle(
                        color: p.inkDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(
                        'Reports, scans, prescriptions, images',
                        'تقارير، صور أشعة، وصفات طبية',
                      ),
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _openUploadFlow,
                child: Text(_t('Upload', 'رفع')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordsHeader(CarelinkPalette p) {
    return Row(
      children: [
        Text(
          _t('Records', 'السجلات'),
          style: TextStyle(
            color: p.inkDark,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        if (!_loading && _error == null)
          Text(
            '${_records.length}',
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }

  Widget _recordTile(CarelinkPalette p, MedicalRecordEntry record) {
    final scheme = Theme.of(context).colorScheme;
    final status = _statusStyle(record, scheme);
    final canShowSummary = record.extractedTextStatus == 'processed';
    final isPatientUpload = record.uploadedBy == 'patient';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _recordThumb(p, record),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _categoryLabel(record),
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('-', style: TextStyle(color: p.inkMuted)),
                    Text(
                      _formatDate(record.createdAt),
                      style: TextStyle(color: p.inkMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _badge(status.label, status.color, status.icon),
                // P5: Medical tags chips
                if (record.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: record.tags.take(5).map((tag) {
                      final label = _tagLabel(tag);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _actionButton(
                      _t('View', 'عرض'),
                      Icons.visibility_outlined,
                      scheme.primary,
                      () => _viewFile(record),
                    ),
                    if (canShowSummary)
                      _actionButton(
                        _t('Summary', 'الملخص'),
                        Icons.notes_rounded,
                        Colors.green,
                        () => _viewSummary(record),
                      ),
                    if (isPatientUpload)
                      _actionButton(
                        _t('Delete', 'حذف'),
                        Icons.delete_outline_rounded,
                        scheme.error,
                        () => _deleteRecord(record),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({String label, Color color, IconData icon}) _statusStyle(
    MedicalRecordEntry record,
    ColorScheme scheme,
  ) {
    switch (record.extractedTextStatus) {
      case 'failed':
        return (
          label: _t('Failed', 'فشل'),
          color: scheme.error,
          icon: Icons.error_outline_rounded,
        );
      case 'processed':
        return (
          label: _t('Ready', 'جاهز'),
          color: Colors.green,
          icon: Icons.check_circle_outline_rounded,
        );
      case 'pending':
      case 'processing':
      default:
        return (
          label: _t('Processing', 'قيد المعالجة'),
          color: Colors.blue,
          icon: Icons.sync_rounded,
        );
    }
  }

  Widget _actionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return PatientPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordThumb(CarelinkPalette p, MedicalRecordEntry record) {
    final scheme = Theme.of(context).colorScheme;
    final url = _fileUrl(record);
    final ext = _extension(record, fallbackUrl: url);
    if (url != null && _isImageExt(ext)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fileIconBox(p, record),
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_fileIcon(record), color: scheme.primary, size: 23),
    );
  }

  Widget _fileIconBox(CarelinkPalette p, MedicalRecordEntry record) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      color: scheme.primary.withValues(alpha: 0.1),
      child: Icon(_fileIcon(record), color: scheme.primary, size: 23),
    );
  }

  IconData _fileIcon(MedicalRecordEntry record) {
    final ext = _extension(record);
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (_isImageExt(ext)) return Icons.image_rounded;
    if (record.uploadedBy != 'patient') return Icons.assignment_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Widget _buildEmptyState(CarelinkPalette p) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54),
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded, size: 50, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            _t('No records yet', 'لا توجد سجلات بعد'),
            style: TextStyle(
              color: p.inkDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t('Upload your first medical record.', 'ارفع أول سجل طبي لك.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openUploadFlow,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(_t('Upload First Record', 'ارفع أول سجل')),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(CarelinkPalette p) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
          const SizedBox(height: 12),
          Text(
            _t('Failed to load records', 'فشل تحميل السجلات'),
            style: TextStyle(
              color: p.inkDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadRecords,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_t('Retry', 'إعادة المحاولة')),
          ),
        ],
      ),
    );
  }

  Widget _pickedFileTile(PlatformFile file, CarelinkPalette p) {
    final scheme = Theme.of(context).colorScheme;
    final ext = (file.extension ?? '').toLowerCase();
    final sizeText = file.size > 1024 * 1024
        ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(file.size / 1024).toStringAsFixed(0)} KB';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              ext == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              color: scheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sizeText,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _sheetTextField({
    required CarelinkPalette p,
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetLabel(p, label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w600),
          decoration: _sheetDecoration(p, hint),
        ),
      ],
    );
  }

  Widget _sheetLabel(CarelinkPalette p, String label) {
    return Text(
      label,
      style: TextStyle(
        color: p.inkMuted,
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  InputDecoration _sheetDecoration(CarelinkPalette p, [String? hint]) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: p.inkMuted.withValues(alpha: 0.55)),
      filled: true,
      fillColor: p.pageBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    );
  }
}

// P3: Expandable OCR section for the summary modal
class _OcrExpandableSection extends StatefulWidget {
  const _OcrExpandableSection({
    required this.ocrText,
    required this.p,
    required this.scheme,
    required this.isArabic,
  });
  final String ocrText;
  final CarelinkPalette p;
  final ColorScheme scheme;
  final bool isArabic;

  @override
  State<_OcrExpandableSection> createState() => _OcrExpandableSectionState();
}

class _OcrExpandableSectionState extends State<_OcrExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.isArabic ? 'تفاصيل متقدمة' : 'Advanced Details';
    final sublabel = widget.isArabic ? 'نص OCR المستخرج' : 'Extracted OCR Text';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PatientPressable(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.p.pageBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.p.stroke),
            ),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: widget.p.inkMuted,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: widget.p.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 10),
          Text(
            sublabel,
            style: TextStyle(
              color: widget.p.inkMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.p.pageBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.p.stroke),
            ),
            child: Text(
              widget.ocrText,
              style: TextStyle(
                color: widget.p.inkMuted,
                fontSize: 12,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageViewerScreen extends StatelessWidget {
  const _ImageViewerScreen({required this.title, required this.fileUrl});
  final String title;
  final String fileUrl;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: AppBar(
        backgroundColor: p.pageBg,
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            fileUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.broken_image_outlined, size: 64, color: p.inkMuted),
          ),
        ),
      ),
    );
  }
}

class _UnsupportedFileViewerScreen extends StatelessWidget {
  const _UnsupportedFileViewerScreen({
    required this.entry,
    required this.fileUrl,
  });
  final MedicalRecordEntry entry;
  final String fileUrl;
  bool get _isArabic => localeController.isArabic;
  String _t(String en, String ar) => _isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: AppBar(
        backgroundColor: p.pageBg,
        foregroundColor: p.inkDark,
        elevation: 0,
        title: Text(
          entry.title,
          style: TextStyle(
            color: p.inkDark,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 58,
                color: scheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                _t('File Details', 'تفاصيل الملف'),
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.fileName ?? entry.title,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.inkMuted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(fileUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(_t('Open / Download', 'فتح / تحميل')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

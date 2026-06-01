import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
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

  bool get _isArabic => localeController.isArabic;

  String _t(String en, String ar) => _isArabic ? ar : en;

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

  Future<void> _loadRecords() async {
    final patientId = _patientId?.trim() ?? '';
    setState(() {
      _loading = true;
      _error = null;
    });

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(e);
      });
    }
  }

  MedicalRecordEntry _entryFromRow(Map<String, dynamic> row, String patientId) {
    final uploadedBy = (row['uploaded_by'] ?? row['uploadedBy'] ?? 'doctor')
        .toString();
    if (uploadedBy == 'patient') {
      final tags = _stringList(row['tags']);
      final attachments = _stringList(row['attachments']);
      final type = _typeFrom(
        (row['record_type'] ?? row['recordType'] ?? 'attachment').toString(),
      );
      return MedicalRecordEntry(
        id: (row['id'] ?? row['recordId'] ?? '').toString(),
        patientId: patientId,
        uploadedBy: 'patient',
        type: type,
        title:
            (row['title'] ??
                    row['file_name'] ??
                    row['fileName'] ??
                    _t('Medical record', 'سجل طبي'))
                .toString(),
        description: (row['description'] ?? row['notes'] ?? '').toString(),
        notes: (row['notes'] ?? row['description'] ?? '').toString(),
        attachments: attachments,
        createdAt:
            DateTime.tryParse(
              (row['created_at'] ?? row['createdAt'] ?? '').toString(),
            ) ??
            DateTime.now(),
        usedByAi: _bool(
          row['used_for_ai_matching'] ?? row['usedForAiMatching'],
        ),
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
        tags: tags,
        usedForAiMatching: _bool(
          row['used_for_ai_matching'] ?? row['usedForAiMatching'],
        ),
        source: (row['source'] ?? 'patient_upload').toString(),
      );
    }

    final diagnosis = (row['diagnosis'] ?? '').toString();
    return MedicalRecordEntry(
      id: (row['id'] ?? row['recordId'] ?? '').toString(),
      patientId: patientId,
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
      attachments: const [],
      createdAt:
          DateTime.tryParse(
            (row['visit_date'] ?? row['created_at'] ?? row['createdAt'] ?? '')
                .toString(),
          ) ??
          DateTime.now(),
      usedByAi: true,
      privateLabel: true,
      uploadedAfterVisit: true,
      aiReady: true,
      usedForAiMatching: true,
    );
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
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

  int get _imageCount => _records.where((record) => _isImage(record)).length;

  int get _reportCount => _records.where((record) {
    final ext = _extension(record);
    return ext == 'pdf' ||
        record.type == MedicalRecordEntryType.visitReport ||
        record.type == MedicalRecordEntryType.oldReport;
  }).length;

  int get _aiReadyCount => _records
      .where(
        (record) =>
            record.uploadedBy != 'patient' ||
            (record.usedForAiMatching && record.aiReady),
      )
      .length;

  String _cleanError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 170 ||
        lower.contains('<html') ||
        lower.contains('<!doctype') ||
        lower.contains('<pre>')) {
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
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      if (!mounted) return;

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
      bool allowAi = true;

      final save = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final p = CarelinkPalette.of(context);
              final scheme = Theme.of(context).colorScheme;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: p.stroke,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _pickedFileTile(file, p),
                        const SizedBox(height: 16),
                        Text(
                          _t('Upload Medical Record', 'رفع سجل طبي'),
                          style: TextStyle(
                            color: p.inkDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sheetTextField(
                          p: p,
                          controller: titleController,
                          label: _t('Title', 'العنوان'),
                          hint: _t('Record title', 'عنوان السجل'),
                        ),
                        const SizedBox(height: 12),
                        _sheetLabel(p, _t('Category', 'التصنيف')),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          dropdownColor: p.surface,
                          style: TextStyle(color: p.inkDark, fontSize: 14),
                          decoration: _sheetDecoration(p),
                          items: categories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(_categoryText(category)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setModalState(() => selectedCategory = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        _sheetTextField(
                          p: p,
                          controller: notesController,
                          label: _t('Notes optional', 'ملاحظات اختيارية'),
                          hint: _t(
                            'Add context for this file',
                            'أضف ملاحظات للسجل',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: allowAi,
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: scheme.primary,
                          title: Text(
                            _t(
                              'Allow AI to use this file',
                              'السماح للذكاء الاصطناعي باستخدام الملف',
                            ),
                            style: TextStyle(
                              color: p.inkDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            _t(
                              'Helps recommendations match your health context.',
                              'يساعد في تحسين مطابقة توصيات الرعاية.',
                            ),
                            style: TextStyle(color: p.inkMuted, fontSize: 12),
                          ),
                          onChanged: (value) =>
                              setModalState(() => allowAi = value),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            if (titleController.text.trim().isEmpty) {
                              _showSnack(
                                _t(
                                  'Please enter a title.',
                                  'يرجى إدخال عنوان.',
                                ),
                              );
                              return;
                            }
                            Navigator.pop(context, true);
                          },
                          child: Text(
                            _t('Upload', 'رفع'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (save != true) return;
      setState(() => _loading = true);
      await _service.uploadPatientRecord(
        patientId: patientId,
        title: titleController.text.trim(),
        category: selectedCategory,
        notes: notesController.text.trim(),
        usedForAiMatching: allowAi,
        aiReady: allowAi,
        filePath: file.path,
        fileBytes: file.bytes,
        fileName: file.name,
      );
      await _loadRecords();
      if (mounted) {
        _showSnack(
          _t(
            'Medical record uploaded successfully.',
            'تم رفع السجل الطبي بنجاح.',
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(
        _t(
          'Upload failed. Please try again.',
          'فشل الرفع. يرجى المحاولة مرة أخرى.',
        ),
        error: true,
      );
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
    } catch (e) {
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

  void _viewFile(MedicalRecordEntry record) {
    final fileUrl = _fileUrl(record);
    if (fileUrl == null || fileUrl.trim().isEmpty) {
      _showDetails(record);
      return;
    }
    final ext = _extension(record, fallbackUrl: fileUrl);
    if (_isImageExt(ext)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _ImageViewerScreen(title: record.title, fileUrl: fileUrl),
        ),
      );
    } else if (ext == 'pdf') {
      launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _UnsupportedFileViewerScreen(entry: record, fileUrl: fileUrl),
        ),
      );
    }
  }

  void _showDetails(MedicalRecordEntry record) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final p = CarelinkPalette.of(context);
        return AlertDialog(
          backgroundColor: p.surface,
          title: Text(
            record.title,
            style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w800),
          ),
          content: Text(
            record.description.isNotEmpty
                ? record.description
                : _t('No file attached.', 'لا يوجد ملف مرفق.'),
            style: TextStyle(color: p.inkMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Close', 'إغلاق')),
            ),
          ],
        );
      },
    );
  }

  String? _fileUrl(MedicalRecordEntry record) {
    final direct = record.fileUrl?.trim();
    if (direct != null && direct.isNotEmpty) {
      if (direct.startsWith('http://') || direct.startsWith('https://')) {
        return direct;
      }
      final separator = direct.startsWith('/') ? '' : '/';
      return '${ApiService.baseUrl}$separator$direct';
    }
    if (record.attachments.isEmpty) return null;
    final path = record.attachments.first.trim();
    if (path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final separator = path.startsWith('/') ? '' : '/uploads/';
    return '${ApiService.baseUrl}$separator$path';
  }

  String _extension(MedicalRecordEntry record, {String? fallbackUrl}) {
    final explicit = record.fileExtension?.trim().toLowerCase();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit.replaceFirst('.', '');
    }
    final source =
        record.fileName ?? fallbackUrl ?? record.attachments.firstOrNull ?? '';
    final clean = source.split('?').first;
    final dot = clean.lastIndexOf('.');
    return dot >= 0 ? clean.substring(dot + 1).toLowerCase() : '';
  }

  bool _isImage(MedicalRecordEntry record) => _isImageExt(_extension(record));

  bool _isImageExt(String ext) =>
      ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext.toLowerCase());

  String _categoryText(String category) {
    final ar = {
      'Radiology': 'أشعة',
      'Lab Test': 'تحليل مخبري',
      'Prescription': 'وصفة طبية',
      'Diagnosis': 'تشخيص',
      'Surgery Report': 'تقرير عملية',
      'Discharge Summary': 'تقرير خروج',
      'Other': 'آخر',
    };
    return _t(category, ar[category] ?? category);
  }

  String _categoryLabel(MedicalRecordEntry record) {
    final category = record.category?.trim();
    if (record.uploadedBy == 'patient' &&
        category != null &&
        category.isNotEmpty) {
      return _categoryText(category);
    }
    switch (record.type) {
      case MedicalRecordEntryType.labResult:
        return _t('Lab Result', 'تحليل مخبري');
      case MedicalRecordEntryType.prescription:
        return _t('Prescription', 'وصفة طبية');
      case MedicalRecordEntryType.visitReport:
        return _t('Visit Report', 'تقرير زيارة');
      case MedicalRecordEntryType.oldReport:
        return _t('Medical Report', 'تقرير طبي');
      default:
        return _t('Medical File', 'ملف طبي');
    }
  }

  IconData _fileIcon(MedicalRecordEntry record) {
    final ext = _extension(record);
    if (_isImageExt(ext)) return Icons.image_outlined;
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (record.type == MedicalRecordEntryType.prescription) {
      return Icons.medication_outlined;
    }
    if (record.type == MedicalRecordEntryType.labResult) {
      return Icons.science_outlined;
    }
    if (record.type == MedicalRecordEntryType.visitReport) {
      return Icons.assignment_outlined;
    }
    return Icons.description_outlined;
  }

  String _formatDate(DateTime date) {
    final monthNames = _isArabic
        ? [
            'يناير',
            'فبراير',
            'مارس',
            'أبريل',
            'مايو',
            'يونيو',
            'يوليو',
            'أغسطس',
            'سبتمبر',
            'أكتوبر',
            'نوفمبر',
            'ديسمبر',
          ]
        : [
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
    return _isArabic
        ? '${date.day} ${monthNames[date.month - 1]} ${date.year}'
        : '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
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
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadRecords,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _buildHeader(p),
                    const SizedBox(height: 14),
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

  Widget _buildHeader(CarelinkPalette p) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            _t('Medical Records', 'السجل الطبي'),
            style: TextStyle(
              color: p.inkDark,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        CarelinkLocaleIconButton(color: scheme.primary),
        CarelinkThemeIconButton(color: scheme.primary),
      ],
    );
  }

  Widget _buildSummaryRow(CarelinkPalette p) {
    return Row(
      children: [
        _summaryPill(
          p,
          _t('Total', 'الإجمالي'),
          '${_records.length}',
          Icons.folder_outlined,
        ),
        const SizedBox(width: 8),
        _summaryPill(
          p,
          _t('Images', 'صور'),
          '$_imageCount',
          Icons.image_outlined,
        ),
        const SizedBox(width: 8),
        _summaryPill(
          p,
          _t('Reports', 'تقارير'),
          '$_reportCount',
          Icons.assignment_outlined,
        ),
        const SizedBox(width: 8),
        _summaryPill(
          p,
          _t('AI Ready', 'جاهز للذكاء'),
          '$_aiReadyCount',
          Icons.auto_awesome_rounded,
        ),
      ],
    );
  }

  Widget _summaryPill(
    CarelinkPalette p,
    String label,
    String value,
    IconData icon,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: p.inkDark,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(CarelinkPalette p) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openUploadFlow,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.stroke),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.upload_file_rounded,
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
                      _t('Upload Medical Record', 'رفع سجل طبي'),
                      style: TextStyle(
                        color: p.inkDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _t(
                        'Reports, scans, prescriptions, images',
                        'تقارير، أشعة، وصفات، صور',
                      ),
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size(72, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
    final category = _categoryLabel(record);
    final isPatientUpload = record.uploadedBy == 'patient';
    final aiReady = isPatientUpload
        ? record.usedForAiMatching && record.aiReady
        : true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _recordThumb(p, record),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        record.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (aiReady)
                      _badge(_t('AI Ready', 'جاهز للذكاء'), scheme.primary),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('•', style: TextStyle(color: p.inkMuted)),
                    Text(
                      _formatDate(record.createdAt),
                      style: TextStyle(color: p.inkMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _textAction(
                      _t('View', 'عرض'),
                      Icons.visibility_outlined,
                      scheme.primary,
                      () => _viewFile(record),
                    ),
                    if (isPatientUpload) ...[
                      const SizedBox(width: 8),
                      _textAction(
                        _t('Delete', 'حذف'),
                        Icons.delete_outline_rounded,
                        scheme.error,
                        () => _deleteRecord(record),
                      ),
                    ],
                  ],
                ),
              ],
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
        color: scheme.primary.withValues(alpha: 0.10),
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
      color: scheme.primary.withValues(alpha: 0.10),
      child: Icon(_fileIcon(record), color: scheme.primary, size: 23),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _textAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.pageBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          Icon(
            ext == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
            color: scheme.primary,
            size: 24,
          ),
          const SizedBox(width: 10),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${(file.size / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(color: p.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
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
        foregroundColor: p.inkDark,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            color: p.inkDark,
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

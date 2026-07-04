import 'dart:async';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/patient/screens/medical_record_details_screen.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart' as url_launcher;

enum _RecordsFilter { all, doctors, nurses, uploads }

enum _RecordStatus { ready, processing, failed, archived }

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
  final TextEditingController _searchController = TextEditingController();

  List<_PatientRecord> _records = const [];
  _RecordsFilter _filter = _RecordsFilter.all;
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  String _query = '';
  String? _patientId;
  bool _resolvedPatient = false;
  Timer? _processingRefresh;

  bool get _isArabic => localeController.isArabic;
  String _t(String english, String arabic) => _isArabic ? arabic : english;

  List<_PatientRecord> get _visibleRecords {
    final query = _query.trim().toLowerCase();
    return _records.where((record) {
      final matchesFilter = switch (_filter) {
        _RecordsFilter.all => true,
        _RecordsFilter.doctors => record.creatorRole == 'doctor',
        _RecordsFilter.nurses => record.creatorRole == 'nurse',
        _RecordsFilter.uploads => record.isPatientUpload,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      final searchableDate = intl.DateFormat(
        'yyyy-MM-dd MMM d yyyy',
      ).format(record.createdAt).toLowerCase();
      return record.title.toLowerCase().contains(query) ||
          record.category.toLowerCase().contains(query) ||
          record.creatorName.toLowerCase().contains(query) ||
          searchableDate.contains(query);
    }).toList();
  }

  int _count(_RecordsFilter filter) => _records.where((record) {
    return switch (filter) {
      _RecordsFilter.all => true,
      _RecordsFilter.doctors => record.creatorRole == 'doctor',
      _RecordsFilter.nurses => record.creatorRole == 'nurse',
      _RecordsFilter.uploads => record.isPatientUpload,
    };
  }).length;

  @override
  void initState() {
    super.initState();
    _filter = _RecordsFilter
        .values[widget.initialTab.clamp(0, _RecordsFilter.values.length - 1)];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedPatient) return;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final map = arguments is Map ? arguments : null;
    _patientId =
        widget.patientId ??
        widget.userId ??
        map?['patientId']?.toString() ??
        map?['userId']?.toString();
    _resolvedPatient = true;
    _loadRecords();
  }

  @override
  void dispose() {
    _processingRefresh?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords({bool silent = false}) async {
    final patientId = _patientId?.trim() ?? '';
    if (patientId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _t(
          'Session expired. Please sign in again.',
          'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.',
        );
      });
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final rows = await _service.listForPatient(
        patientId,
        requesterUserId: patientId,
        requesterRole: 'patient',
      );
      final records = rows.map(_PatientRecord.fromApi).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
        _error = null;
      });
      _syncProcessingRefresh();
    } catch (error) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  void _syncProcessingRefresh() {
    final needsRefresh = _records.any(
      (record) => record.status == _RecordStatus.processing,
    );
    if (needsRefresh) {
      _processingRefresh ??= Timer.periodic(
        const Duration(seconds: 4),
        (_) => _loadRecords(silent: true),
      );
    } else {
      _processingRefresh?.cancel();
      _processingRefresh = null;
    }
  }

  String _cleanError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty || message.length > 160 || message.contains('<html')) {
      return _t(
        'Could not load medical records. Please try again.',
        'تعذر تحميل السجلات الطبية. يرجى المحاولة مرة أخرى.',
      );
    }
    return _isArabic ? context.l10n.userMessage(error) : message;
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFFDC2626) : AppColors.primary,
        content: Text(message),
      ),
    );
  }

  Future<void> _uploadRecord() async {
    if (_uploading) return;
    final patientId = _patientId?.trim() ?? '';
    if (patientId.isEmpty) return;

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'txt'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      if (file.size > 12 * 1024 * 1024) {
        _showMessage(
          _t(
            'Maximum file size is 12 MB.',
            'الحد الأقصى لحجم الملف هو 12 ميغابايت.',
          ),
          error: true,
        );
        return;
      }

      final details = await _askUploadDetails(file);
      if (details == null || !mounted) return;
      setState(() => _uploading = true);
      await _service.uploadPatientRecord(
        patientId: patientId,
        title: details.$1,
        category: details.$2,
        notes: details.$3,
        usedForAiMatching: true,
        aiReady: false,
        filePath: kIsWeb ? null : file.path,
        fileBytes: file.bytes,
        fileName: file.name,
      );
      await _loadRecords(silent: true);
      _showMessage(
        _t(
          'Medical record uploaded successfully.',
          'تم رفع السجل الطبي بنجاح.',
        ),
      );
    } catch (error) {
      _showMessage(_cleanError(error), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<(String, String, String)?> _askUploadDetails(PlatformFile file) async {
    final title = TextEditingController(text: file.name.split('.').first);
    final notes = TextEditingController();
    const categories = [
      'Medical Report',
      'Lab Result',
      'Prescription',
      'Radiology',
      'Insurance',
      'Vaccination',
      'Other',
    ];
    var category = categories.first;
    final result = await showModalBottomSheet<(String, String, String)>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final p = CarelinkPalette.of(context);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: p.stroke,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _t('Upload Medical Record', 'رفع سجل طبي'),
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _uploadField(
                        p,
                        controller: title,
                        label: _t('Title', 'العنوان'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        dropdownColor: p.surface,
                        decoration: _inputDecoration(
                          p,
                          _t('Category', 'التصنيف'),
                        ),
                        items: categories
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => category = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _uploadField(
                        p,
                        controller: notes,
                        label: _t('Notes (optional)', 'ملاحظات (اختياري)'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () {
                          final value = title.text.trim();
                          if (value.isEmpty) return;
                          Navigator.pop(context, (
                            value,
                            category,
                            notes.text.trim(),
                          ));
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
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
    title.dispose();
    notes.dispose();
    return result;
  }

  Widget _uploadField(
    CarelinkPalette p, {
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: p.inkDark, fontSize: 14),
      decoration: _inputDecoration(p, label),
    );
  }

  InputDecoration _inputDecoration(CarelinkPalette p, String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: p.surfaceSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Future<void> _openRecord(_PatientRecord record) async {
    if (record.isPatientUpload) {
      _showFileActions(record);
    } else {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => MedicalRecordDetailsScreen(
            recordId: record.id,
            patientUserId: _patientId ?? '',
          ),
        ),
      );
      if (changed == true) await _loadRecords(silent: true);
    }
  }

  void _showFileActions(_PatientRecord record) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final p = CarelinkPalette.of(ctx);
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _recordTitle(record),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: p.inkDark,
                  ),
                ),
                const SizedBox(height: 12),
                _actionTile(
                  ctx,
                  p,
                  Icons.open_in_new_rounded,
                  _t('Open', 'فتح'),
                  () => _openRecordDirect(record),
                ),
                if (record.fileUrl != null && record.fileUrl!.isNotEmpty) ...[
                  _actionTile(
                    ctx,
                    p,
                    Icons.download_rounded,
                    _t('Download', 'تنزيل'),
                    () => _launch(record.fileUrl!),
                  ),
                  _actionTile(
                    ctx,
                    p,
                    Icons.share_outlined,
                    _t('Share', 'مشاركة'),
                    () => _launch(record.fileUrl!),
                  ),
                ],
                if (record.isPatientUpload)
                  _actionTile(
                    ctx,
                    p,
                    Icons.delete_outline_rounded,
                    _t('Delete', 'حذف'),
                    () => _deleteUpload(record),
                    danger: true,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionTile(
    BuildContext context,
    CarelinkPalette p,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFDC2626) : AppColors.primary;
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: danger ? color : p.inkDark,
        ),
      ),
      trailing: Icon(
        _isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        color: p.inkMuted,
      ),
    );
  }

  Future<void> _openRecordDirect(_PatientRecord record) async {
    if (record.fileUrl != null &&
        record.fileUrl!.isNotEmpty &&
        record.isPatientUpload) {
      await _launch(record.fileUrl!);
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MedicalRecordDetailsScreen(
          recordId: record.id,
          patientUserId: _patientId ?? '',
        ),
      ),
    );
    if (changed == true) await _loadRecords(silent: true);
  }

  Future<void> _deleteUpload(_PatientRecord record) async {
    final patientId = _patientId?.trim() ?? '';
    if (patientId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final p = CarelinkPalette.of(dialogContext);
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            _t('Delete record?', 'حذف السجل؟'),
            style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w800),
          ),
          content: Text(
            _t(
              'This action cannot be undone.',
              'لا يمكن التراجع عن هذا الإجراء.',
            ),
            style: TextStyle(color: p.inkMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: Text(_t('Delete', 'حذف')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.deletePatientRecord(
        recordId: record.id,
        patientId: patientId,
      );
      await _loadRecords(silent: true);
      _showMessage(_t('Record deleted.', 'تم حذف السجل.'));
    } catch (error) {
      _showMessage(_cleanError(error), error: true);
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(
        uri,
        mode: url_launcher.LaunchMode.externalApplication,
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Could not open file.', 'تعذر فتح الملف.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        final p = CarelinkPalette.of(context);
        return Directionality(
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: PatientScaffold(
            enabled: false,
            backgroundColor: p.isDark ? p.pageBg : const Color(0xFFF8FAFA),
            appBar: AppBar(
              toolbarHeight: 78,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 16,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _t('My Medical Records', 'سجلاتي الطبية'),
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _t(
                      'Reports, diagnoses, prescriptions and uploads',
                      'التقارير والتشخيصات والوصفات والملفات',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              actions: const [
                PatientHeaderActions(
                  showLanguage: true,
                  showTheme: true,
                  color: Color(0xFF0F766E),
                ),
                SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: () => _loadRecords(silent: true),
                color: AppColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  children: [
                    _summaryRow(p),
                    const SizedBox(height: 14),
                    _uploadCard(p),
                    const SizedBox(height: 14),
                    _searchBar(p),
                    const SizedBox(height: 10),
                    _filterChips(p),
                    const SizedBox(height: 16),
                    _recordsBody(p),
                    const SizedBox(height: 12),
                    _securityCard(p),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryRow(CarelinkPalette p) {
    final items = <(_RecordsFilter, String)>[
      (_RecordsFilter.all, _t('All', 'الكل')),
      (_RecordsFilter.doctors, _t('Doctors', 'الأطباء')),
      (_RecordsFilter.nurses, _t('Nurses', 'الممرضين')),
      (_RecordsFilter.uploads, _t('Uploads', 'ملفاتي')),
    ];
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: _cardDecoration(p, 22),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_count(items[i].$1)}',
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    items[i].$2,
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
            if (i < items.length - 1)
              Container(
                width: 1,
                height: 44,
                color: p.stroke.withValues(alpha: 0.75),
              ),
          ],
        ],
      ),
    );
  }

  Widget _uploadCard(CarelinkPalette p) {
    return PatientPressable(
      onTap: _uploading ? null : _uploadRecord,
      enabled: !_uploading,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: _cardDecoration(p, 20),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.upload_file_rounded,
                color: AppColors.primary,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _t('Upload Medical Record', 'رفع سجل طبي'),
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _t('PDF, images, reports', 'PDF، صور، تقارير'),
                    style: TextStyle(color: p.inkMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (_uploading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: .35),
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(CarelinkPalette p) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _cardDecoration(p, 18, shadow: false),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: p.inkMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              style: TextStyle(color: p.inkDark, fontSize: 13),
              decoration: InputDecoration(
                hintText: _t(
                  'Search medical records...',
                  'ابحث في السجلات الطبية...',
                ),
                hintStyle: TextStyle(color: p.inkMuted, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              icon: const Icon(Icons.close_rounded, size: 16),
              color: p.inkMuted,
            )
          else
            IconButton(
              tooltip: _t('Filters', 'عوامل التصفية'),
              onPressed: _showFilters,
              icon: const Icon(Icons.tune_rounded, size: 20),
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _filterChips(CarelinkPalette p) {
    final items = <(_RecordsFilter, String)>[
      (_RecordsFilter.all, _t('All', 'الكل')),
      (_RecordsFilter.doctors, _t('Doctors', 'الأطباء')),
      (_RecordsFilter.nurses, _t('Nurses', 'الممرضون')),
      (_RecordsFilter.uploads, _t('My Uploads', 'ملفاتي')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            SizedBox(
              height: 40,
              child: ChoiceChip(
                label: Text(items[i].$2),
                selected: _filter == items[i].$1,
                onSelected: (_) => setState(() => _filter = items[i].$1),
                selectedColor: AppColors.primary,
                backgroundColor: p.surface,
                side: BorderSide(
                  color: _filter == items[i].$1 ? AppColors.primary : p.stroke,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                labelStyle: TextStyle(
                  color: _filter == items[i].$1 ? Colors.white : p.inkDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            if (i < items.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  void _showFilters() {
    final items = <(_RecordsFilter, String, IconData)>[
      (_RecordsFilter.all, _t('All', 'الكل'), Icons.folder_outlined),
      (
        _RecordsFilter.doctors,
        _t('Doctors', 'الأطباء'),
        Icons.local_hospital_outlined,
      ),
      (
        _RecordsFilter.nurses,
        _t('Nurses', 'الممرضون'),
        Icons.medical_services_outlined,
      ),
      (
        _RecordsFilter.uploads,
        _t('My Uploads', 'ملفاتي'),
        Icons.upload_file_outlined,
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: CarelinkPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final p = CarelinkPalette.of(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Filter records', 'تصفية السجلات'),
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(item.$3, color: AppColors.primary),
                    title: Text(
                      item.$2,
                      style: TextStyle(
                        color: p.inkDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: _filter == item.$1
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() => _filter = item.$1);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recordsBody(CarelinkPalette p) {
    if (_loading) {
      return Column(
        children: [
          _skeletonBox(p, height: 96),
          const SizedBox(height: 16),
          _skeletonBox(p, height: 96),
          const SizedBox(height: 16),
          _skeletonBox(p, height: 96),
        ],
      );
    }
    if (_error != null) return _errorState(p);
    if (_records.isNotEmpty && _visibleRecords.isEmpty) {
      return _noMatchesState(p);
    }
    if (_visibleRecords.isEmpty) return _emptyState(p);
    return Column(
      children: [
        for (var i = 0; i < _visibleRecords.length; i++) ...[
          TweenAnimationBuilder<double>(
            key: ValueKey(_visibleRecords[i].id),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 220 + (i.clamp(0, 5) * 45)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - value)),
                child: child,
              ),
            ),
            child: _recordCard(p, _visibleRecords[i]),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _recordCard(CarelinkPalette p, _PatientRecord record) {
    final status = _statusStyle(record.status);
    final bool isUpload = record.isPatientUpload;
    return PatientPressable(
      onTap: () => _openRecord(record),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cardDecoration(p, 20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _recordColor(record).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _recordIcon(record),
                color: _recordColor(record),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _recordTitle(record),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isUpload
                            ? Icons.cloud_upload_outlined
                            : Icons.person_outline_rounded,
                        size: 14,
                        color: p.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isUpload
                              ? '${_recordCategory(record)} • ${_t('Uploaded by you', 'تم الرفع بواسطتك')}'
                              : '${_recordCategory(record)} • ${_creatorText(record)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.inkMuted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status.label,
                          style: TextStyle(
                            color: status.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        intl.DateFormat('d MMM y').format(record.createdAt),
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: _t('More', 'المزيد'),
              onPressed: () => _showFileActions(record),
              icon: const Icon(Icons.more_vert_rounded),
              color: p.inkMuted,
              iconSize: 21,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: _cardDecoration(p, 19, shadow: false),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              color: AppColors.primary,
              size: 29,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _t('No medical records yet', 'لا توجد سجلات طبية بعد'),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              'Your reports from doctors and nurses will appear here.',
              'ستظهر تقارير الأطباء والممرضين هنا.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _uploadRecord,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(_t('Upload', 'رفع ملف')),
          ),
        ],
      ),
    );
  }

  Widget _noMatchesState(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: _cardDecoration(p, 19, shadow: false),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: Color(0xFF64748B),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            _t('No matching records', 'لا توجد نتائج مطابقة'),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _query = '';
                _filter = _RecordsFilter.all;
              });
            },
            child: Text(_t('Clear filters', 'مسح عوامل التصفية')),
          ),
        ],
      ),
    );
  }

  Widget _errorState(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: _cardDecoration(p, 19, shadow: false),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(height: 7),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 9),
          TextButton.icon(
            onPressed: _loadRecords,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_t('Try again', 'إعادة المحاولة')),
          ),
        ],
      ),
    );
  }

  Widget _securityCard(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: p.isDark ? .12 : .07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Your privacy matters', 'خصوصيتك تهمنا'),
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _t(
                    'All your medical records are encrypted and shared only with authorized care providers.',
                    'جميع سجلاتك الطبية مشفرة ولا تتم مشاركتها إلا مع مقدمي الرعاية المصرح لهم.',
                  ),
                  style: TextStyle(color: p.inkMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(
    CarelinkPalette p,
    double radius, {
    bool shadow = true,
  }) {
    return BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: p.stroke.withValues(alpha: 0.72)),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: p.cardShadowColor(0.04),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ]
          : null,
    );
  }

  String _creatorText(_PatientRecord record) {
    if (record.isPatientUpload) return _t('You', 'أنت');
    if (record.creatorName.isNotEmpty) return record.creatorName;
    return record.creatorRole == 'nurse'
        ? _t('Nurse', 'ممرض')
        : _t('Doctor', 'طبيب');
  }

  String _recordTitle(_PatientRecord record) {
    if (!_isArabic) return record.title;
    return _localizedMedicalTerm(record.title);
  }

  String _recordCategory(_PatientRecord record) {
    if (!_isArabic) return record.category;
    return _localizedMedicalTerm(record.category);
  }

  String _localizedMedicalTerm(String value) {
    final normalized = value.trim().toLowerCase();
    const terms = <String, String>{
      'medical record': 'سجل طبي',
      'medical report': 'تقرير طبي',
      'visit report': 'تقرير زيارة',
      'nursing report': 'تقرير تمريضي',
      'diagnosis': 'تشخيص',
      'prescription': 'وصفة طبية',
      'lab result': 'نتيجة مختبر',
      'lab results': 'نتائج مختبر',
      'x-ray report': 'تقرير أشعة سينية',
      'mri report': 'تقرير رنين مغناطيسي',
      'ct scan': 'تصوير مقطعي',
      'insurance document': 'وثيقة تأمين',
      'vaccination record': 'سجل تطعيمات',
    };
    return terms[normalized] ?? value;
  }

  IconData _recordIcon(_PatientRecord record) {
    final value = '${record.title} ${record.category}'.toLowerCase();
    if (value.contains('lab') || value.contains('blood')) {
      return Icons.science_outlined;
    }
    if (value.contains('prescription') || value.contains('medication')) {
      return Icons.medication_outlined;
    }
    if (value.contains('x-ray') ||
        value.contains('radiology') ||
        value.contains('scan') ||
        value.contains('mri')) {
      return Icons.document_scanner_outlined;
    }
    if (record.isPatientUpload) return Icons.upload_file_outlined;
    if (record.creatorRole == 'nurse') return Icons.description_outlined;
    return Icons.medical_services_outlined;
  }

  Color _recordColor(_PatientRecord record) {
    if (record.status == _RecordStatus.failed) return const Color(0xFFDC2626);
    final value = '${record.title} ${record.category}'.toLowerCase();
    if (value.contains('prescription') || value.contains('medication')) {
      return const Color(0xFFF59E0B);
    }
    if (value.contains('lab') || value.contains('blood')) {
      return const Color(0xFF8B5CF6);
    }
    if (record.isPatientUpload) return const Color(0xFF8B5CF6);
    if (record.creatorRole == 'nurse') return const Color(0xFF3B82F6);
    return const Color(0xFF22A06B);
  }

  _StatusView _statusStyle(_RecordStatus status) {
    return switch (status) {
      _RecordStatus.ready => _StatusView(
        _t('Ready', 'جاهز'),
        const Color(0xFF15803D),
      ),
      _RecordStatus.processing => _StatusView(
        _t('Under review', 'قيد المراجعة'),
        const Color(0xFF2563EB),
      ),
      _RecordStatus.failed => _StatusView(
        _t('Unavailable', 'غير متاح'),
        const Color(0xFFDC2626),
      ),
      _RecordStatus.archived => _StatusView(
        _t('Archived', 'مؤرشف'),
        const Color(0xFF64748B),
      ),
    };
  }

  Widget _skeletonBox(CarelinkPalette p, {required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: p.stroke.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _PatientRecord {
  const _PatientRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.creatorRole,
    required this.creatorName,
    required this.createdAt,
    required this.status,
    required this.isPatientUpload,
    required this.raw,
    this.fileUrl,
  });

  final String id;
  final String title;
  final String category;
  final String creatorRole;
  final String creatorName;
  final DateTime createdAt;
  final _RecordStatus status;
  final bool isPatientUpload;
  final String? fileUrl;
  final Map<String, dynamic> raw;

  factory _PatientRecord.fromApi(Map<String, dynamic> raw) {
    String text(List<String> keys) {
      for (final key in keys) {
        final value = raw[key]?.toString().trim() ?? '';
        if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
      }
      return '';
    }

    final source = text(['source']).toLowerCase();
    final normalizedRole = text([
      'creatorRole',
      'providerRole',
      'provider_role',
      'createdByRole',
      'role',
    ]).toLowerCase();
    final normalizedRecordType = text([
      'recordType',
      'record_type',
      'report_kind',
    ]).toLowerCase();
    final uploadedBy = text([
      'uploaded_by',
      'uploadedBy',
      'uploadedByRole',
    ]).toLowerCase();
    final isPatientUpload =
        normalizedRole == 'patient' ||
        uploadedBy == 'patient' ||
        source == 'patient_upload' ||
        source == 'patientmedicalfile' ||
        normalizedRecordType == 'patient_upload';
    final title = text(['title', 'diagnosis', 'file_name', 'fileName']);
    final category = text([
      'category',
      'record_type',
      'recordType',
      'report_kind',
    ]);
    final providerName = text([
      'creatorName',
      'providerName',
      'provider_name',
      'createdByName',
      'uploaderName',
    ]);
    final explicitRole = normalizedRole;
    final roleClues = '$title $category $providerName'.toLowerCase();
    final creatorRole = isPatientUpload
        ? 'patient'
        : explicitRole.contains('nurse') ||
              roleClues.contains('nurse') ||
              roleClues.contains('nursing') ||
              roleClues.contains('wound care') ||
              roleClues.contains('vital signs')
        ? 'nurse'
        : 'doctor';
    final createdAt = DateTime.tryParse(
      text([
        'created_at',
        'createdAt',
        'visit_date',
        'uploadDate',
      ]).replaceFirst(' ', 'T'),
    );
    final rawStatus = text([
      'extracted_text_status',
      'extractedTextStatus',
      'aiStatus',
      'status',
    ]).toLowerCase();
    final status = switch (rawStatus) {
      'failed' || 'error' => _RecordStatus.failed,
      'archived' => _RecordStatus.archived,
      'pending' || 'processing' || 'queued' => _RecordStatus.processing,
      _ => _RecordStatus.ready,
    };

    return _PatientRecord(
      id: text(['id', 'recordId']),
      title: title.isEmpty ? 'Medical record' : title,
      category: category.isEmpty
          ? 'Medical record'
          : _displayCategory(category),
      creatorRole: creatorRole,
      creatorName: isPatientUpload ? '' : providerName,
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: isPatientUpload ? status : _RecordStatus.ready,
      isPatientUpload: isPatientUpload,
      fileUrl: text(['fileUrl', 'file_url']),
      raw: raw,
    );
  }

  static String _displayCategory(String value) {
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return 'Medical record';
    return normalized
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class _StatusView {
  const _StatusView(this.label, this.color);

  final String label;
  final Color color;
}

import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/shared/widgets/patient_app_bar.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:url_launcher/url_launcher.dart';

/// Read-only visit report detail.
class MedicalRecordDetailsScreen extends StatefulWidget {
  const MedicalRecordDetailsScreen({
    super.key,
    required this.recordId,
    required this.patientUserId,
    this.requesterRole = 'patient',
  });

  final String recordId;
  final String patientUserId;
  final String requesterRole;

  @override
  State<MedicalRecordDetailsScreen> createState() =>
      _MedicalRecordDetailsScreenState();
}

class _MedicalRecordDetailsScreenState
    extends State<MedicalRecordDetailsScreen> {
  final _service = MedicalRecordService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await _service.getVisitReportById(
        widget.recordId,
        requesterUserId: widget.patientUserId,
        requesterRole: widget.requesterRole,
      );
      if (!mounted) return;
      setState(() {
        _data = m;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.userMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return PatientScaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(
        title: (_data?['title']?.toString().trim().isNotEmpty ?? false)
            ? _data!['title'].toString()
            : localeController.isArabic
            ? 'تفاصيل السجل الطبي'
            : 'Medical record details',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _buildBody(p, _data ?? {}),
    );
  }

  Widget _buildBody(CarelinkPalette p, Map<String, dynamic> m) {
    final provider = (m['creatorName'] ?? m['providerName'] ?? '—').toString();
    final visitDate =
        (m['createdAt'] ?? m['visit_date'] ?? m['created_at'] ?? '—')
            .toString();
    final normalizedTitle = (m['title'] ?? '').toString();
    final normalizedDescription = (m['description'] ?? '').toString();
    final normalizedSummary = (m['aiSummary'] ?? '').toString();
    final recordType = (m['recordType'] ?? '').toString();
    final creatorRole = (m['creatorRole'] ?? '').toString();
    final fileUrl = (m['fileUrl'] ?? '').toString().trim();
    final dx = (m['diagnosis'] ?? '').toString();
    final plan = (m['treatment_plan'] ?? '').toString();
    final rec = (m['recommendations'] ?? '').toString();
    final meds = (m['medications'] ?? '').toString();
    final allergies = (m['allergies'] ?? '').toString();
    final notes = (m['notes'] ?? '').toString();
    final vitals = m['vital_signs'];
    final fu =
        m['follow_up_required'] == true ||
        m['follow_up_required'] == 1 ||
        m['follow_up_required'] == '1';
    final fuDate = (m['follow_up_date'] ?? '').toString();

    List<String> parseBullets(String text) {
      if (text.isEmpty) return [];
      if (text.contains('\n')) {
        return text
            .split('\n')
            .map((e) => e.trim().replaceAll(RegExp(r'^[-•*]\s*'), ''))
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (text.contains('. ')) {
        return text
            .split('. ')
            .map((e) => e.trim().replaceAll(RegExp(r'^[-•*]\s*'), ''))
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (text.contains(',')) {
        return text
            .split(',')
            .map((e) => e.trim().replaceAll(RegExp(r'^[-•*]\s*'), ''))
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [text.trim().replaceAll(RegExp(r'^[-•*]\s*'), '')];
    }

    Widget buildSection({
      required String title,
      required String content,
      required IconData icon,
      bool bulletPoints = false,
    }) {
      if (content.trim().isEmpty) return const SizedBox.shrink();

      Widget bodyWidget;
      if (bulletPoints) {
        final items = parseBullets(content);
        bodyWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e,
                          style: TextStyle(
                            color: p.inkDark,
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      } else {
        bodyWidget = Text(
          content,
          style: TextStyle(
            color: p.inkDark,
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.isDark ? p.surface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.stroke.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: p.cardShadowColor(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: p.inkDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            bodyWidget,
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Card
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.isDark ? p.surface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.stroke.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: p.cardShadowColor(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medical_information_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.trim().isEmpty || provider == '—'
                          ? _creatorRoleLabel(creatorRole)
                          : provider,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: p.inkDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recordType.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: p.inkMuted),
                        const SizedBox(width: 4),
                        Text(
                          visitDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: p.inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          localeController.isArabic ? 'مكتمل' : 'Completed',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // AI Summary
        if (normalizedSummary.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localeController.isArabic ? 'ملخص الذكاء الاصطناعي' : 'AI Summary',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6D28D9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  normalizedSummary,
                  style: const TextStyle(
                    color: Color(0xFF4C1D95),
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Sections
        if (normalizedDescription.isNotEmpty)
          buildSection(
            title: normalizedTitle.isEmpty
                ? (localeController.isArabic ? 'الشكوى الرئيسية' : 'Chief Complaint')
                : normalizedTitle,
            content: normalizedDescription,
            icon: Icons.speaker_notes_rounded,
          ),
        if (vitals != null && vitals.toString().trim().isNotEmpty)
          buildSection(
            title: localeController.isArabic ? 'العلامات الحيوية' : 'Vital Signs',
            content: vitals.toString(),
            icon: Icons.monitor_heart_rounded,
            bulletPoints: true,
          ),
        buildSection(
          title: localeController.isArabic ? 'التشخيص' : 'Diagnosis',
          content: dx,
          icon: Icons.health_and_safety_rounded,
        ),
        buildSection(
          title: localeController.isArabic ? 'الأعراض' : 'Symptoms',
          content: '', // There is no direct "symptoms" field, but we add it if available in future
          icon: Icons.sick_rounded,
          bulletPoints: true,
        ),
        buildSection(
          title: localeController.isArabic ? 'خطة العلاج' : 'Treatment Plan',
          content: plan,
          icon: Icons.healing_rounded,
          bulletPoints: true,
        ),
        buildSection(
          title: localeController.isArabic ? 'الأدوية' : 'Medications',
          content: meds,
          icon: Icons.medication_rounded,
          bulletPoints: true,
        ),
        buildSection(
          title: localeController.isArabic ? 'إرشادات التمريض' : 'Nursing / Recommendations',
          content: rec,
          icon: Icons.local_hospital_rounded,
          bulletPoints: true,
        ),
        buildSection(
          title: localeController.isArabic ? 'الحساسية' : 'Allergies',
          content: allergies,
          icon: Icons.warning_rounded,
          bulletPoints: true,
        ),
        buildSection(
          title: localeController.isArabic ? 'ملاحظات' : 'Notes',
          content: notes,
          icon: Icons.note_alt_rounded,
        ),
        if (fu)
          buildSection(
            title: localeController.isArabic ? 'المتابعة' : 'Follow-up',
            content: fuDate.isNotEmpty ? 'Required by $fuDate' : 'Required',
            icon: Icons.event_repeat_rounded,
          ),

        // Attachments Card
        if (fileUrl.isNotEmpty || creatorRole.trim().toLowerCase() == 'patient')
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.isDark ? p.surface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.stroke.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: p.cardShadowColor(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.attachment_rounded,
                        size: 18,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localeController.isArabic ? 'المرفقات' : 'Attachments',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: p.inkDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (fileUrl.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => _openFile(fileUrl),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(
                        localeController.isArabic
                            ? 'فتح الملف المرفق'
                            : 'Open attached file',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                if (creatorRole.trim().toLowerCase() == 'patient') ...[
                  if (fileUrl.isNotEmpty) const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _deleteUpload,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(
                        localeController.isArabic
                            ? 'حذف الملف'
                            : 'Delete my upload',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _creatorRoleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'doctor':
        return localeController.isArabic ? 'طبيب' : 'Doctor';
      case 'nurse':
        return localeController.isArabic ? 'ممرض' : 'Nurse';
      case 'patient':
        return localeController.isArabic ? 'المريض' : 'Patient';
      default:
        return localeController.isArabic ? 'مقدم الرعاية' : 'Care provider';
    }
  }

  Future<void> _openFile(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localeController.isArabic
                ? 'تعذر فتح الملف.'
                : 'Could not open this file.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteUpload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localeController.isArabic ? 'حذف الملف؟' : 'Delete upload?',
        ),
        content: Text(
          localeController.isArabic
              ? 'لا يمكن التراجع عن هذا الإجراء.'
              : 'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localeController.isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localeController.isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deletePatientRecord(
        recordId: widget.recordId,
        patientId: widget.patientUserId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.userMessage(error))));
    }
  }
}

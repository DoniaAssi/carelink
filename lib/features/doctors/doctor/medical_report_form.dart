import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../services/doctor_service.dart';

class MedicalReportFormScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic>? requestData;

  const MedicalReportFormScreen({
    super.key,
    required this.requestId,
    this.requestData,
  });

  @override
  State<MedicalReportFormScreen> createState() =>
      _MedicalReportFormScreenState();
}

class _MedicalReportFormScreenState extends State<MedicalReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symptomsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _medicationController = TextEditingController();
  final _followUpDateController = TextEditingController();
  final _followUpNotesController = TextEditingController();
  final _additionalNotesController = TextEditingController();
  final _doctorService = DoctorService();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final reason = (widget.requestData?['reasonForVisit'] ?? '').toString();
    if (reason.isNotEmpty) _symptomsController.text = reason;
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _medicationController.dispose();
    _followUpDateController.dispose();
    _followUpNotesController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickFollowUpDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    _followUpDateController.text =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'doctor_report_draft_${widget.requestId}';
    await prefs.setString(
      key,
      [
        _symptomsController.text,
        _diagnosisController.text,
        _treatmentController.text,
        _medicationController.text,
        _followUpDateController.text,
        _followUpNotesController.text,
        _additionalNotesController.text,
      ].join('\n---\n'),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft saved'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    final status = (widget.requestData?['status'] ?? '')
        .toString()
        .toLowerCase();
    if (status != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Medical reports can be submitted only after the visit is completed.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId');

      if (doctorId == null || doctorId.isEmpty) {
        throw Exception('Doctor ID not found. Please login again.');
      }

      final notes = <String>[
        if (_symptomsController.text.trim().isNotEmpty)
          'Symptoms / Patient Condition:\n${_symptomsController.text.trim()}',
        if (_treatmentController.text.trim().isNotEmpty)
          'Treatment / Plan:\n${_treatmentController.text.trim()}',
        if (_followUpDateController.text.trim().isNotEmpty)
          'Follow-up Date:\n${_followUpDateController.text.trim()}',
        if (_followUpNotesController.text.trim().isNotEmpty)
          'Follow-up Notes:\n${_followUpNotesController.text.trim()}',
        if (_additionalNotesController.text.trim().isNotEmpty)
          'Additional Notes:\n${_additionalNotesController.text.trim()}',
      ].join('\n\n');

      final response = await _doctorService.submitMedicalReport(
        widget.requestId,
        doctorId,
        diagnosis: _diagnosisController.text.trim(),
        notes: notes,
        prescription: _medicationController.text.trim(),
      );

      if (response['success'] == true) {
        await prefs.remove('doctor_report_draft_${widget.requestId}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical report submitted successfully'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(response['error'] ?? 'Failed to submit report');
      }
    } catch (e) {
      debugPrint('Error submitting report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit report. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reviewReport() async {
    if (!_formKey.currentState!.validate()) return;

    final patientName = (widget.requestData?['patientName'] ?? 'Patient')
        .toString();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Report'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _reviewLine('Patient', patientName),
              _reviewLine('Diagnosis', _diagnosisController.text.trim()),
              _reviewLine('Treatment', _treatmentController.text.trim()),
              if (_medicationController.text.trim().isNotEmpty)
                _reviewLine('Medication', _medicationController.text.trim()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Edit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (submit == true) await _submitReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 26),
                    _buildSteps(),
                    const SizedBox(height: 24),
                    _buildPatientCard(),
                    const SizedBox(height: 12),
                    _buildSectionCard(
                      icon: Icons.assignment_outlined,
                      title: 'Symptoms / Patient Condition',
                      child: _reportField(
                        _symptomsController,
                        'Describe the symptoms and current condition...',
                        maxLines: 3,
                        maxLength: 500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSectionCard(
                      icon: Icons.medical_services_outlined,
                      title: 'Diagnosis & Treatment',
                      child: Column(
                        children: [
                          _reportField(
                            _diagnosisController,
                            'Enter your diagnosis...',
                            label: 'Diagnosis',
                            maxLines: 3,
                            maxLength: 500,
                            requiredField: true,
                          ),
                          const SizedBox(height: 14),
                          _reportField(
                            _treatmentController,
                            'Describe the treatment plan...',
                            label: 'Treatment / Plan',
                            maxLines: 3,
                            maxLength: 500,
                            requiredField: true,
                          ),
                          const SizedBox(height: 14),
                          _reportField(
                            _medicationController,
                            'Enter medication name, dose, frequency...',
                            label: 'Prescribed Medication (Optional)',
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFollowUpCard(),
                    const SizedBox(height: 24),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _circleButton(Icons.arrow_back_rounded, () => Navigator.pop(context)),
        const Expanded(
          child: Text(
            'Create Medical Report',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _saveDraft,
          icon: const Icon(Icons.save_outlined, size: 19),
          label: const Text('Save Draft'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFEAF0EF)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon, color: const Color(0xFF151823), size: 28),
        ),
      ),
    );
  }

  Widget _buildSteps() {
    final steps = [
      'Report Details',
      'Diagnosis & Treatment',
      'Follow-up & Notes',
      'Review & Submit',
    ];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: i == 0
                      ? AppColors.primary
                      : const Color(0xFFF0F4F3),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i == 0 ? Colors.white : const Color(0xFF59646E),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps[i],
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: i == 0 ? AppColors.primary : const Color(0xFF59646E),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (i != steps.length - 1)
            Container(
              width: 36,
              height: 2,
              margin: const EdgeInsets.only(bottom: 28),
              color: i == 0 ? AppColors.primary : const Color(0xFFE2E8E6),
            ),
        ],
      ],
    );
  }

  Widget _buildPatientCard() {
    final data = widget.requestData ?? {};
    final patientName = (data['patientName'] ?? 'Patient').toString();
    final patientEmail = (data['patientEmail'] ?? '').toString();
    final serviceType = (data['serviceType'] ?? 'Medical Visit').toString();
    final status = (data['status'] ?? 'Confirmed').toString();
    final scheduledAt = data['scheduledAt'];

    return _buildSectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Patient & Visit Information',
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: const Color(0xFFE7F7F2),
                child: Text(
                  patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patientEmail.isEmpty
                          ? 'Request ID: ${widget.requestId}'
                          : patientEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF68727D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${widget.requestId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _infoBox(
                  Icons.calendar_today_outlined,
                  'Visit Date',
                  _formatDate(scheduledAt),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoBox(
                  Icons.access_time_rounded,
                  'Visit Time',
                  _formatTime(scheduledAt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoBox(Icons.home_work_outlined, 'Service Type', serviceType),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard() {
    return _buildSectionCard(
      icon: Icons.favorite_border_rounded,
      title: 'Follow-up & Notes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _followUpDateController,
                  readOnly: true,
                  onTap: _pickFollowUpDate,
                  decoration: _fieldDecoration(
                    'Select date',
                    label: 'Follow-up Date (Optional)',
                    suffixIcon: Icons.calendar_month_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _reportField(
                  _followUpNotesController,
                  'e.g. Recheck after 5 days...',
                  label: 'Follow-up Notes',
                  maxLines: 3,
                  maxLength: 200,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _reportField(
            _additionalNotesController,
            'Any additional notes or recommendations...',
            label: 'Additional Notes (Optional)',
            maxLines: 3,
            maxLength: 500,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEAF0EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F7F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _reportField(
    TextEditingController controller,
    String hint, {
    String? label,
    int maxLines = 1,
    int? maxLength,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: _fieldDecoration(hint, label: label),
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
    );
  }

  InputDecoration _fieldDecoration(
    String hint, {
    String? label,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      counterStyle: const TextStyle(color: Color(0xFF68727D), fontSize: 11),
      suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5ECEA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5ECEA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _infoBox(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5ECEA)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF68727D),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final lower = status.toLowerCase();
    final color = lower == 'completed' ? AppColors.info : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        lower.isEmpty ? 'Confirmed' : status,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: Color(0xFFB8D8D3)),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _reviewReport,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: const Text('Next: Review Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic value) {
    if (value is! String || value.isEmpty) return 'Not scheduled';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _reviewLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic value) {
    if (value is! String || value.isEmpty) return '--:--';
    final date = DateTime.tryParse(value);
    if (date == null) return '--:--';
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

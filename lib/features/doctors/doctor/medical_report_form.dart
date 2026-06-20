import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../services/doctor_service.dart';
import 'doctor_ui_constants.dart';

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
  int _currentStep = 0;
  String _patientCondition = 'Improved';

  static const _primary = Color(0xFF0F8B8D);
  static const _ink = Color(0xFF101828);
  static const _muted = Color(0xFF667085);
  static const _line = Color(0xFFDDE6E3);

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

      final reportData = {
        'requestId': widget.requestId,
        'doctorId': doctorId,
        'diagnosis': _diagnosisController.text.trim(),
        'notes': notes,
        'prescription': _medicationController.text.trim(),
        'isInitialDiagnosis': false,
      };
      debugPrint('Submitting visit report...');
      debugPrint(reportData.toString());

      final response = await _doctorService.submitMedicalReport(
        widget.requestId,
        doctorId,
        diagnosis: reportData['diagnosis'] as String,
        notes: reportData['notes'] as String,
        prescription: reportData['prescription'] as String,
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

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 4) {
      setState(() => _currentStep += 1);
      return;
    }
    _submitReport();
  }

  void _previousStep() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _currentStep -= 1);
  }

  bool _validateCurrentStep() {
    if (_currentStep == 2 && _diagnosisController.text.trim().isEmpty) {
      _showValidationMessage('Please enter the diagnosis.');
      return false;
    }
    if (_currentStep == 2 && _treatmentController.text.trim().isEmpty) {
      _showValidationMessage('Please enter the procedures performed.');
      return false;
    }
    return true;
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DoctorUiConstants.doctorBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 26),
                    _buildSteps(),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey(_currentStep),
                        child: _buildCurrentStep(),
                      ),
                    ),
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
            'Create Visit Report',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _saveDraft,
          icon: const Icon(Icons.save_outlined, size: 19),
          label: const Text('Save Draft'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
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
          width: 48,
          height: 48,
          child: Icon(icon, color: _ink, size: 28),
        ),
      ),
    );
  }

  Widget _buildSteps() {
    final steps = [
      'Visit Details',
      'Patient\nCondition',
      'Procedures &\nMedications',
      'Follow-up &\nNext Visit',
      'Review &\nSubmit',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: i == _currentStep ? _primary : Colors.white,
                    shape: BoxShape.circle,
                    border: i == _currentStep
                        ? null
                        : Border.all(color: _line, width: 1.3),
                    boxShadow: i == _currentStep
                        ? [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.22),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i == _currentStep ? Colors.white : _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  steps[i],
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: i == _currentStep ? _primary : _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (i != steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 20, left: 2, right: 2),
                color: i < _currentStep ? _primary : _line,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildVisitDetailsStep();
      case 1:
        return _buildPatientConditionStep();
      case 2:
        return _buildProceduresStep();
      case 3:
        return _buildFollowUpStep();
      default:
        return _buildReviewStep();
    }
  }

  Widget _buildVisitDetailsStep() {
    final data = widget.requestData ?? {};
    final scheduledAt = data['scheduledAt'];
    final visitNumber = _firstText([
      data['visitNumber'],
      data['currentVisit'],
      data['visitCount'],
    ]);
    final requiredVisits = _firstText([
      data['requiredVisits'],
      data['totalVisits'],
      data['numberOfVisits'],
    ]);
    final visitLabel = visitNumber.isEmpty && requiredVisits.isEmpty
        ? '--'
        : '${visitNumber.isEmpty ? '-' : visitNumber} / ${requiredVisits.isEmpty ? '-' : requiredVisits}';

    return _buildSectionCard(
      icon: Icons.calendar_month_outlined,
      title: 'Visit Information',
      child: _infoPanel(
        children: [
          _visitInfoRow(
            Icons.calendar_today_outlined,
            'Visit Number',
            visitLabel,
          ),
          _panelDivider(),
          _visitInfoRow(
            Icons.calendar_today_outlined,
            'Visit Date',
            _formatDate(scheduledAt),
          ),
          _panelDivider(),
          _visitInfoRow(
            Icons.access_time_rounded,
            'Visit Time',
            _formatTime(scheduledAt),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientConditionStep() {
    return _buildSectionCard(
      stepNumber: 1,
      icon: Icons.person_outline_rounded,
      title: 'Patient Condition',
      subtitle: "How is the patient's condition today?",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 560;
              final cards = [
                _conditionCard('Improved', Icons.trending_up_rounded),
                _conditionCard('No Change', Icons.remove_rounded),
                _conditionCard('Worsened', Icons.trending_down_rounded),
              ];
              if (isNarrow) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i != cards.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(width: 16),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          const Text(
            'Additional Notes (Optional)',
            style: TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _reportField(
            _additionalNotesController,
            'e.g., Fever gone, but cough still present.',
            maxLines: 4,
            maxLength: 500,
          ),
        ],
      ),
    );
  }

  Widget _buildProceduresStep() {
    return Column(
      children: [
        _buildSectionCard(
          stepNumber: 2,
          icon: Icons.assignment_outlined,
          title: 'Diagnosis',
          subtitle: 'What is the clinical diagnosis?',
          child: _reportField(
            _diagnosisController,
            'Enter diagnosis...',
            maxLines: 4,
            maxLength: 500,
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          stepNumber: 2,
          icon: Icons.medical_services_outlined,
          title: 'Procedures Performed',
          subtitle: 'What was done in this session?',
          child: _reportField(
            _treatmentController,
            'e.g., Performed physical therapy session and stretching exercises.',
            maxLines: 4,
            maxLength: 500,
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          stepNumber: 3,
          icon: Icons.medication_outlined,
          title: 'Medications Given',
          subtitle: 'What medications were given?',
          child: _reportField(
            _medicationController,
            'e.g., Paracetamol 500 mg or Ibuprofen 400 mg.',
            maxLines: 4,
            maxLength: 500,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowUpStep() {
    return Column(
      children: [
        _buildSectionCard(
          stepNumber: 4,
          icon: Icons.note_alt_outlined,
          title: 'Follow-up Notes',
          subtitle: 'What instructions or advice were given?',
          child: _reportField(
            _followUpNotesController,
            'e.g., Continue medication, drink fluids, and get enough rest.',
            maxLines: 4,
            maxLength: 500,
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          stepNumber: 5,
          icon: Icons.calendar_month_outlined,
          title: 'Next Appointment',
          subtitle: 'When is the next visit?',
          child: TextFormField(
            controller: _followUpDateController,
            readOnly: true,
            onTap: _pickFollowUpDate,
            decoration: _fieldDecoration(
              'Select next appointment date',
              suffixIcon: Icons.calendar_month_outlined,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final data = widget.requestData ?? {};
    return Column(
      children: [
        _summaryCard('Visit Information', [
          _summaryLine('Visit Date', _formatDate(data['scheduledAt'])),
          _summaryLine('Visit Time', _formatTime(data['scheduledAt'])),
        ]),
        const SizedBox(height: 14),
        _summaryCard('Patient Condition', [
          _summaryLine('Condition', _patientCondition),
          _summaryLine(
            'Additional Notes',
            _additionalNotesController.text.trim(),
          ),
        ]),
        const SizedBox(height: 14),
        _summaryCard('Procedures & Medications', [
          _summaryLine('Diagnosis', _diagnosisController.text.trim()),
          _summaryLine(
            'Procedures Performed',
            _treatmentController.text.trim(),
          ),
          _summaryLine('Medications Given', _medicationController.text.trim()),
        ]),
        const SizedBox(height: 14),
        _summaryCard('Follow-up & Next Visit', [
          _summaryLine('Follow-up Notes', _followUpNotesController.text.trim()),
          _summaryLine('Next Appointment', _followUpDateController.text.trim()),
        ]),
      ],
    );
  }

  Widget _conditionCard(String label, IconData icon) {
    final selected = _patientCondition == label;
    final isWorsened = label == 'Worsened';
    final color = isWorsened ? const Color(0xFFF27474) : _primary;

    return InkWell(
      onTap: () => setState(() => _patientCondition = label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : _line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.35)
                    : const Color(0xFFE2E8EF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF8A96A3),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : const Color(0xFF98A2B3),
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    int? stepNumber,
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAF0EF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stepNumber != null) ...[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _primary,
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F7F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _primary, size: 25),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _infoPanel({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(children: children),
    );
  }

  Widget _visitInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 24),
          const SizedBox(width: 22),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelDivider() {
    return const Divider(height: 1, color: _line, indent: 46);
  }

  Widget _reportField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: _fieldDecoration(hint),
    );
  }

  InputDecoration _fieldDecoration(String hint, {IconData? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      counterStyle: const TextStyle(color: _muted, fontSize: 11),
      suffixIcon: suffixIcon == null
          ? null
          : Icon(suffixIcon, color: _primary, size: 22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _summaryCard(String title, List<Widget> children) {
    return _buildSectionCard(
      icon: Icons.fact_check_outlined,
      title: title,
      child: Column(children: children),
    );
  }

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == 4;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _previousStep,
            icon: Icon(
              isFirst ? Icons.close_rounded : Icons.arrow_back_rounded,
            ),
            label: Text(isFirst ? 'Cancel' : 'Previous'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFB8D8D3)),
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
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _nextStep,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  ),
            label: Text(isLast ? 'Submit Report' : 'Next'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
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
    return '${date.day}/${date.month}/${date.year}';
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

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }
}

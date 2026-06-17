import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../services/doctor_service.dart';

class InitialDiagnosisReportScreen extends StatefulWidget {
  const InitialDiagnosisReportScreen({
    super.key,
    required this.requestId,
    this.requestData,
  });

  final String requestId;
  final Map<String, dynamic>? requestData;

  @override
  State<InitialDiagnosisReportScreen> createState() =>
      _InitialDiagnosisReportScreenState();
}

class _InitialDiagnosisReportScreenState
    extends State<InitialDiagnosisReportScreen> {
  final _doctorService = DoctorService();
  final _stepOneKey = GlobalKey<FormState>();
  final _stepTwoKey = GlobalKey<FormState>();
  final _stepThreeKey = GlobalKey<FormState>();
  final _pageController = PageController();
  final _chiefComplaintController = TextEditingController();
  final _symptomsController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentPlanController = TextEditingController();
  final _customVisitsController = TextEditingController();

  String _requiredVisits = 'not_determined';
  int _currentStep = 0;
  bool _isSubmitting = false;

  static const _pageColor = Color(0xFFF5F5F5);
  static const _primary = Color(0xFF0F8B8D);
  static const _ink = Color(0xFF101828);
  static const _muted = Color(0xFF667085);

  @override
  void initState() {
    super.initState();
    final reason = _text(widget.requestData?['reasonForVisit']);
    if (reason != null) _chiefComplaintController.text = reason;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _chiefComplaintController.dispose();
    _symptomsController.dispose();
    _medicalHistoryController.dispose();
    _diagnosisController.dispose();
    _treatmentPlanController.dispose();
    _customVisitsController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'doctor_initial_diagnosis_draft_${widget.requestId}',
      [
        _chiefComplaintController.text,
        _symptomsController.text,
        _medicalHistoryController.text,
        _diagnosisController.text,
        _treatmentPlanController.text,
        _requiredVisits,
        _customVisitsController.text,
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

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        return _stepOneKey.currentState?.validate() ?? false;
      case 1:
        return _stepTwoKey.currentState?.validate() ?? true;
      case 2:
        return _stepThreeKey.currentState?.validate() ?? false;
      default:
        return true;
    }
  }

  int? _firstInvalidStep() {
    if (_chiefComplaintController.text.trim().isEmpty ||
        _symptomsController.text.trim().isEmpty) {
      return 0;
    }
    if (_diagnosisController.text.trim().isEmpty ||
        _treatmentPlanController.text.trim().isEmpty ||
        (_requiredVisits == 'custom' &&
            _customVisitsController.text.trim().isEmpty)) {
      return 2;
    }
    return null;
  }

  void _goToStep(int step) {
    final nextStep = step.clamp(0, 3).toInt();
    setState(() => _currentStep = nextStep);
    _pageController.animateToPage(
      nextStep,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextStep() {
    if (!_validateStep(_currentStep)) return;
    _goToStep(_currentStep + 1);
  }

  void _previousStep() => _goToStep(_currentStep - 1);

  Future<void> _submit() async {
    final invalidStep = _firstInvalidStep();
    if (invalidStep != null) {
      _goToStep(invalidStep);
      return;
    }

    final requiredVisits = _requiredVisits == 'custom'
        ? _customVisitsController.text.trim()
        : _requiredVisits;

    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      if (doctorId.isEmpty) throw Exception('Doctor ID not found');

      final response = await _doctorService.submitMedicalReport(
        widget.requestId,
        doctorId,
        isInitialDiagnosis: true,
        chiefComplaint: _chiefComplaintController.text.trim(),
        symptoms: _symptomsController.text.trim(),
        medicalHistory: _medicalHistoryController.text.trim(),
        diagnosis: _diagnosisController.text.trim(),
        treatmentPlan: _treatmentPlanController.text.trim(),
        notes: _treatmentPlanController.text.trim(),
        requiredVisits: requiredVisits,
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to submit report');
      }

      await prefs.remove('doctor_initial_diagnosis_draft_${widget.requestId}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Initial diagnosis report submitted'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 28),
                  _steps(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _patientInfoStep(),
                        _medicalHistoryStep(),
                        _diagnosisPlanStep(),
                        _reviewStep(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _wizardActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepScroll(List<Widget> children) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _patientInfoStep() {
    return Form(
      key: _stepOneKey,
      child: _stepScroll([
        _patientInfoCard(),
        const SizedBox(height: 10),
        _section(
          icon: Icons.feed_outlined,
          title: 'Chief Complaint',
          subtitle: "What is the main reason for the patient's visit?",
          child: _textArea(
            _chiefComplaintController,
            'Enter chief complaint...',
            maxLength: 500,
            required: true,
          ),
        ),
        _section(
          icon: Icons.monitor_heart_outlined,
          title: 'Symptoms',
          subtitle: "List and describe the patient's current symptoms.",
          child: _textArea(
            _symptomsController,
            'Enter symptoms...',
            maxLength: 1000,
            required: true,
          ),
        ),
      ]),
    );
  }

  Widget _medicalHistoryStep() {
    return Form(
      key: _stepTwoKey,
      child: _stepScroll([
        _section(
          icon: Icons.medical_information_outlined,
          title: 'Medical History',
          subtitle: 'Relevant past medical history.',
          child: _textArea(
            _medicalHistoryController,
            'Enter medical history...',
            maxLength: 1000,
          ),
        ),
      ]),
    );
  }

  Widget _diagnosisPlanStep() {
    return Form(
      key: _stepThreeKey,
      child: _stepScroll([
        _section(
          icon: Icons.assignment_outlined,
          title: 'Diagnosis',
          subtitle: 'Enter the diagnosis for the patient.',
          child: _textArea(
            _diagnosisController,
            'Enter diagnosis...',
            maxLength: 500,
            required: true,
          ),
        ),
        _section(
          icon: Icons.event_note_outlined,
          title: 'Treatment Plan',
          subtitle: 'Outline the treatment plan and recommended interventions.',
          child: _textArea(
            _treatmentPlanController,
            'Enter treatment plan...',
            maxLength: 1000,
            required: true,
          ),
        ),
        _visitsCard(),
      ]),
    );
  }

  Widget _reviewStep() {
    final data = widget.requestData ?? {};
    final patientName = _text(data['patientName']) ?? 'Patient';
    final email = _text(data['patientEmail']) ?? '';
    final serviceType = _text(data['serviceType']) ?? 'Medical Visit';
    final scheduledAt = _text(data['scheduledAt']);

    return _stepScroll([
      _section(
        icon: Icons.fact_check_outlined,
        title: 'Review & Submit',
        subtitle: 'Confirm the initial diagnosis details before submitting.',
        child: Column(
          children: [
            _summaryRow('Patient Name', patientName),
            _summaryRow('Email', email),
            _summaryRow('Request ID', '#${widget.requestId}'),
            _summaryRow('Visit Date', _formatDate(scheduledAt)),
            _summaryRow('Visit Time', _formatTime(scheduledAt)),
            _summaryRow('Service Type', serviceType),
            const Divider(height: 28),
            _summaryBlock(
              'Chief Complaint',
              _chiefComplaintController.text.trim(),
            ),
            _summaryBlock('Symptoms', _symptomsController.text.trim()),
            _summaryBlock(
              'Medical History',
              _medicalHistoryController.text.trim().isEmpty
                  ? 'Not provided'
                  : _medicalHistoryController.text.trim(),
            ),
            _summaryBlock('Diagnosis', _diagnosisController.text.trim()),
            _summaryBlock(
              'Treatment Plan',
              _treatmentPlanController.text.trim(),
            ),
            _summaryRow('Required Visits', _requiredVisitsLabel()),
          ],
        ),
      ),
    ]);
  }

  Widget _header() {
    return Row(
      children: [
        _iconButton(Icons.arrow_back_rounded, () => Navigator.pop(context)),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            children: [
              Text(
                'Initial Diagnosis Report',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Create the initial diagnosis and treatment plan for the patient.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _saveDraft,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Save Draft'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFDDE7E5)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _steps() {
    final steps = [
      'Patient Info',
      'Medical History',
      'Diagnosis & Plan',
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
                  backgroundColor: i <= _currentStep
                      ? _primary
                      : const Color(0xFFF0F4F3),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i <= _currentStep ? Colors.white : _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  steps[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: i == _currentStep ? _primary : _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (i != steps.length - 1)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(bottom: 30),
                color: i < _currentStep ? _primary : const Color(0xFFDDE7E5),
              ),
            ),
        ],
      ],
    );
  }

  Widget _patientInfoCard() {
    final data = widget.requestData ?? {};
    final patientName = _text(data['patientName']) ?? 'Patient';
    final email = _text(data['patientEmail']) ?? '';
    final serviceType = _text(data['serviceType']) ?? 'Medical Visit';
    final status = _text(data['status']) ?? 'completed';
    final scheduledAt = _text(data['scheduledAt']);

    return _section(
      icon: Icons.person_rounded,
      title: 'Patient & Visit Information',
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: const Color(0xFFE7F7F2),
                child: Text(
                  patientName.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: _primary,
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
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${widget.requestId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primary,
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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final boxes = [
                _infoBox(
                  Icons.calendar_today_outlined,
                  'Visit Date',
                  _formatDate(scheduledAt),
                ),
                _infoBox(
                  Icons.access_time_rounded,
                  'Visit Time',
                  _formatTime(scheduledAt),
                ),
                _infoBox(Icons.home_work_outlined, 'Service Type', serviceType),
              ];
              return compact
                  ? Column(
                      children: [
                        for (final box in boxes) ...[
                          box,
                          if (box != boxes.last) const SizedBox(height: 10),
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        for (final box in boxes) ...[
                          Expanded(child: box),
                          if (box != boxes.last) const SizedBox(width: 14),
                        ],
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE7E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F7F2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: _primary, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _textArea(
    TextEditingController controller,
    String hint, {
    int maxLength = 500,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      minLines: 3,
      maxLines: 5,
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        counterStyle: const TextStyle(color: _muted, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE7E5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE7E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _visitsCard() {
    return _section(
      icon: Icons.event_available_outlined,
      title: 'Estimated Follow-up Visits',
      subtitle: 'Estimated number of follow-up visits or duration of care.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final options = [
                _visitOption(
                  'not_determined',
                  'Not determined yet',
                  'Will be decided later',
                ),
                _visitOption('3', '3 Visits', 'Estimated'),
                _visitOption('5', '5 Visits', 'Estimated'),
                _visitOption('10_plus', '10+ Visits', 'Estimated'),
                _customVisitOption(),
              ];
              return compact
                  ? Column(
                      children: [
                        for (final option in options) ...[
                          option,
                          if (option != options.last)
                            const SizedBox(height: 10),
                        ],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final option in options) ...[
                          Expanded(child: option),
                          if (option != options.last) const SizedBox(width: 10),
                        ],
                      ],
                    );
            },
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _primary, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can update the number of visits as the treatment progresses.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _visitOption(String value, String title, String subtitle) {
    final selected = _requiredVisits == value;
    return InkWell(
      onTap: () => setState(() => _requiredVisits = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 74),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _primary : const Color(0xFFDDE7E5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? _primary : _muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customVisitOption() {
    final selected = _requiredVisits == 'custom';
    return InkWell(
      onTap: () => setState(() => _requiredVisits = 'custom'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 74),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _primary : const Color(0xFFDDE7E5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter number',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customVisitsController,
                    keyboardType: TextInputType.number,
                    enabled: selected,
                    validator: _requiredVisits == 'custom'
                        ? (value) => value == null || value.trim().isEmpty
                              ? 'Required'
                              : null
                        : null,
                    decoration: InputDecoration(
                      hintText: 'e.g. 8',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'visits',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wizardActions() {
    final isLastStep = _currentStep == 3;
    final primaryLabel = isLastStep ? 'Submit' : 'Next';
    final primaryIcon = isLastStep
        ? Icons.check_rounded
        : Icons.arrow_forward_rounded;

    return Row(
      children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : _previousStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFDDE7E5)),
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 18),
        ],
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSubmitting
                ? null
                : (isLastStep ? _submit : _nextStep),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(primaryIcon),
            label: Text(primaryLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _requiredVisitsLabel() {
    switch (_requiredVisits) {
      case '3':
        return '3 Visits';
      case '5':
        return '5 Visits';
      case '10_plus':
        return '10+ Visits';
      case 'custom':
        final value = _customVisitsController.text.trim();
        return value.isEmpty ? 'Custom number' : '$value visits';
      default:
        return 'Not determined yet';
    }
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? 'Not provided' : value.trim(),
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBlock(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE7E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.trim().isEmpty ? 'Not provided' : value.trim(),
            style: const TextStyle(
              color: _ink,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDE7E5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Color(0xFF175CD3),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 42, height: 42, child: Icon(icon, color: _ink)),
      ),
    );
  }

  String _formatDate(String? value) {
    final date = DateTime.tryParse(value ?? '');
    if (date == null) return 'Not scheduled';
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  String _formatTime(String? value) {
    final date = DateTime.tryParse(value ?? '');
    if (date == null) return '--:--';
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }

  String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/locale_controller.dart';
import '../../../core/theme_controller.dart';
import '../../../services/doctor_service.dart';
import 'doctor_ui_constants.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _chiefComplaintController = TextEditingController();
  final _otherSymptomsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentPlanController = TextEditingController();
  final _nursingInstructionsController = TextEditingController();
  final _chronicDiseasesController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _currentMedicationsController = TextEditingController();
  final _previousSurgeriesController = TextEditingController();

  final Set<String> _symptoms = {};
  Map<String, dynamic> _medicalRecord = {};
  String? _selectedBloodType;
  bool _isLoadingRecord = true;
  bool _isSaving = false;
  int _requiredVisits = 5;

  static const _primary = Color(0xFF0F8B8D);
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageColor => DoctorUiConstants.pageColor(context);
  Color get _surfaceColor => DoctorUiConstants.surfaceColor(context);
  Color get _ink => DoctorUiConstants.inkColor(context);
  Color get _muted => DoctorUiConstants.mutedColor(context);
  Color get _softPrimary =>
      _isDark ? _primary.withValues(alpha: 0.18) : const Color(0xFFE7F7F2);
  Color get _fieldBorder => DoctorUiConstants.borderColor(context);
  static const _bloodTypes = <String>[
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    final reason = _text(widget.requestData?['reasonForVisit']);
    if (reason != null) _chiefComplaintController.text = reason;
    _loadMedicalRecord();
  }

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _otherSymptomsController.dispose();
    _diagnosisController.dispose();
    _treatmentPlanController.dispose();
    _nursingInstructionsController.dispose();
    _chronicDiseasesController.dispose();
    _allergiesController.dispose();
    _currentMedicationsController.dispose();
    _previousSurgeriesController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicalRecord() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId =
          prefs.getString('doctor_userId') ??
          _text(widget.requestData?['providerUserId']) ??
          '';
      final patientId = _text(widget.requestData?['patientUserId']) ?? '';

      if (doctorId.isEmpty || patientId.isEmpty) {
        setState(() => _isLoadingRecord = false);
        return;
      }

      final record = await _doctorService.getPatientMedicalRecord(
        patientId,
        doctorId: doctorId,
      );

      if (!mounted) return;
      final bloodType = _text(record['bloodType']);
      final chronicDiseases = _medicalListValue(
        record['diseases'],
        const ['diseaseName', 'name', 'title'],
        fallback:
            _text(record['chronicConditions']) ??
            _text(record['previousConditions']),
      );
      final allergies = _medicalListValue(record['allergies'], const [
        'allergyName',
        'name',
        'title',
      ], fallback: _text(record['allergiesText']));
      _chronicDiseasesController.text = _editableMedicalValue(chronicDiseases);
      _allergiesController.text = _editableMedicalValue(allergies);
      _currentMedicationsController.text =
          _text(record['currentMedications']) ?? '';
      _previousSurgeriesController.text = _text(record['pastSurgeries']) ?? '';
      setState(() {
        _medicalRecord = record;
        _selectedBloodType = _bloodTypes.contains(bloodType) ? bloodType : null;
        _isLoadingRecord = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingRecord = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final doctorIdMissingMessage = context.dtr(
      'doctor.initial.doctorIdMissing',
    );
    final saveFailedMessage = context.dtr('doctor.initial.saveFailed');

    final symptomText = [
      ..._symptoms,
      if (_otherSymptomsController.text.trim().isNotEmpty)
        _otherSymptomsController.text.trim(),
    ].join(', ');

    if (symptomText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.dtr('doctor.initial.selectSymptoms'))),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId =
          prefs.getString('doctor_userId') ??
          _text(widget.requestData?['providerUserId']) ??
          '';
      if (doctorId.isEmpty) {
        throw Exception(doctorIdMissingMessage);
      }

      final response = await _doctorService.createInitialDiagnosisReport(
        serviceRequestId: widget.requestId,
        doctorUserId: doctorId,
        chiefComplaint: _chiefComplaintController.text.trim(),
        symptoms: symptomText,
        diagnosis: _diagnosisController.text.trim(),
        treatmentPlan: _treatmentPlanController.text.trim(),
        nursingInstructions: _nursingInstructionsController.text.trim(),
        requiredVisits: _requiredVisits,
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? saveFailedMessage);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.dtr('doctor.initial.saved')),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.dxError(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DoctorTypographyScope(
      child: ListenableBuilder(
        listenable: localeController,
        builder: (context, _) => Directionality(
          textDirection: localeController.isDoctorArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: _pageColor,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                      children: [
                        _appBar(),
                        const SizedBox(height: 18),
                        _patientHeader(),
                        const SizedBox(height: 12),
                        _medicalProfileCard(),
                        const SizedBox(height: 12),
                        _textAreaCard(
                          icon: Icons.assignment_outlined,
                          title: context.dtr('doctor.initial.chiefComplaint'),
                          controller: _chiefComplaintController,
                          hint: context.dtr(
                            'doctor.initial.enterChiefComplaint',
                          ),
                        ),
                        _symptomsCard(),
                        _textAreaCard(
                          icon: Icons.medical_services_outlined,
                          title: context.dtr('doctor.initial.diagnosis'),
                          controller: _diagnosisController,
                          hint: context.dtr('doctor.initial.enterDiagnosis'),
                        ),
                        _textAreaCard(
                          icon: Icons.medication_outlined,
                          title: context.dtr('doctor.initial.treatmentPlan'),
                          controller: _treatmentPlanController,
                          hint: context.dtr(
                            'doctor.initial.enterTreatmentPlan',
                          ),
                        ),
                        _textAreaCard(
                          icon: Icons.warning_amber_rounded,
                          title: context.dtr(
                            'doctor.initial.nursingInstructions',
                          ),
                          controller: _nursingInstructionsController,
                          hint: context.dtr(
                            'doctor.initial.enterNursingInstructions',
                          ),
                        ),
                        _visitsCard(),
                        const SizedBox(height: 18),
                        _saveButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appBar() {
    return Row(
      children: [
        _iconButton(Icons.arrow_back_rounded, () => Navigator.pop(context)),
        Expanded(
          child: Text(
            context.dtr('doctor.initial.title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _iconButton(
          Icons.language_rounded,
          () => localeController.toggleDoctor(),
        ),
        ListenableBuilder(
          listenable: themeController,
          builder: (context, _) => _iconButton(
            themeController.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            () => themeController.toggle(),
          ),
        ),
        _iconButton(Icons.save_outlined, _isSaving ? null : _save),
      ],
    );
  }

  Widget _patientHeader() {
    final data = widget.requestData ?? {};
    final name =
        _text(data['patientName']) ?? context.dtr('doctor.initial.patient');
    final age = _ageLabel(_text(_medicalRecord['dateOfBirth']));
    final gender =
        _text(_medicalRecord['gender']) ?? context.dtr('doctor.common.notSet');
    final address =
        _text(data['visitAddress']) ??
        _text(data['location']) ??
        _text(_medicalRecord['addressText']) ??
        context.dtr('doctor.common.notSet');
    final phone =
        _text(data['patientPhone']) ?? context.dtr('doctor.common.notSet');
    final serviceType =
        _text(data['serviceType']) ??
        context.dtr('doctor.initial.medicalVisit');
    final image = _text(data['profileImageUrl']) ?? _text(data['patientImage']);

    return _card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: _softPrimary,
            backgroundImage: image == null ? null : NetworkImage(image),
            child: image == null
                ? Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$age, $gender',
                  style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _inlineInfo(Icons.location_on_outlined, address),
                const SizedBox(height: 8),
                _inlineInfo(Icons.phone_rounded, phone),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _inlineInfo(Icons.local_hospital, serviceType),
                    ),
                    _statusBadge(context.dtr('doctor.initial.active')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicalProfileCard() {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _iconTile(Icons.water_drop_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.dtr('doctor.initial.medicalProfile'),
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingRecord)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else ...[
            _medicalFieldLabel(
              Icons.water_drop,
              context.dtr('doctor.initial.bloodType'),
              required: true,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedBloodType,
              isExpanded: true,
              decoration: _medicalInputDecoration(
                context.dtr('doctor.initial.selectBloodType'),
              ),
              items: _bloodTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              validator: (value) =>
                  value == null ? context.dtr('doctor.initial.required') : null,
              onChanged: (value) => setState(() => _selectedBloodType = value),
            ),
            const SizedBox(height: 16),
            _medicalTextField(
              icon: Icons.monitor_heart,
              label: context.dtr('doctor.initial.chronicDiseases'),
              controller: _chronicDiseasesController,
              hint: context.dtr('doctor.initial.enterChronicDiseases'),
            ),
            _medicalTextField(
              icon: Icons.warning_amber_rounded,
              label: context.dtr('doctor.initial.allergies'),
              controller: _allergiesController,
              hint: context.dtr('doctor.initial.enterAllergies'),
            ),
            _medicalTextField(
              icon: Icons.medication_outlined,
              label: context.dtr('doctor.initial.currentMedications'),
              controller: _currentMedicationsController,
              hint: context.dtr('doctor.initial.enterCurrentMedications'),
            ),
            _medicalTextField(
              icon: Icons.edit_outlined,
              label: context.dtr('doctor.initial.previousSurgeries'),
              controller: _previousSurgeriesController,
              hint: context.dtr('doctor.initial.enterPreviousSurgeries'),
              bottomSpacing: 0,
            ),
          ],
        ],
      ),
    );
  }

  Widget _symptomsCard() {
    const symptomOptions = <(String, String)>[
      ('Fever', 'doctor.initial.fever'),
      ('Headache', 'doctor.initial.headache'),
      ('Dizziness', 'doctor.initial.dizziness'),
      ('Nausea', 'doctor.initial.nausea'),
      ('Other', 'doctor.initial.other'),
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldTitle(
            Icons.medical_services_outlined,
            context.dtr('doctor.initial.symptoms'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              for (final option in symptomOptions)
                SizedBox(
                  width: option.$1 == 'Other' ? 110 : 140,
                  child: CheckboxListTile(
                    value: _symptoms.contains(option.$1),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _symptoms.add(option.$1);
                        } else {
                          _symptoms.remove(option.$1);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      context.dtr(option.$2),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _otherSymptomsController,
                  decoration: InputDecoration(
                    hintText: context.dtr('doctor.initial.specifyOther'),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textAreaCard({
    required IconData icon,
    required String title,
    required TextEditingController controller,
    required String hint,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldTitle(icon, title),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            validator: (value) => value == null || value.trim().isEmpty
                ? context.dtr('doctor.initial.required')
                : null,
            decoration: InputDecoration(
              hintText: hint,
              counterStyle: TextStyle(color: _muted, fontSize: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitsCard() {
    return _card(
      child: Column(
        children: [
          _fieldTitle(
            Icons.calendar_month_outlined,
            context.dtr('doctor.initial.requiredVisits'),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _counterButton(Icons.remove_rounded, () {
                if (_requiredVisits > 1) {
                  setState(() => _requiredVisits--);
                }
              }),
              SizedBox(
                width: 90,
                child: Text(
                  '$_requiredVisits',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _counterButton(
                Icons.add_rounded,
                () => setState(() => _requiredVisits++),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${context.dtr('doctor.initial.progress')} '),
                TextSpan(
                  text: context.dtr(
                    'doctor.initial.visitsProgress',
                    args: {'completed': '0', 'required': '$_requiredVisits'},
                  ),
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' ${context.dtr('doctor.initial.visitsCompleted')}',
                ),
              ],
            ),
            style: TextStyle(
              color: _muted,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _save,
      icon: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.save_outlined),
      label: Text(context.dtr('doctor.initial.save')),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(58),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _fieldTitle(IconData icon, String title) {
    return Row(
      children: [
        _iconTile(icon),
        const SizedBox(width: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: title),
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
          style: const TextStyle(
            color: _primary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _medicalFieldLabel(
    IconData icon,
    String label, {
    bool required = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: _primary, size: 21),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: label),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _medicalTextField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
    double bottomSpacing = 16,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _medicalFieldLabel(icon, label),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: _medicalInputDecoration(hint),
          ),
        ],
      ),
    );
  }

  InputDecoration _medicalInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary),
      ),
    );
  }

  Widget _inlineInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: _primary, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _iconTile(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _softPrimary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: _primary, size: 20),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: _softPrimary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: _primary),
        ),
      ),
    );
  }

  Widget _statusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _softPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _primary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: _primary),
        ),
      ),
    );
  }

  String _medicalListValue(
    dynamic value,
    List<String> keys, {
    String? fallback,
  }) {
    if (value is List && value.isNotEmpty) {
      final items = value
          .map((item) {
            if (item is Map) {
              for (final key in keys) {
                final text = _text(item[key]);
                if (text != null) return text;
              }
            }
            return _text(item);
          })
          .whereType<String>()
          .toList();
      if (items.isNotEmpty) return items.join(', ');
    }
    return fallback ?? 'Not set';
  }

  String _editableMedicalValue(String value) {
    return value == 'Not set' ? '' : value;
  }

  String _ageLabel(String? dateOfBirth) {
    final date = DateTime.tryParse(dateOfBirth ?? '');
    if (date == null) return context.dtr('doctor.common.notSet');
    final now = DateTime.now();
    var age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return context.dtr('doctor.initial.years', args: {'count': '$age'});
  }

  String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

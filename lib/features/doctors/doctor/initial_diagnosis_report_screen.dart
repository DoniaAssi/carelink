import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
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

  final Set<String> _symptoms = {};
  Map<String, dynamic> _medicalRecord = {};
  bool _isLoadingRecord = true;
  bool _isSaving = false;
  int _requiredVisits = 5;

  static const _pageColor = DoctorUiConstants.doctorBackground;
  static const _primary = Color(0xFF0F8B8D);
  static const _ink = Color(0xFF101828);
  static const _muted = Color(0xFF667085);

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
      setState(() {
        _medicalRecord = record;
        _isLoadingRecord = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingRecord = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final symptomText = [
      ..._symptoms,
      if (_otherSymptomsController.text.trim().isNotEmpty)
        _otherSymptomsController.text.trim(),
    ].join(', ');

    if (symptomText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter symptoms')),
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
      if (doctorId.isEmpty) throw Exception('Doctor ID not found');

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
        throw Exception(response['error'] ?? 'Failed to save report');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Initial diagnosis saved successfully.'),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    title: 'Chief Complaint',
                    controller: _chiefComplaintController,
                    hint: 'Enter chief complaint...',
                  ),
                  _symptomsCard(),
                  _textAreaCard(
                    icon: Icons.medical_services_outlined,
                    title: 'Diagnosis',
                    controller: _diagnosisController,
                    hint: 'Enter diagnosis...',
                  ),
                  _textAreaCard(
                    icon: Icons.medication_outlined,
                    title: 'Treatment Plan',
                    controller: _treatmentPlanController,
                    hint: 'Enter treatment plan...',
                  ),
                  _textAreaCard(
                    icon: Icons.warning_amber_rounded,
                    title: 'Nursing Instructions',
                    controller: _nursingInstructionsController,
                    hint: 'Enter nursing instructions...',
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
    );
  }

  Widget _appBar() {
    return Row(
      children: [
        _iconButton(Icons.arrow_back_rounded, () => Navigator.pop(context)),
        const Expanded(
          child: Text(
            'Initial Diagnosis Report',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _iconButton(Icons.save_outlined, _isSaving ? null : _save),
      ],
    );
  }

  Widget _patientHeader() {
    final data = widget.requestData ?? {};
    final name = _text(data['patientName']) ?? 'Patient';
    final age = _ageLabel(_text(_medicalRecord['dateOfBirth']));
    final gender = _text(_medicalRecord['gender']) ?? 'Not set';
    final address =
        _text(data['visitAddress']) ??
        _text(data['location']) ??
        _text(_medicalRecord['addressText']) ??
        'Not set';
    final phone = _text(data['patientPhone']) ?? 'Not set';
    final serviceType = _text(data['serviceType']) ?? 'Medical Visit';
    final image = _text(data['profileImageUrl']) ?? _text(data['patientImage']);

    return _card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFFE7F7F2),
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
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$age, $gender',
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w800,
                  ),
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
                    _statusBadge('Active'),
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
              const Expanded(
                child: Text(
                  'Medical Profile',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _readOnlyBadge(),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingRecord)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else ...[
            _profileRow(
              Icons.water_drop,
              'Blood Type',
              _text(_medicalRecord['bloodType']) ?? 'Not set',
            ),
            _profileRow(
              Icons.monitor_heart,
              'Chronic Diseases',
              _medicalListValue(
                _medicalRecord['diseases'],
                ['diseaseName', 'name', 'title'],
                fallback:
                    _text(_medicalRecord['chronicConditions']) ??
                    _text(_medicalRecord['previousConditions']),
              ),
            ),
            _profileRow(
              Icons.warning_amber_rounded,
              'Allergies',
              _medicalListValue(
                _medicalRecord['allergies'],
                ['allergyName', 'name', 'title'],
                fallback: _text(_medicalRecord['allergiesText']),
              ),
            ),
            _profileRow(
              Icons.medication_outlined,
              'Current Medications',
              _text(_medicalRecord['currentMedications']) ?? 'Not set',
            ),
            _profileRow(
              Icons.edit_outlined,
              'Previous Surgeries',
              _text(_medicalRecord['pastSurgeries']) ?? 'Not set',
              showDivider: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _symptomsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldTitle(Icons.medical_services_outlined, 'Symptoms'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              for (final symptom in const [
                'Fever',
                'Headache',
                'Dizziness',
                'Nausea',
                'Other',
              ])
                SizedBox(
                  width: symptom == 'Other' ? 110 : 140,
                  child: CheckboxListTile(
                    value: _symptoms.contains(symptom),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _symptoms.add(symptom);
                        } else {
                          _symptoms.remove(symptom);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      symptom,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _otherSymptomsController,
                  decoration: InputDecoration(
                    hintText: 'Specify other symptoms...',
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
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
            decoration: InputDecoration(
              hintText: hint,
              counterStyle: const TextStyle(color: _muted, fontSize: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE7E5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE7E5)),
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
            'Required Number of Visits',
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
                  style: const TextStyle(
                    color: Colors.black,
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
                const TextSpan(text: 'Progress: '),
                TextSpan(
                  text: '0 / $_requiredVisits',
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const TextSpan(text: ' Visits Completed'),
              ],
            ),
            style: const TextStyle(
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
      label: const Text('Save Initial Diagnosis'),
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
        color: Colors.white,
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

  Widget _profileRow(
    IconData icon,
    String label,
    String value, {
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: _primary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 38, top: 12, bottom: 12),
            child: Divider(height: 1),
          ),
      ],
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
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
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
        color: const Color(0xFFE7F7F2),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: _primary, size: 20),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFE7F7F2),
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

  Widget _readOnlyBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 15, color: _muted),
          SizedBox(width: 6),
          Text(
            'Read Only',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F7F2),
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

  String _ageLabel(String? dateOfBirth) {
    final date = DateTime.tryParse(dateOfBirth ?? '');
    if (date == null) return 'Not set';
    final now = DateTime.now();
    var age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return '$age years';
  }

  String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

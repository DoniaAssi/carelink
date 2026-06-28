import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/doctor_service.dart';
import '../../../core/app_colors.dart';
import 'doctor_ui_constants.dart';

class MedicalRecordScreen extends StatefulWidget {
  final String patientId;

  const MedicalRecordScreen({super.key, required this.patientId});

  @override
  State<MedicalRecordScreen> createState() => _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends State<MedicalRecordScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  Map<String, dynamic> _record = {};

  bool get _hasRecordData =>
      _record.isNotEmpty &&
      (_record.keys.any(
            (key) => key != 'visitReports' && key != 'initialDiagnosisReports',
          ) ||
          _listOf('initialDiagnosisReports').isNotEmpty ||
          _listOf('visitReports').isNotEmpty);

  @override
  void initState() {
    super.initState();
    _loadMedicalRecord();
  }

  Future<void> _loadMedicalRecord() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      final record = await _doctorService.getPatientMedicalRecord(
        widget.patientId,
        doctorId: doctorId,
      );
      debugPrint(
        '[doctor:medical-record-screen] patientId=${widget.patientId} '
        'doctorId=$doctorId '
        'keys=${record.keys.toList()} '
        'initialDiagnosisReports=${record['initialDiagnosisReports'] is List ? (record['initialDiagnosisReports'] as List).length : 0} '
        'visitReports=${record['visitReports'] is List ? (record['visitReports'] as List).length : 0}',
      );
      setState(() {
        _record = record;
        _isLoading = false;
      });
    } catch (e) {
      final message = e.toString().toLowerCase();
      final isMissingRecord = message.contains('medical record not found');
      setState(() {
        _record = {};
        _isLoading = false;
      });
      if (isMissingRecord) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading medical record: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DoctorUiConstants.doctorBackground,
      appBar: AppBar(
        title: const Text('Medical Record'),
        backgroundColor: DoctorUiConstants.doctorBackground,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasRecordData
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadMedicalRecord,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Basic Info Card
                    if (_record.keys.any(
                      (key) =>
                          key != 'visitReports' &&
                          key != 'initialDiagnosisReports',
                    )) ...[
                      _buildSectionCard('Basic Information', [
                        _buildInfoRow(
                          'Date of Birth',
                          _record['dateOfBirth'] ?? 'Not set',
                        ),
                        _buildInfoRow('Gender', _record['gender'] ?? 'Not set'),
                        _buildInfoRow(
                          'Blood Type',
                          _record['bloodType'] ?? 'Not set',
                        ),
                      ]),
                      const SizedBox(height: 16),
                      // Allergies Card
                      _buildSectionCard(
                        'Allergies',
                        _listOf('allergies').isNotEmpty
                            ? _listOf(
                                'allergies',
                              ).map((a) => _buildAllergyRow(a)).toList()
                            : [
                                const Text(
                                  'No allergies recorded',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                      ),
                      const SizedBox(height: 16),
                      // Diseases Card
                      _buildSectionCard(
                        'Medical Conditions',
                        _listOf('diseases').isNotEmpty
                            ? _listOf(
                                'diseases',
                              ).map((d) => _buildDiseaseRow(d)).toList()
                            : [
                                const Text(
                                  'No conditions recorded',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                      ),
                      const SizedBox(height: 16),
                      // Current Medications
                      _buildSectionCard('Current Medications', [
                        Text(
                          _record['currentMedications'] ??
                              'No medications recorded',
                        ),
                      ]),
                      const SizedBox(height: 16),
                      // Past Surgeries
                      _buildSectionCard('Past Surgeries', [
                        Text(
                          _record['pastSurgeries'] ?? 'No surgeries recorded',
                        ),
                      ]),
                      const SizedBox(height: 16),
                    ],
                    if (_listOf('initialDiagnosisReports').isNotEmpty) ...[
                      _buildSectionCard(
                        'Initial Diagnosis',
                        _listOf(
                          'initialDiagnosisReports',
                        ).map((r) => _buildInitialDiagnosisRow(r)).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_listOf('visitReports').isNotEmpty) ...[
                      _buildSectionCard(
                        'Medical Reports',
                        _listOf(
                          'visitReports',
                        ).map((r) => _buildVisitReportRow(r)).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Clinical Notes
                    if (_listOf('clinicalNotes').isNotEmpty) ...[
                      _buildSectionCard(
                        'Clinical Notes',
                        _listOf(
                          'clinicalNotes',
                        ).map((n) => _buildNoteRow(n)).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Lab Results
                    if (_listOf('labResults').isNotEmpty) ...[
                      _buildSectionCard(
                        'Lab Results',
                        _listOf(
                          'labResults',
                        ).map((l) => _buildLabResultRow(l)).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No medical record found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _listOf(String key) {
    final value = _record[key];
    return value is List ? value : const [];
  }

  Widget _buildAllergyRow(dynamic allergy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allergy['allergyName'] ?? 'Unavailable',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${allergy['allergyCategory'] ?? ''} - ${allergy['severity'] ?? 'Unavailable'}',
                  // style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseRow(dynamic disease) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.medical_services,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disease['diseaseName'] ?? 'Unavailable',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${disease['icdCode'] ?? ''} - ${disease['diseaseStatus'] ?? ''}',
                  // style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteRow(dynamic note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                note['authorName'] ?? 'Unavailable',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                _formatDate(note['createdAt']),
                // style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(note['noteText'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildLabResultRow(dynamic result) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result['testName'] ?? 'Unavailable',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Result: ${result['resultValue'] ?? 'N/A'}',
                // style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (result['unit'] != null) ...[
                const Text(' '),
                Text(
                  result['unit'],
                  // style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
          if (result['referenceRange'] != null)
            Text(
              'Reference: ${result['referenceRange']}',
              // style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildVisitReportRow(dynamic report) {
    final item = report is Map ? report : <String, dynamic>{};
    final title = (item['title'] ?? item['diagnosis'] ?? 'Visit report')
        .toString();
    final diagnosis = (item['diagnosis'] ?? '').toString();
    final notes = (item['notes'] ?? item['treatment_plan'] ?? '').toString();
    final medications =
        (item['medications'] ?? item['medications_prescribed'] ?? '')
            .toString();
    final provider = (item['providerName'] ?? '').toString();
    final date = _formatAnyDate(item['visit_date'] ?? item['created_at']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.description, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (date.isNotEmpty || provider.isNotEmpty)
                      Text(
                        [
                          if (date.isNotEmpty) date,
                          if (provider.isNotEmpty) provider,
                        ].join(' - '),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (diagnosis.isNotEmpty) _reportText('Diagnosis', diagnosis),
          if (notes.isNotEmpty) _reportText('Treatment / Notes', notes),
          if (medications.isNotEmpty) _reportText('Medication', medications),
        ],
      ),
    );
  }

  Widget _buildInitialDiagnosisRow(dynamic report) {
    final item = report is Map ? report : <String, dynamic>{};
    final date = _formatAnyDate(
      item['reportDate'] ?? item['createdAt'] ?? item['updatedAt'],
    );
    final doctorName = (item['doctorName'] ?? 'Doctor').toString();
    final diagnosis = (item['diagnosis'] ?? '').toString();
    final treatmentPlan = (item['treatmentPlan'] ?? '').toString();
    final bloodType = _firstDisplayValue([
      item['bloodType'],
      item['blood_type'],
    ]);
    final chronicDiseases = _firstDisplayValue([
      item['chronicDiseases'],
      item['chronic_diseases'],
      item['diseases'],
    ]);
    final allergies = _firstDisplayValue([item['allergies']]);
    final currentMedications = _firstDisplayValue([
      item['currentMedications'],
      item['current_medications'],
    ]);
    final previousSurgeries = _firstDisplayValue([
      item['previousSurgeries'],
      item['pastSurgeries'],
      item['previous_surgeries'],
      item['past_surgeries'],
    ]);
    final chiefComplaint = _firstDisplayValue([item['chiefComplaint']]);
    final symptoms = _firstDisplayValue([item['symptoms']]);
    final nursingInstructions = _firstDisplayValue([
      item['nursingInstructions'],
    ]);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFE3DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.assignment_turned_in_outlined,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Type: Initial Diagnosis',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (date.isNotEmpty) date,
                        if (doctorName.isNotEmpty) doctorName,
                      ].join(' - '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (diagnosis.isNotEmpty) _reportText('Diagnosis', diagnosis),
          if (treatmentPlan.isNotEmpty)
            _reportText('Treatment Plan', treatmentPlan),
          if (bloodType.isNotEmpty) _reportText('Blood Type', bloodType),
          if (chronicDiseases.isNotEmpty)
            _reportText('Chronic Diseases', chronicDiseases),
          if (allergies.isNotEmpty) _reportText('Allergies', allergies),
          if (currentMedications.isNotEmpty)
            _reportText('Current Medications', currentMedications),
          if (previousSurgeries.isNotEmpty)
            _reportText('Previous Surgeries', previousSurgeries),
          if (chiefComplaint.isNotEmpty)
            _reportText('Chief Complaint', chiefComplaint),
          if (symptoms.isNotEmpty) _reportText('Symptoms', symptoms),
          if (nursingInstructions.isNotEmpty)
            _reportText('Nursing Instructions', nursingInstructions),
        ],
      ),
    );
  }

  String _firstDisplayValue(List<dynamic> values) {
    for (final value in values) {
      final formatted = _formatDisplayValue(value);
      if (formatted.isNotEmpty) return formatted;
    }
    return '';
  }

  String _formatDisplayValue(dynamic value) {
    if (value == null) return '';

    if (value is Iterable) {
      return value
          .map(_formatDisplayValue)
          .where((item) => item.isNotEmpty)
          .join(', ');
    }

    if (value is Map) {
      for (final key in const [
        'diseaseName',
        'allergyName',
        'name',
        'value',
        'description',
      ]) {
        final formatted = _formatDisplayValue(value[key]);
        if (formatted.isNotEmpty) return formatted;
      }
      return '';
    }

    final formatted = value.toString().trim();
    if (formatted.isEmpty ||
        formatted.toLowerCase() == 'null' ||
        formatted.toLowerCase() == 'not set') {
      return '';
    }
    return formatted;
  }

  Widget _reportText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }

  String _formatAnyDate(dynamic value) {
    if (value == null) return '';
    return _formatDate(value.toString());
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

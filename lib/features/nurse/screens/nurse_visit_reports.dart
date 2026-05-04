import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/services/report_service.dart';
import 'package:carelink/shared/services/service_request_service.dart';
import 'nurse_ui.dart';

class NurseVisitReports extends StatefulWidget {
  final User user;

  const NurseVisitReports({Key? key, required this.user}) : super(key: key);

  @override
  State<NurseVisitReports> createState() => _NurseVisitReportsState();
}

class _NurseVisitReportsState extends State<NurseVisitReports> {
  List<ServiceRequest> completedRequests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompletedRequests();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive((context) => Scaffold(
      backgroundColor: NurseUi.background,
      appBar: AppBar(
        title: Text(NurseUi.label('Visit Reports', '\u062a\u0642\u0627\u0631\u064a\u0631 \u0627\u0644\u0632\u064a\u0627\u0631\u0627\u062a')),
        backgroundColor: NurseUi.background,
        foregroundColor: NurseUi.text,
        elevation: 0,
        actions: [
          NurseModeControls(providerUserId: widget.user.userId),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNewReportDialog(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            )
          : completedRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.assignment_turned_in,
                        size: 60,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No completed visits yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showNewReportDialog(),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'Submit First Report',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: completedRequests.length,
                  itemBuilder: (context, index) {
                    return _buildReportCard(completedRequests[index]);
                  },
                ),
    ));
  }

  Widget _buildReportCard(ServiceRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.serviceType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            request.location,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF28a745).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'COMPLETED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF28a745),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visit Date',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(request.scheduledDate),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duration',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '2 hours',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Visit Summary',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Patient condition stable. Administered prescribed medications and monitored vital signs. Provided patient education on medication adherence and lifestyle modifications.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF17a2b8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _viewFullReport(request),
                    icon: const Icon(Icons.visibility, color: Colors.white, size: 16),
                    label: const Text(
                      'View Full Report',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFffc107),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _editReport(request),
                    icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                    label: const Text(
                      'Edit Report',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCompletedRequests() async {
    try {
      final data = await ServiceRequestService.getProviderRequests(
        widget.user.userId,
        status: 'completed',
      );
      setState(() {
        completedRequests = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error loading completed requests: $e');
    }
  }

  void _showNewReportDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => NewReportForm(
        providerUserId: widget.user.userId,
        completedRequests: completedRequests,
        onSaved: _loadCompletedRequests,
      ),
    );
  }

  void _viewFullReport(ServiceRequest request) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => FullReportView(request: request),
    );
  }

  void _editReport(ServiceRequest request) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => EditReportForm(request: request),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class NewReportForm extends StatefulWidget {
  final String providerUserId;
  final List<ServiceRequest> completedRequests;
  final Future<void> Function() onSaved;

  const NewReportForm({
    Key? key,
    required this.providerUserId,
    required this.completedRequests,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<NewReportForm> createState() => _NewReportFormState();
}

class _NewReportFormState extends State<NewReportForm> {
  final visitSummaryController = TextEditingController();
  final vitalSignsController = TextEditingController();
  final medicationsController = TextEditingController();
  final observationsController = TextEditingController();
  final recommendationsController = TextEditingController();

  String selectedPatient = '';
  String selectedService = '';
  ServiceRequest? selectedRequest;
  DateTime visitDate = DateTime.now();
  int visitDuration = 1;

  List<String> get patients => widget.completedRequests
      .map((request) => request.patientName.isEmpty ? request.patientId : request.patientName)
      .toSet()
      .toList();

  final List<String> services = [
    'Home Nursing Care',
    'Medication Administration',
    'Vital Signs Monitoring',
    'Wound Care',
    'Patient Education',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'New Visit Report',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Selection
                  const Text(
                    'Patient',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedPatient.isEmpty ? null : selectedPatient,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    hint: const Text('Select patient'),
                    items: patients.map((patient) {
                      return DropdownMenuItem<String>(
                        value: patient,
                        child: Text(patient),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedPatient = value!;
                        selectedRequest = widget.completedRequests.firstWhere(
                          (request) =>
                              request.patientName == value ||
                              request.patientId == value,
                          orElse: () => widget.completedRequests.first,
                        );
                        selectedService = selectedRequest?.serviceType ?? selectedService;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Service Type
                  const Text(
                    'Service Type',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedService.isEmpty ? null : selectedService,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    hint: const Text('Select service type'),
                    items: services.map((service) {
                      return DropdownMenuItem<String>(
                        value: service,
                        child: Text(service),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedService = value!);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Visit Date and Duration
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Visit Date',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${visitDate.day}/${visitDate.month}/${visitDate.year}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Duration (hours)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onChanged: (value) {
                                setState(() => visitDuration = int.tryParse(value) ?? 1);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Visit Summary
                  const Text(
                    'Visit Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: visitSummaryController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Brief summary of the visit...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Vital Signs
                  const Text(
                    'Vital Signs',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: vitalSignsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Blood pressure, heart rate, temperature, etc.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Medications Administered
                  const Text(
                    'Medications Administered',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: medicationsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'List medications given and dosages...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Observations
                  const Text(
                    'Clinical Observations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: observationsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Patient condition, symptoms, concerns...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recommendations
                  const Text(
                    'Recommendations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: recommendationsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Follow-up care, lifestyle advice, etc.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _submitReport,
                      child: const Text(
                        'Submit Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: visitDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => visitDate = picked);
    }
  }

  Future<void> _submitReport() async {
    if (selectedPatient.isEmpty || selectedService.isEmpty ||
        visitSummaryController.text.isEmpty || selectedRequest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a visit and fill required fields')),
      );
      return;
    }

    final success = await ReportService.createReport(
      providerId: widget.providerUserId,
      requestId: selectedRequest!.id,
      patientId: selectedRequest!.patientId,
      patientName: selectedPatient,
      serviceType: selectedService,
      location: selectedRequest!.location,
      scheduledDate: visitDate,
      durationHours: visitDuration,
      visitSummary: visitSummaryController.text.trim(),
      vitalSigns: vitalSignsController.text.trim(),
      medications: medicationsController.text.trim(),
      observations: observationsController.text.trim(),
      recommendations: recommendationsController.text.trim(),
    );
    if (success) await widget.onSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Report submitted successfully' : 'Failed to submit report',
        ),
      ),
    );
    if (success) Navigator.pop(context);
  }
}

class FullReportView extends StatelessWidget {
  final ServiceRequest request;

  const FullReportView({Key? key, required this.request}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Visit Report Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReportSection('Patient Information', 'John Doe\nAge: 65\nMedical History: Hypertension, Diabetes'),
                  _buildReportSection('Service Type', request.serviceType),
                  _buildReportSection('Visit Date', _formatDate(request.scheduledDate)),
                  _buildReportSection('Duration', '2 hours'),
                  _buildReportSection('Visit Summary', 'Patient condition stable. Administered prescribed medications and monitored vital signs. Provided patient education on medication adherence and lifestyle modifications.'),
                  _buildReportSection('Vital Signs', 'Blood Pressure: 120/80 mmHg\nHeart Rate: 72 bpm\nTemperature: 98.6°F\nOxygen Saturation: 98%'),
                  _buildReportSection('Medications Administered', 'Metformin 500mg - 1 tablet\nLisinopril 10mg - 1 tablet\nAspirin 81mg - 1 tablet'),
                  _buildReportSection('Clinical Observations', 'Patient reports good compliance with medication regimen. No signs of distress or complications. Wound healing progressing well.'),
                  _buildReportSection('Recommendations', 'Continue current medication regimen. Schedule follow-up appointment in 2 weeks. Encourage daily walking exercise.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class EditReportForm extends StatefulWidget {
  final ServiceRequest request;

  const EditReportForm({Key? key, required this.request}) : super(key: key);

  @override
  State<EditReportForm> createState() => _EditReportFormState();
}

class _EditReportFormState extends State<EditReportForm> {
  final visitSummaryController = TextEditingController(text: 'Patient condition stable...');

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Visit Report',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visit Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: visitSummaryController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _updateReport,
                    child: const Text(
                      'Update Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateReport() {
    // TODO: Update report via API
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report updated successfully')),
    );
    Navigator.pop(context);
  }
}

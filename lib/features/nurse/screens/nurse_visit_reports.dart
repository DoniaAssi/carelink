import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/visit_report.dart';
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
  List<VisitReport> visitReports = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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
          : visitReports.isEmpty
              ? Center(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
                    decoration: BoxDecoration(
                      color: NurseUi.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: NurseUi.border.withOpacity(0.8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            NurseUi.isDarkMode.value ? 0.18 : 0.05,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: NurseUi.softSurface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_rounded,
                            size: 42,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No completed visit reports yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: NurseUi.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Completed reports from the database will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: NurseUi.muted),
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _showNewReportDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'Submit First Report',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visitReports.length,
                  itemBuilder: (context, index) {
                    return _buildReportCard(visitReports[index]);
                  },
                ),
    ));
  }

  Widget _buildReportCard(VisitReport report) {
    final summary = report.visitSummary.trim().isNotEmpty
        ? report.visitSummary.trim()
        : 'No summary available yet.';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(NurseUi.isDarkMode.value ? 0.18 : 0.05),
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
                        report.serviceType.isNotEmpty ? report.serviceType : 'Visit Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: NurseUi.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: NurseUi.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              report.location.isNotEmpty ? report.location : 'Unknown location',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: NurseUi.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    report.status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _reportMetric(
                  Icons.calendar_today_rounded,
                  'Visit Date',
                  _formatDate(report.scheduledDate),
                ),
                _reportMetric(
                  Icons.schedule_rounded,
                  'Duration',
                  report.durationHours > 0
                      ? '${report.durationHours} hours'
                      : 'Not specified',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Summary',
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
                color: NurseUi.softSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NurseUi.border.withOpacity(0.7)),
              ),
              child: Text(
                summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: NurseUi.text, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _viewFullReport(report),
                    icon: const Icon(Icons.visibility, size: 16),
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
                      backgroundColor: NurseUi.softSurface,
                      foregroundColor: AppColors.primaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: NurseUi.border.withOpacity(0.8)),
                    ),
                    onPressed: () => _editReport(report),
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(
                      'Edit Report',
                      style: TextStyle(color: AppColors.primaryDark, fontSize: 12),
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

  Widget _reportMetric(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: NurseUi.muted)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: NurseUi.text,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final requests = await ServiceRequestService.getProviderRequests(
        widget.user.userId,
        status: 'completed',
      );
      final reports = await ReportService.getReports(widget.user.userId);
      if (!mounted) return;
      setState(() {
        completedRequests = requests;
        visitReports = reports;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        completedRequests = [];
        visitReports = [];
        isLoading = false;
      });
      // ignore: avoid_print
      print('Error loading reports or requests: $e');
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
        onSaved: _loadData,
      ),
    );
  }

  void _viewFullReport(VisitReport report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => FullReportView(report: report),
    );
  }

  void _editReport(VisitReport report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => EditReportForm(
        report: report,
        onSaved: _loadData,
      ),
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
  final patientIdController = TextEditingController();
  final patientNameController = TextEditingController();
  final serviceTypeController = TextEditingController();
  final locationController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    if (widget.completedRequests.isNotEmpty) {
      selectedRequest = widget.completedRequests.first;
      selectedPatient = selectedRequest!.patientName.isEmpty
          ? selectedRequest!.patientId
          : selectedRequest!.patientName;
      selectedService = selectedRequest!.serviceType;
      visitDate = selectedRequest!.scheduledDate;
    }
  }

  @override
  void dispose() {
    patientIdController.dispose();
    patientNameController.dispose();
    serviceTypeController.dispose();
    locationController.dispose();
    visitSummaryController.dispose();
    vitalSignsController.dispose();
    medicationsController.dispose();
    observationsController.dispose();
    recommendationsController.dispose();
    super.dispose();
  }

  List<String> get patients => widget.completedRequests
      .map((request) => request.patientName.isEmpty ? request.patientId : request.patientName)
      .toSet()
      .toList();

  List<String> get services => {
        ...widget.completedRequests
            .map((request) => request.serviceType)
            .where((service) => service.trim().isNotEmpty),
        'Home Nursing Care',
        'Medication Administration',
        'Vital Signs Monitoring',
        'Wound Care',
        'Patient Education',
      }.toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: NurseUi.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'New Visit Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: NurseUi.text,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: NurseUi.text),
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
                  if (widget.completedRequests.isEmpty) ...[
                    _manualField('Patient ID', patientIdController),
                    _manualField('Patient Name', patientNameController),
                  ] else ...[
                    Text(
                      'Patient',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: NurseUi.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedPatient.isEmpty ? null : selectedPatient,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: NurseUi.surface,
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
                          visitDate = selectedRequest?.scheduledDate ?? visitDate;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Service Type
                  if (widget.completedRequests.isEmpty)
                    _manualField('Service Type', serviceTypeController)
                  else ...[
                    Text(
                      'Service Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: NurseUi.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedService.isEmpty ? null : selectedService,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: NurseUi.surface,
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
                  ],
                  if (widget.completedRequests.isEmpty) _manualField('Location', locationController),
                  const SizedBox(height: 16),

                  // Visit Date and Duration
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Visit Date',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: NurseUi.text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: NurseUi.surface,
                                  border: Border.all(color: NurseUi.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 20,
                                      color: AppColors.primaryDark,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${visitDate.day}/${visitDate.month}/${visitDate.year}',
                                      style: TextStyle(fontSize: 14, color: NurseUi.text),
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
                            Text(
                              'Duration (hours)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: NurseUi.text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: NurseUi.surface,
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
                  Text(
                    'Visit Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NurseUi.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: visitSummaryController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Brief summary of the visit...',
                      filled: true,
                      fillColor: NurseUi.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Vital Signs
                  Text(
                    'Vital Signs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NurseUi.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: vitalSignsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Blood pressure, heart rate, temperature, etc.',
                      filled: true,
                      fillColor: NurseUi.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Medications Administered
                  Text(
                    'Medications Administered',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NurseUi.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: medicationsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'List medications given and dosages...',
                      filled: true,
                      fillColor: NurseUi.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Observations
                  Text(
                    'Clinical Observations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NurseUi.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: observationsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Patient condition, symptoms, concerns...',
                      filled: true,
                      fillColor: NurseUi.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recommendations
                  Text(
                    'Recommendations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NurseUi.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: recommendationsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Follow-up care, lifestyle advice, etc.',
                      filled: true,
                      fillColor: NurseUi.surface,
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
                        foregroundColor: Colors.white,
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

  Widget _manualField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: NurseUi.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    final patientId =
        selectedRequest?.patientId ?? patientIdController.text.trim();
    final patientName = selectedRequest?.patientName.isNotEmpty == true
        ? selectedRequest!.patientName
        : (patientNameController.text.trim().isNotEmpty
            ? patientNameController.text.trim()
            : patientId);
    final serviceType = selectedRequest?.serviceType.isNotEmpty == true
        ? selectedRequest!.serviceType
        : (selectedService.isNotEmpty
            ? selectedService
            : serviceTypeController.text.trim());
    final location = selectedRequest?.location.isNotEmpty == true
        ? selectedRequest!.location
        : locationController.text.trim();

    if (patientId.isEmpty ||
        serviceType.isEmpty ||
        visitSummaryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill patient, service, and summary')),
      );
      return;
    }

    final success = await ReportService.createReport(
      providerId: widget.providerUserId,
      requestId: selectedRequest?.id ?? '',
      patientId: patientId,
      patientName: patientName,
      serviceType: serviceType,
      location: location,
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
  final VisitReport report;

  const FullReportView({Key? key, required this.report}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final patient = report.patientName.isNotEmpty ? report.patientName : report.patientId;
    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: BoxDecoration(
        color: NurseUi.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: NurseUi.text,
                        ),
                      ),
                      Text(
                        patient.isNotEmpty ? patient : 'Patient report',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: NurseUi.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: NurseUi.text),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _smartSummary(report),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _detailTile(
                          Icons.medical_services_rounded,
                          'Service',
                          report.serviceType.isNotEmpty
                              ? report.serviceType
                              : 'Nursing service',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detailTile(
                          Icons.event_rounded,
                          'Date',
                          _formatDate(report.scheduledDate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildReportSection('Clinical Notes', report.visitSummary),
                  _buildReportSection('Vital Signs', report.vitalSigns),
                  _buildReportSection('Medications', report.medications),
                  _buildReportSection('Observations', report.observations),
                  _buildReportSection('Recommendations', report.recommendations),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryDark),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: NurseUi.muted)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: NurseUi.text,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection(String title, String content) {
    final body = content.trim().isEmpty ? 'Not recorded.' : content.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(fontSize: 14, color: NurseUi.text, height: 1.45),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _smartSummary(VisitReport report) {
    final parts = <String>[];
    final patient = report.patientName.isNotEmpty ? report.patientName : 'The patient';
    final service = report.serviceType.isNotEmpty ? report.serviceType : 'nursing care';
    parts.add('$patient received $service on ${_formatDate(report.scheduledDate)}.');
    if (report.visitSummary.trim().isNotEmpty) {
      parts.add('Visit focus: ${report.visitSummary.trim()}');
    }
    if (report.vitalSigns.trim().isNotEmpty) {
      parts.add('Vitals noted: ${report.vitalSigns.trim()}');
    }
    if (report.medications.trim().isNotEmpty) {
      parts.add('Medications: ${report.medications.trim()}');
    }
    if (report.observations.trim().isNotEmpty) {
      parts.add('Clinical observation: ${report.observations.trim()}');
    }
    if (report.recommendations.trim().isNotEmpty) {
      parts.add('Recommended next step: ${report.recommendations.trim()}');
    }
    if (parts.length == 1) {
      parts.add('No detailed clinical notes were added to this report yet.');
    }
    return parts.join('\n\n');
  }
}

class EditReportForm extends StatefulWidget {
  final VisitReport report;
  final Future<void> Function() onSaved;

  const EditReportForm({
    Key? key,
    required this.report,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<EditReportForm> createState() => _EditReportFormState();
}

class _EditReportFormState extends State<EditReportForm> {
  late final TextEditingController visitSummaryController;
  late final TextEditingController patientNameController;
  late final TextEditingController serviceTypeController;
  late final TextEditingController locationController;
  late final TextEditingController durationController;
  late final TextEditingController vitalSignsController;
  late final TextEditingController medicationsController;
  late final TextEditingController observationsController;
  late final TextEditingController recommendationsController;

  @override
  void initState() {
    super.initState();
    visitDate = widget.report.scheduledDate;
    patientNameController = TextEditingController(text: widget.report.patientName);
    serviceTypeController = TextEditingController(text: widget.report.serviceType);
    locationController = TextEditingController(text: widget.report.location);
    durationController = TextEditingController(
      text: widget.report.durationHours > 0
          ? widget.report.durationHours.toString()
          : '',
    );
    visitSummaryController = TextEditingController(text: widget.report.visitSummary);
    vitalSignsController = TextEditingController(text: widget.report.vitalSigns);
    medicationsController = TextEditingController(text: widget.report.medications);
    observationsController = TextEditingController(text: widget.report.observations);
    recommendationsController = TextEditingController(text: widget.report.recommendations);
  }

  @override
  void dispose() {
    patientNameController.dispose();
    serviceTypeController.dispose();
    locationController.dispose();
    durationController.dispose();
    visitSummaryController.dispose();
    vitalSignsController.dispose();
    medicationsController.dispose();
    observationsController.dispose();
    recommendationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: NurseUi.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Edit Visit Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: NurseUi.text,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: NurseUi.text),
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
                  _field('Patient Name', patientNameController),
                  _field('Service Type', serviceTypeController),
                  _field('Location', locationController),
                  _dateField(),
                  _field(
                    'Duration (hours)',
                    durationController,
                    keyboardType: TextInputType.number,
                  ),
                  _field(
                    'Visit Summary',
                    visitSummaryController,
                    maxLines: 3,
                  ),
                  _field(
                    'Vital Signs',
                    vitalSignsController,
                    maxLines: 3,
                  ),
                  _field(
                    'Medications Administered',
                    medicationsController,
                    maxLines: 2,
                  ),
                  _field(
                    'Clinical Observations',
                    observationsController,
                    maxLines: 3,
                  ),
                  _field(
                    'Recommendations',
                    recommendationsController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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
          ),
        ],
      ),
    );
  }

  DateTime visitDate = DateTime.now();

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: NurseUi.text,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              filled: true,
              fillColor: NurseUi.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visit Date',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: NurseUi.text,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NurseUi.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NurseUi.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(visitDate),
                    style: TextStyle(color: NurseUi.text),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: visitDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => visitDate = picked);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _updateReport() async {
    final success = await ReportService.updateReport(
      reportId: widget.report.id,
      providerId: widget.report.providerId,
      requestId: widget.report.requestId,
      patientId: widget.report.patientId,
      patientName: patientNameController.text.trim(),
      serviceType: serviceTypeController.text.trim(),
      location: locationController.text.trim(),
      scheduledDate: visitDate,
      durationHours: int.tryParse(durationController.text.trim()) ?? 0,
      visitSummary: visitSummaryController.text.trim(),
      vitalSigns: vitalSignsController.text.trim(),
      medications: medicationsController.text.trim(),
      observations: observationsController.text.trim(),
      recommendations: recommendationsController.text.trim(),
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report updated successfully')),
        );
        await widget.onSaved();
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update report')),
        );
      }
    }
  }
}

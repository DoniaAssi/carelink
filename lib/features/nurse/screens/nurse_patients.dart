import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/service_request_service.dart';

import 'nurse_ui.dart';

class NursePatients extends StatefulWidget {
  const NursePatients({super.key, required this.user});

  final User user;

  @override
  State<NursePatients> createState() => _NursePatientsState();
}

class _NursePatientsState extends State<NursePatients> {
  bool isLoading = true;
  List<ServiceRequest> requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ServiceRequestService.getProviderRequests(
      widget.user.userId,
    );
    if (!mounted) return;
    setState(() {
      requests = data;
      isLoading = false;
    });
  }

  List<ServiceRequest> get patients {
    final seen = <String>{};
    final list = <ServiceRequest>[];
    for (final request in requests) {
      final key = request.patientId.isNotEmpty
          ? request.patientId
          : request.patientName;
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      list.add(request);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                  children: [
                    const Text(
                      'My Patients',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF151823),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _searchBox(),
                    const SizedBox(height: 14),
                    if (patients.isEmpty)
                      _emptyState()
                    else
                      for (final patient in patients) _patientTile(patient),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _shadow,
      ),
      child: Row(
        children: const [
          Expanded(
            child: Text(
              'Search patients...',
              style: TextStyle(
                color: Color(0xFF78909C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(Icons.search_rounded, color: Color(0xFF607D8B)),
        ],
      ),
    );
  }

  Widget _patientTile(ServiceRequest request) {
    final name = request.patientName.isEmpty
        ? 'Patient ${request.patientId}'
        : request.patientName;
    final age = request.patientAge > 0 ? request.patientAge.toString() : '--';
    final location = request.location.isEmpty ? 'Ramallah' : request.location;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _shadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: _avatar(name),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          'Female • $age\n$location',
          style: const TextStyle(
            height: 1.35,
            color: Color(0xFF607D8B),
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.primaryDark,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NursePatientDetails(request: request),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String name) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFDDF2EF),
      child: Text(
        name.isEmpty ? 'P' : name[0].toUpperCase(),
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Text(
          'No patients yet',
          style: TextStyle(
            color: Color(0xFF78909C),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  List<BoxShadow> get _shadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.045),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

class NursePatientDetails extends StatelessWidget {
  const NursePatientDetails({super.key, required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final name = request.patientName.isEmpty
        ? 'Patient ${request.patientId}'
        : request.patientName;
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
            children: [
              _topBar(context),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFDDF2EF),
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 24,
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
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Female • ${request.patientAge > 0 ? request.patientAge : '--'} years',
                          style: const TextStyle(
                            color: Color(0xFF607D8B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _smallLine(
                          Icons.location_on_outlined,
                          request.location,
                        ),
                        _smallLine(Icons.phone_outlined, request.patientPhone),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _card(
                title: 'Medical Information',
                children: [
                  _infoRow('Condition', request.medicalCondition, Icons.shield),
                  _infoRow('Allergies', 'Dust, Pollen', Icons.coronavirus),
                  _infoRow(
                    'Medications',
                    'Ventolin, Montelukast',
                    Icons.description,
                  ),
                  _infoRow('Blood Type', 'O+', Icons.bloodtype),
                  const Divider(height: 28),
                  const Row(
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                      Spacer(),
                      Text(
                        'View full medical records',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFB0BEC5),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _card(
                title: 'Care Plan',
                trailing: 'View full plan',
                children: [
                  _plainRow('Care Type', request.serviceType),
                  _plainRow('Frequency', '3 times per week'),
                  _plainRow('Next Visit', _dateTime(request.scheduledDate)),
                  _plainRow('Goals', '• Improve breathing\n• Monitor symptoms'),
                ],
              ),
              const SizedBox(height: 14),
              _card(
                title: 'Latest Note',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDF2EF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.note_alt,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    title: const Text(
                      'Visit note • Jun 14, 2026',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text(
                      'Patient is stable. No signs of respiratory distress...',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        const Spacer(),
        const Icon(Icons.language_rounded, color: AppColors.primaryDark),
        const SizedBox(width: 14),
        const Icon(Icons.dark_mode_rounded, color: AppColors.primaryDark),
      ],
    );
  }

  Widget _smallLine(IconData icon, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF607D8B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    String? trailing,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Flexible(
            child: Text(
              value.trim().isEmpty ? 'Not recorded' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _plainRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF607D8B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _dateTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

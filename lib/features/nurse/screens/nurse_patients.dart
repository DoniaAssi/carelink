import 'dart:async';

import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/features/nurse/services/nurse_repository.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';

import 'nurse_ui.dart';

class MyPatientsScreen extends NursePatients {
  const MyPatientsScreen({super.key, required super.user});
}

class NursePatients extends StatefulWidget {
  const NursePatients({super.key, required this.user});

  final User user;

  @override
  State<NursePatients> createState() => _NursePatientsState();
}

class _NursePatientsState extends State<NursePatients> {
  static const Color _background = Color(0xFFF4FAF9);
  static const Color _primary = Color(0xFF0F766E);
  static const Color _active = Color(0xFF22C55E);
  static const Color _inactive = Color(0xFF9CA3AF);

  final NurseRepository _repository = const NurseRepository();
  final TextEditingController _searchController = TextEditingController();

  Timer? _refreshTimer;
  bool isLoading = true;
  List<ServiceRequest> requests = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => isLoading = true);
    }
    final data = await _repository.getAllRequests(widget.user.userId);
    if (!mounted) return;
    setState(() {
      requests = data;
      isLoading = false;
    });
  }

  List<_PatientSummary> get patients {
    final byKey = <String, ServiceRequest>{};
    final activeByKey = <String, bool>{};

    for (final request in requests) {
      final key = _patientKey(request);
      if (key.isEmpty) continue;
      final isActive = _isActiveStatus(request.status);
      activeByKey[key] = (activeByKey[key] ?? false) || isActive;
      if (!byKey.containsKey(key) ||
          (isActive && !_isActiveStatus(byKey[key]!.status))) {
        byKey[key] = request;
      }
    }

    final list =
        byKey.entries.map((entry) {
          return _PatientSummary.fromRequest(
            entry.value,
            active: activeByKey[entry.key] ?? false,
          );
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return list;
  }

  List<_PatientSummary> get filteredPatients {
    final query = searchQuery;
    if (query.isEmpty) return patients;
    return patients.where((patient) {
      return patient.searchText.contains(query);
    }).toList();
  }

  String _patientKey(ServiceRequest request) {
    final id = request.patientId.trim();
    if (id.isNotEmpty) return id;
    return request.patientName.trim().toLowerCase();
  }

  bool _isActiveStatus(String status) {
    final value = status.toLowerCase().trim();
    return value == 'accepted' ||
        value == 'assigned' ||
        value == 'confirmed' ||
        value == 'scheduled' ||
        value == 'in_progress' ||
        value == 'in progress';
  }

  @override
  Widget build(BuildContext context) {
    final allPatients = patients;
    final visiblePatients = filteredPatients;

    return NurseUi.reactive(
      (context) => Container(
        color: _background,
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                    children: [
                      _header(),
                      const SizedBox(height: 18),
                      _searchBox(),
                      const SizedBox(height: 18),
                      _listHeader(allPatients.length),
                      const SizedBox(height: 12),
                      if (visiblePatients.isEmpty)
                        _emptyState()
                      else
                        for (final patient in visiblePatients)
                          _patientCard(patient),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'My Patients',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),
        Tooltip(
          message: 'Add patient',
          child: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_add_alt_1_rounded),
            color: _primary,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchBox() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _shadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Search patients...',
                isDense: true,
              ),
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Filter',
            visualDensity: VisualDensity.compact,
            onPressed: () {},
            icon: const Icon(
              Icons.filter_list_rounded,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listHeader(int total) {
    return Row(
      children: [
        Text(
          'Patients ($total)',
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        if (searchQuery.isNotEmpty)
          Text(
            '${filteredPatients.length} found',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }

  Widget _patientCard(_PatientSummary patient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _shadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientDetailsScreen(request: patient.request),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _avatar(patient),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        patient.detailsText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: _primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              patient.locationText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusBadge(patient.active),
                    const SizedBox(height: 12),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: _primary,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(_PatientSummary patient) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFDDF2EF),
          child: Text(
            patient.initial,
            style: const TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: patient.active ? _active : _inactive,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(bool active) {
    final color = active ? _active : _inactive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _shadow,
      ),
      child: const Center(
        child: Text(
          'No patients found',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  List<BoxShadow> get _shadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.055),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

class _PatientSummary {
  const _PatientSummary({
    required this.name,
    required this.phone,
    required this.age,
    required this.gender,
    required this.location,
    required this.active,
    required this.request,
  });

  final String name;
  final String phone;
  final int age;
  final String gender;
  final String location;
  final bool active;
  final ServiceRequest request;

  factory _PatientSummary.fromRequest(
    ServiceRequest request, {
    required bool active,
  }) {
    final name = request.patientName.trim().isEmpty
        ? 'Patient ${request.patientId}'
        : request.patientName.trim();
    final location = request.patientAddress.trim().isNotEmpty
        ? request.patientAddress.trim()
        : request.location.trim();

    return _PatientSummary(
      name: name,
      phone: request.patientPhone.trim(),
      age: request.patientAge,
      gender: '',
      location: location,
      active: active,
      request: request,
    );
  }

  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'P';
    return trimmed.substring(0, 1).toUpperCase();
  }

  String get detailsText {
    final parts = <String>[];
    if (gender.trim().isNotEmpty) parts.add(_titleCase(gender));
    if (age > 0) parts.add('$age years');
    if (phone.isNotEmpty) parts.add(phone);
    return parts.isEmpty ? 'Details not set' : parts.join(' - ');
  }

  String get locationText => location.isEmpty ? 'Location not set' : location;

  String get searchText => '$name $phone $location'.toLowerCase();

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value.substring(0, 1).toUpperCase() + value.substring(1);
  }
}

class PatientDetailsScreen extends NursePatientDetails {
  const PatientDetailsScreen({super.key, required super.request});
}

class NursePatientDetails extends StatelessWidget {
  const NursePatientDetails({super.key, required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final name = request.patientName.trim().isEmpty
        ? 'Patient ${request.patientId}'
        : request.patientName.trim();
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: const Color(0xFFF4FAF9),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
            children: [
              _topBar(context),
              const SizedBox(height: 18),
              _patientHeader(name),
              const SizedBox(height: 24),
              _card(
                title: 'Medical Information',
                children: [
                  _infoRow('Condition', request.medicalCondition, Icons.shield),
                  _infoRow(
                    'Reason',
                    request.reasonForVisit,
                    Icons.medical_information_outlined,
                  ),
                  _infoRow('Service', request.serviceType, Icons.description),
                  _infoRow('Phone', request.patientPhone, Icons.phone_outlined),
                ],
              ),
              const SizedBox(height: 14),
              _card(
                title: 'Care Plan',
                children: [
                  _plainRow('Care Type', request.serviceType),
                  _plainRow(
                    'Duration',
                    '${request.expectedDurationHours} hours',
                  ),
                  _plainRow('Next Visit', _dateTime(request.scheduledDate)),
                  _plainRow('Notes', request.notes ?? ''),
                ],
              ),
              const SizedBox(height: 14),
              _card(
                title: 'Location',
                children: [
                  _plainRow('Address', _locationText),
                  _plainRow('Location Note', request.locationNote),
                  _plainRow('GPS', _gpsText),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _patientHeader(String name) {
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: const Color(0xFFDDF2EF),
          child: Text(
            name.isEmpty ? 'P' : name.substring(0, 1).toUpperCase(),
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
                request.patientAge > 0
                    ? '${request.patientAge} years'
                    : 'Age not set',
                style: const TextStyle(
                  color: Color(0xFF607D8B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _smallLine(Icons.location_on_outlined, _locationText),
              _smallLine(Icons.phone_outlined, request.patientPhone),
            ],
          ),
        ),
      ],
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

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
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
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
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
              value.trim().isEmpty ? 'Not recorded' : value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String get _locationText {
    if (request.patientAddress.trim().isNotEmpty) {
      return request.patientAddress.trim();
    }
    return request.location.trim();
  }

  String get _gpsText {
    final lat = request.gpsLat;
    final lng = request.gpsLng;
    if (lat == null || lng == null) return '';
    return '$lat, $lng';
  }

  String _dateTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

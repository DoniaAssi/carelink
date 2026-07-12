import 'dart:convert';

import 'package:carelink/core/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_localizations.dart';
import '../../../core/locale_controller.dart';
import '../../../services/doctor_service.dart';
import 'doctor_ui_constants.dart';
import 'medical_record_screen.dart';
import 'patient_appointments_screen.dart';

class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final _doctorService = DoctorService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<dynamic> _patients = [];
  String _query = '';

  static const _primary = Color(0xFF0F8B8D);
  Color get _pageColor => DoctorUiConstants.pageColor(context);
  Color get _textDark => DoctorUiConstants.inkColor(context);
  Color get _textMuted => DoctorUiConstants.mutedColor(context);

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      final patients = await _doctorService.getPatients(doctorId);

      if (mounted) {
        setState(() {
          _patients = patients;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.dxError(e))));
    }
  }

  List<dynamic> get _filteredPatients {
    final term = _query.trim().toLowerCase();
    if (term.isEmpty) return _patients;

    return _patients.where((patient) {
      final item = _mapOf(patient);
      final searchable = [
        item['patientName'],
        item['patientEmail'],
        item['patientPhone'],
        item['gender'],
        item['addressText'],
        item['location'],
        item['address'],
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
      return searchable.contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DoctorTypographyScope(
      child: ListenableBuilder(
        listenable: localeController,
        builder: (context, _) {
          return Directionality(
            textDirection: localeController.isDoctorArabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Scaffold(
              backgroundColor: _pageColor,
              appBar: AppBar(
                backgroundColor: _pageColor,
                surfaceTintColor: _pageColor,
                elevation: 0,
                centerTitle: true,
                leading: Navigator.canPop(context)
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: _primary,
                        onPressed: () => Navigator.maybePop(context),
                      )
                    : null,
                title: Text(
                  context.dx('Patients'),
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              body: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: _loadPatients,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                28,
                              ),
                              children: [
                                _searchBox(),
                                const SizedBox(height: 14),
                                _summaryCard(),
                                const SizedBox(height: 14),
                                if (_filteredPatients.isEmpty)
                                  _emptyState()
                                else
                                  ..._filteredPatients.map(_patientCard),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      decoration: _cardDecoration(radius: 22, opacity: 0.035),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: context.dtr('doctor.patients.search'),
          hintStyle: TextStyle(color: _textMuted, fontWeight: FontWeight.w600),
          prefixIcon: Icon(Icons.search_rounded, color: _textMuted),
          suffixIcon: _query.isEmpty
              ? IconButton(
                  tooltip: context.dx('Filter'),
                  onPressed: () {},
                  icon: const Icon(Icons.filter_alt_outlined, color: _primary),
                )
              : IconButton(
                  tooltip: context.dx('Clear'),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: Icon(Icons.close_rounded, color: _textMuted),
                ),
          filled: true,
          fillColor: DoctorUiConstants.surfaceColor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: _primary, width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: _cardDecoration(radius: 20, opacity: 0.03),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.dx('Total Patients'),
              style: TextStyle(
                color: _textMuted,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '${_patients.length}',
            style: TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: _cardDecoration(radius: 24, opacity: 0.04),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded, color: _primary),
          ),
          const SizedBox(height: 18),
          Text(
            context.dtr('doctor.patients.empty'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _patientCard(dynamic rawPatient) {
    final patient = _mapOf(rawPatient);
    final patientId = _text(patient['patientUserId']);
    final patientName = _text(patient['patientName']) ?? 'Patient';
    final location = _locationText(patient);
    final totalVisits = _toInt(patient['totalVisits']);
    final nextVisit = _formatDate(_text(patient['nextVisit']));
    final imageUrl =
        profileImageUrlFromMap(patient) ??
        _text(patient['patientImageUrl']) ??
        _text(patient['profileImageUrl']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecoration(radius: 24, opacity: 0.04),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: patientId == null ? null : () => _openPatientDetails(patient),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
            child: Row(
              children: [
                profileAvatarOrPlaceholder(
                  imageUrl: imageUrl,
                  size: 68,
                  placeholderColor: _primary,
                  placeholderIcon: Icons.person_rounded,
                  iconSize: 36,
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
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: _textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              location ?? context.dtr('doctor.common.notSet'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 14,
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
                    _visitBadge(totalVisits),
                    const SizedBox(height: 12),
                    Text(
                      'Next: ${nextVisit ?? context.dtr('doctor.common.notSet')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF344054),
                  size: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _visitBadge(int totalVisits) {
    final label = totalVisits == 1 ? '1 Visit' : '$totalVisits Visits';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F8EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color(0xFF079455),
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _openPatientDetails(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPatientDetailsScreen(patient: patient),
      ),
    );
  }

  BoxDecoration _cardDecoration({
    required double radius,
    double opacity = 0.05,
  }) {
    return BoxDecoration(
      color: DoctorUiConstants.surfaceColor(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: DoctorUiConstants.borderColor(context)),
      boxShadow: [
        BoxShadow(
          color: DoctorUiConstants.shadowColor(context, opacity),
          blurRadius: 24,
          spreadRadius: -10,
          offset: const Offset(0, 14),
        ),
      ],
    );
  }
}

class DoctorPatientDetailsScreen extends StatefulWidget {
  const DoctorPatientDetailsScreen({super.key, required this.patient});

  final Map<String, dynamic> patient;

  @override
  State<DoctorPatientDetailsScreen> createState() =>
      _DoctorPatientDetailsScreenState();
}

class _DoctorPatientDetailsScreenState
    extends State<DoctorPatientDetailsScreen> {
  final _doctorService = DoctorService();

  Map<String, dynamic> _record = {};

  static const _primary = Color(0xFF0F8B8D);
  Color get _pageColor => DoctorUiConstants.pageColor(context);
  Color get _textDark => DoctorUiConstants.inkColor(context);
  Color get _textMuted => DoctorUiConstants.mutedColor(context);

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  Future<void> _loadRecord() async {
    final patientId = _patientId;
    if (patientId.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      final record = await _doctorService.getPatientMedicalRecord(
        patientId,
        doctorId: doctorId,
      );
      if (!mounted) return;
      setState(() {
        _record = record;
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  String get _patientId => _text(widget.patient['patientUserId']) ?? '';

  @override
  Widget build(BuildContext context) {
    return DoctorTypographyScope(
      child: ListenableBuilder(
        listenable: localeController,
        builder: (context, _) {
          return Directionality(
            textDirection: localeController.isDoctorArabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Scaffold(
              backgroundColor: _pageColor,
              appBar: AppBar(
                backgroundColor: _pageColor,
                surfaceTintColor: _pageColor,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: _primary,
                  onPressed: () => Navigator.maybePop(context),
                ),
                title: Text(
                  context.dx('Patient Details'),
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert_rounded, color: _primary),
                  ),
                ],
              ),
              body: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      children: [
                        _headerCard(),
                        const SizedBox(height: 18),
                        _statsCard(),
                        const SizedBox(height: 20),
                        _actionCard(
                          icon: Icons.calendar_month_outlined,
                          title: context.dx('Appointments'),
                          subtitle: context.dx('View & manage appointments'),
                          onTap: _openAppointments,
                        ),
                        _actionCard(
                          icon: Icons.medical_services_outlined,
                          title: context.dx('Medical Records'),
                          subtitle: context.dx(
                            'View medical history and documents',
                          ),
                          onTap: _openMedicalRecord,
                        ),
                        _actionCard(
                          icon: Icons.medical_information_outlined,
                          title: context.dx('Visits History'),
                          subtitle: context.dx('View all past visits'),
                          onTap: _openVisitHistory,
                        ),
                        _actionCard(
                          icon: Icons.note_alt_outlined,
                          title: context.dx('Notes'),
                          subtitle: context.dx('View patient notes'),
                          onTap: _openNotes,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _headerCard() {
    final patientName = _text(widget.patient['patientName']) ?? 'Patient';
    final age = _ageText({...widget.patient, ..._record});
    final gender =
        _text(_record['gender']) ??
        _text(widget.patient['gender']) ??
        _text(widget.patient['patientGender']);
    final location = _locationText({...widget.patient, ..._record});
    final phone = _text(widget.patient['patientPhone']);
    final imageUrl =
        profileImageUrlFromMap(widget.patient) ??
        profileImageUrlFromMap(_record) ??
        _text(widget.patient['patientImageUrl']) ??
        _text(widget.patient['profileImageUrl']);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(radius: 24, opacity: 0.04),
      child: Row(
        children: [
          profileAvatarOrPlaceholder(
            imageUrl: imageUrl,
            size: 124,
            placeholderColor: _primary,
            placeholderIcon: Icons.person_rounded,
            iconSize: 62,
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 27,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _joinAvailable([age, gender]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _iconLine(
                  Icons.location_on_outlined,
                  location ?? context.dtr('doctor.common.notSet'),
                  _primary,
                ),
                const SizedBox(height: 10),
                _iconLine(
                  Icons.phone_rounded,
                  phone ?? context.dtr('doctor.common.notSet'),
                  _textMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard() {
    final visits = _toInt(widget.patient['totalVisits']);
    final nextVisit =
        _formatDate(_text(widget.patient['nextVisit'])) ??
        context.dtr('doctor.common.notSet');
    final lastVisit =
        _formatDate(_text(widget.patient['lastVisit'])) ??
        context.dtr('doctor.common.notSet');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 22),
      decoration: _cardDecoration(radius: 24, opacity: 0.04),
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              icon: Icons.assignment_outlined,
              value: '$visits',
              label: context.dx(visits == 1 ? 'Visit' : 'Visits'),
            ),
          ),
          _divider(),
          Expanded(
            child: _statItem(
              icon: Icons.calendar_month_outlined,
              value: nextVisit,
              label: context.dx('Next Visit'),
            ),
          ),
          _divider(),
          Expanded(
            child: _statItem(
              icon: Icons.access_time_rounded,
              value: lastVisit,
              label: context.dx('Last Visit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: _primary, size: 34),
        const SizedBox(height: 14),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _textDark,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _textMuted,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _cardDecoration(radius: 24, opacity: 0.035),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Row(
              children: [
                Icon(icon, color: _primary, size: 42),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF344054),
                  size: 34,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconLine(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textMuted,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 92,
      color: Colors.black.withValues(alpha: 0.08),
    );
  }

  void _openAppointments() {
    if (_patientId.isEmpty) return;
    final patientName = _text(widget.patient['patientName']) ?? 'Patient';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPatientAppointmentsScreen(
          patientId: _patientId,
          patientName: patientName,
        ),
      ),
    );
  }

  void _openMedicalRecord() {
    if (_patientId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicalRecordScreen(patientId: _patientId),
      ),
    );
  }

  void _openVisitHistory() {
    if (_patientId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorVisitHistoryScreen(patientId: _patientId),
      ),
    );
  }

  void _openNotes() {
    if (_patientId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPatientNotesScreen(patientId: _patientId),
      ),
    );
  }

  BoxDecoration _cardDecoration({
    required double radius,
    double opacity = 0.05,
  }) {
    return BoxDecoration(
      color: DoctorUiConstants.surfaceColor(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: DoctorUiConstants.borderColor(context)),
      boxShadow: [
        BoxShadow(
          color: DoctorUiConstants.shadowColor(context, opacity),
          blurRadius: 24,
          spreadRadius: -10,
          offset: const Offset(0, 14),
        ),
      ],
    );
  }
}

class DoctorPatientNotesScreen extends StatefulWidget {
  const DoctorPatientNotesScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<DoctorPatientNotesScreen> createState() =>
      _DoctorPatientNotesScreenState();
}

class _DoctorPatientNotesScreenState extends State<DoctorPatientNotesScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  List<dynamic> _notes = [];

  static const _primary = Color(0xFF0F8B8D);
  Color get _textDark => DoctorUiConstants.inkColor(context);
  Color get _textMuted => DoctorUiConstants.mutedColor(context);

  String _localNotesKey(String doctorId) =>
      'doctor_patient_notes_${doctorId}_${widget.patientId}';

  List<Map<String, dynamic>> _localNotes(
    SharedPreferences preferences,
    String doctorId,
  ) {
    final encoded = preferences.getString(_localNotesKey(doctorId));
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      final record = await _doctorService.getPatientMedicalRecord(
        widget.patientId,
        doctorId: doctorId,
      );
      final savedLocally = _localNotes(prefs, doctorId);
      if (!mounted) return;
      setState(() {
        _notes = [...savedLocally, ..._listOf(record['clinicalNotes'])];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.dxError(e))));
    }
  }

  Future<void> _showAddNoteDialog() async {
    final formKey = GlobalKey<FormState>();
    var draftNote = '';
    final noteText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.dx('Add Note')),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            minLines: 4,
            maxLines: 7,
            maxLength: 1000,
            onChanged: (value) => draftNote = value,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Enter patient note...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Please enter a note.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.dx('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, draftNote.trim());
            },
            style: FilledButton.styleFrom(backgroundColor: _primary),
            child: Text(context.dx('Save')),
          ),
        ],
      ),
    );
    if (noteText == null || noteText.isEmpty) return;

    final preferences = await SharedPreferences.getInstance();
    final doctorId = preferences.getString('doctor_userId') ?? '';
    final doctorName = preferences.getString('doctor_fullName') ?? 'Doctor';
    final note = <String, dynamic>{
      'noteId': 'local_${DateTime.now().microsecondsSinceEpoch}',
      'noteText': noteText,
      'authorName': doctorName,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'isLocal': true,
    };
    final savedNotes = _localNotes(preferences, doctorId)..insert(0, note);
    await preferences.setString(
      _localNotesKey(doctorId),
      jsonEncode(savedNotes),
    );

    if (!mounted) return;
    setState(() => _notes.insert(0, note));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.dx('Note saved successfully.')),
        backgroundColor: _primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DoctorTypographyScope(
      child: _DoctorDetailScaffold(
        title: context.dx('Notes'),
        action: Container(
          margin: const EdgeInsetsDirectional.only(end: 12),
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: _primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: _showAddNoteDialog,
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadNotes,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  children: _notes.isEmpty
                      ? [
                          _emptyState(
                            Icons.note_alt_outlined,
                            context.dx('No notes yet'),
                          ),
                        ]
                      : _notes.map(_noteCard).toList(),
                ),
              ),
      ),
    );
  }

  Widget _noteCard(dynamic rawNote) {
    final note = _mapOf(rawNote);
    final author = _text(note['authorName']) ?? _text(note['doctorName']);
    final date = _formatDate(
      _text(note['createdAt']) ?? _text(note['created_at']),
    );
    final content =
        _text(note['noteText']) ??
        _text(note['note']) ??
        _text(note['description']) ??
        _text(note['notes']);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 20),
      decoration: _softCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.assignment_outlined, color: _primary, size: 34),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date ?? context.dtr('doctor.common.notSet'),
                            style: TextStyle(
                              color: _textDark,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            author ?? context.dtr('doctor.common.notSet'),
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.more_horiz_rounded, color: _textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.black.withValues(alpha: 0.08)),
                const SizedBox(height: 16),
                Text(
                  content ?? context.dtr('doctor.common.notSet'),
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorVisitHistoryScreen extends StatefulWidget {
  const DoctorVisitHistoryScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<DoctorVisitHistoryScreen> createState() =>
      _DoctorVisitHistoryScreenState();
}

class _DoctorVisitHistoryScreenState extends State<DoctorVisitHistoryScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  List<dynamic> _visits = [];

  static const _primary = Color(0xFF0F8B8D);
  Color get _textDark => DoctorUiConstants.inkColor(context);
  Color get _textMuted => DoctorUiConstants.mutedColor(context);

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      final record = await _doctorService.getPatientMedicalRecord(
        widget.patientId,
        doctorId: doctorId,
      );
      if (!mounted) return;
      setState(() {
        _visits = _listOf(record['visitReports']);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.dxError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DoctorTypographyScope(
      child: _DoctorDetailScaffold(
        title: context.dx('Visit History'),
        action: IconButton(
          icon: const Icon(
            Icons.filter_alt_outlined,
            color: _primary,
            size: 30,
          ),
          onPressed: () {},
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadVisits,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  children: _visits.isEmpty
                      ? [
                          _emptyState(
                            Icons.medical_information_outlined,
                            'No visit history yet',
                          ),
                        ]
                      : [
                          Stack(
                            children: [
                              PositionedDirectional(
                                start: 28,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 1.2,
                                  color: Colors.black.withValues(alpha: 0.12),
                                ),
                              ),
                              Column(
                                children: _visits
                                    .map(_visitTimelineItem)
                                    .toList(),
                              ),
                            ],
                          ),
                        ],
                ),
              ),
      ),
    );
  }

  Widget _visitTimelineItem(dynamic rawVisit) {
    final visit = _mapOf(rawVisit);
    final dateTime =
        _text(visit['visit_date']) ??
        _text(visit['created_at']) ??
        _text(visit['createdAt']);
    final title =
        _text(visit['title']) ??
        _text(visit['diagnosis']) ??
        _text(visit['serviceType']) ??
        'Visit report';
    final doctorName =
        _text(visit['providerName']) ??
        _text(visit['doctorName']) ??
        _text(visit['authorName']);
    final description =
        _text(visit['notes']) ??
        _text(visit['treatment_plan']) ??
        _text(visit['recommendations']) ??
        _text(visit['diagnosis']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 84),
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary, width: 2),
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 18, 22),
              decoration: _softCardDecoration(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_note_outlined,
                      color: _primary,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDate(dateTime) ??
                                        context.dtr('doctor.common.notSet'),
                                    style: TextStyle(
                                      color: _primary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatTime(dateTime) ??
                                        context.dtr('doctor.common.notSet'),
                                    style: TextStyle(
                                      color: _textMuted,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: TextStyle(
                            color: _textDark,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              color: _textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                doctorName ??
                                    context.dtr('doctor.common.notSet'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          description ?? context.dtr('doctor.common.notSet'),
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 16,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
}

class _DoctorDetailScaffold extends StatelessWidget {
  const _DoctorDetailScaffold({
    required this.title,
    required this.action,
    required this.child,
  });

  final String title;
  final Widget action;
  final Widget child;

  static const _primary = Color(0xFF0F8B8D);

  @override
  Widget build(BuildContext context) {
    final pageColor = DoctorUiConstants.pageColor(context);
    final textDark = DoctorUiConstants.inkColor(context);
    return DoctorTypographyScope(
      child: ListenableBuilder(
        listenable: localeController,
        builder: (context, _) {
          return Directionality(
            textDirection: localeController.isDoctorArabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Scaffold(
              backgroundColor: pageColor,
              appBar: AppBar(
                backgroundColor: pageColor,
                surfaceTintColor: pageColor,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: _primary,
                  onPressed: () => Navigator.maybePop(context),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                actions: [action],
              ),
              body: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

List<dynamic> _listOf(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

BoxDecoration _softCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 24,
        spreadRadius: -10,
        offset: const Offset(0, 14),
      ),
    ],
  );
}

Widget _emptyState(IconData icon, String message) {
  return Container(
    margin: const EdgeInsets.only(top: 32),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
    decoration: _softCardDecoration(),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF0F8B8D).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF0F8B8D), size: 34),
        ),
        const SizedBox(height: 18),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

Map<String, dynamic> _mapOf(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

String? _text(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _ageText(Map<String, dynamic> item) {
  final directAge =
      _text(item['age']) ?? _text(item['patientAge']) ?? _text(item['years']);
  if (directAge != null) return '$directAge years';

  final dob =
      _text(item['dateOfBirth']) ??
      _text(item['birthDate']) ??
      _text(item['patientDateOfBirth']);
  if (dob == null) return null;

  final parsed = DateTime.tryParse(dob);
  if (parsed == null) return null;

  final now = DateTime.now();
  var age = now.year - parsed.year;
  final hadBirthday =
      now.month > parsed.month ||
      (now.month == parsed.month && now.day >= parsed.day);
  if (!hadBirthday) age--;
  return age >= 0 ? '$age years' : null;
}

String? _locationText(Map<String, dynamic> item) {
  return _text(item['visitAddress']) ??
      _text(item['location']) ??
      _text(item['addressText']) ??
      _text(item['address']) ??
      _text(item['patientAddress']) ??
      _text(item['locationNote']);
}

String _joinAvailable(List<String?> values) {
  final available = values.whereType<String>().where((v) => v.isNotEmpty);
  return available.isEmpty ? 'Not set' : available.join(', ');
}

String? _formatDate(String? dateStr) {
  if (dateStr == null) return null;
  final date = DateTime.tryParse(dateStr);
  if (date == null) return dateStr;
  return '${date.day}/${date.month}/${date.year}';
}

String? _formatTime(String? dateStr) {
  if (dateStr == null) return null;
  final date = DateTime.tryParse(dateStr);
  if (date == null) return null;
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

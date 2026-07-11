import 'dart:async';

import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/models/visit_report.dart';
import 'package:carelink/shared/services/report_service.dart';

import 'nurse_ui.dart';

class ReportsListScreen extends NurseVisitReports {
  const ReportsListScreen({super.key, required super.user});
}

class NurseVisitReports extends StatefulWidget {
  const NurseVisitReports({super.key, required this.user});

  final User user;

  @override
  State<NurseVisitReports> createState() => _NurseVisitReportsState();
}

class _NurseVisitReportsState extends State<NurseVisitReports> {
  static Color get _primary => AppColors.primary;
  static Color get _text => NurseUi.text;
  static Color get _muted => NurseUi.muted;

  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;

  bool isLoading = true;
  String selectedFilter = 'All';
  String searchQuery = '';
  List<VisitReport> reports = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadReports();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _loadReports(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => searchQuery = _searchController.text.trim().toLowerCase());
  }

  Future<void> _loadReports({bool silent = false}) async {
    if (!silent && mounted) setState(() => isLoading = true);
    final data = await ReportService.getReports(widget.user.userId);
    if (!mounted) return;
    setState(() {
      reports = data
        ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
      isLoading = false;
    });
  }

  List<VisitReport> get filteredReports {
    return reports.where((report) {
      final status = _statusLabel(report.status);
      final matchesFilter =
          selectedFilter == 'All' ||
          status.toLowerCase() == selectedFilter.toLowerCase();
      if (!matchesFilter) return false;
      if (searchQuery.isEmpty) return true;
      final searchText =
          '${report.patientName} ${report.serviceType} ${report.status}'
              .toLowerCase();
      return searchText.contains(searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Material(
        color: NurseUi.background,
        child: SafeArea(
          child: isLoading
              ? Center(child: CircularProgressIndicator(color: _primary))
              : RefreshIndicator(
                  color: _primary,
                  onRefresh: _loadReports,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      _searchBox(),
                      const SizedBox(height: 14),
                      _filterTabs(),
                      const SizedBox(height: 16),
                      if (filteredReports.isEmpty)
                        _emptyState()
                      else ...[
                        for (final report in filteredReports)
                          _reportCard(report),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            'All reports loaded',
                            style: TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
        Expanded(
          child: Text(
            'Reports',
            style: TextStyle(
              color: _text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Filter',
          onPressed: () {},
          icon: Icon(Icons.filter_list_rounded, color: _primary),
        ),
        NurseModeControls(providerUserId: widget.user.userId),
      ],
    );
  }

  Widget _searchBox() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _shadow,
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: NurseUi.t('Search reports...'),
                isDense: true,
              ),
              style: TextStyle(color: _text, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTabs() {
    final filters = ['All', 'Completed', 'In Progress', 'Draft'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            _filterChip(filter),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String filter) {
    final selected = selectedFilter == filter;
    final count = filter == 'All'
        ? reports.length
        : reports.where((report) => _statusKey(report.status) == filter).length;
    return ChoiceChip(
      label: Text('${NurseUi.t(filter)} ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => selectedFilter = filter),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: _primary,
      backgroundColor: NurseUi.surface,
      side: BorderSide(color: selected ? _primary : NurseUi.border),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _text,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _reportCard(VisitReport report) {
    final patient = _patientName(report);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _shadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportDetailsScreen(report: report),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: const Color(0xFFDDF2EF),
                  child: Text(
                    _initial(patient),
                    style: TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _serviceType(report),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: _muted,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _dateTime(report.scheduledDate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusBadge(report.status),
                    const SizedBox(height: 14),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: _primary,
                      size: 16,
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

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _shadow,
      ),
      child: Center(
        child: Text(
          NurseUi.t('No reports available'),
          style: TextStyle(color: _muted, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  List<BoxShadow> get _shadow => NurseUi.softShadow;
}

class ReportDetailsScreen extends StatelessWidget {
  const ReportDetailsScreen({super.key, required this.report});

  static Color get _background => NurseUi.background;
  static Color get _primary => AppColors.primary;
  static const Color _success = Color(0xFF22C55E);
  static Color get _text => NurseUi.text;
  static Color get _muted => NurseUi.muted;

  final VisitReport report;

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              _topBar(context),
              const SizedBox(height: 16),
              _patientHeaderCard(),
              const SizedBox(height: 14),
              _visitInformationCard(),
              const SizedBox(height: 14),
              _summaryCard(),
              const SizedBox(height: 14),
              _careProvidedGrid(),
              const SizedBox(height: 14),
              _vitalSignsGrid(),
              const SizedBox(height: 18),
              _viewFullReportButton(context),
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
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        ),
        Expanded(
          child: Text(
            NurseUi.t('Report Details'),
            textAlign: TextAlign.center,
            style: TextStyle(color: _text, fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.more_vert_rounded, color: _primary),
        ),
        ...NurseUi.headerActions(),
      ],
    );
  }

  Widget _patientHeaderCard() {
    final patient = _patientName(report);
    return _card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFDDF2EF),
            child: Text(
              _initial(patient),
              style: TextStyle(color: _primary, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _text, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  _serviceType(report),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: _primary, size: 15),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _location(report),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
          ),
          _statusBadge(report.status),
        ],
      ),
    );
  }

  Widget _visitInformationCard() {
    return _sectionCard(
      title: NurseUi.t('Visit Information'),
      children: [
        _infoRow(
          Icons.calendar_today_rounded,
          NurseUi.t('Date & Time'),
          _dateTime(report.scheduledDate),
        ),
        _infoRow(
          Icons.timer_outlined,
          NurseUi.t('Duration'),
          _duration(report),
        ),
        _infoRow(
          Icons.local_hospital_outlined,
          NurseUi.t('Visit Type'),
          _serviceType(report),
        ),
        _infoRow(
          Icons.play_arrow_rounded,
          NurseUi.t('Started At'),
          _time(report.createdAt),
        ),
        _infoRow(
          Icons.check_circle_outline,
          NurseUi.t('Completed At'),
          _time(report.updatedAt),
        ),
      ],
    );
  }

  Widget _summaryCard() {
    final summary = report.visitSummary.trim().isEmpty
        ? NurseUi.t('Not recorded')
        : report.visitSummary.trim();
    return _sectionCard(
      title: NurseUi.t('Summary'),
      children: [
        Text(
          summary,
          style: TextStyle(
            color: _text,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _careProvidedGrid() {
    final items = [
      _CareItem(
        NurseUi.t('Medication\nAdministration'),
        Icons.medication_outlined,
        report.medications,
      ),
      _CareItem(
        NurseUi.t('Wound Care'),
        Icons.healing_rounded,
        report.observations,
      ),
      _CareItem(
        NurseUi.t('Vital Signs\nMonitoring'),
        Icons.favorite_outline,
        report.vitalSigns,
      ),
      _CareItem(
        NurseUi.t('Personal Care'),
        Icons.person_outline,
        report.visitSummary,
      ),
      _CareItem(
        NurseUi.t('Patient\nEducation'),
        Icons.menu_book_outlined,
        report.recommendations,
      ),
      _CareItem(
        NurseUi.t('IV Support'),
        Icons.invert_colors,
        report.observations,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            NurseUi.t('Care Provided'),
            style: TextStyle(color: _text, fontWeight: FontWeight.w900),
          ),
        ),
        GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.18,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final done = _hasCareData(item.source, item.label);
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _shadow,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          color: done ? _primary : const Color(0xFF9CA3AF),
                          size: 23,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _text,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: done ? _success : const Color(0xFFCBD5E1),
                      size: 16,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _vitalSignsGrid() {
    final vitals = _parseVitals(report.vitalSigns);
    final items = [
      _VitalItem(
        NurseUi.t('Blood Pressure'),
        vitals['blood pressure'] ?? vitals['bp'] ?? NurseUi.t('Not recorded'),
        Icons.monitor_heart_outlined,
      ),
      _VitalItem(
        NurseUi.t('Heart Rate'),
        vitals['heart rate'] ?? vitals['hr'] ?? NurseUi.t('Not recorded'),
        Icons.favorite_border,
      ),
      _VitalItem(
        NurseUi.t('Temperature'),
        vitals['temperature'] ?? vitals['temp'] ?? NurseUi.t('Not recorded'),
        Icons.thermostat,
      ),
      _VitalItem(
        NurseUi.t('Oxygen Saturation'),
        vitals['oxygen saturation'] ??
            vitals['spo2'] ??
            NurseUi.t('Not recorded'),
        Icons.air,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            NurseUi.t('Vital Signs'),
            style: TextStyle(color: _text, fontWeight: FontWeight.w900),
          ),
        ),
        GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.35,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _shadow,
              ),
              child: Row(
                children: [
                  Icon(item.icon, color: _primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _text,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _viewFullReportButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () => _showFullReport(context),
        icon: const Icon(Icons.description_outlined, size: 18),
        label: Text(NurseUi.t('View Full Report')),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  void _showFullReport(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FullReportSheet(report: report),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: _text, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _shadow,
      ),
      child: child,
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value.trim().isEmpty ? NurseUi.t('Not recorded') : value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BoxShadow> get _shadow => NurseUi.softShadow;
}

class _FullReportSheet extends StatelessWidget {
  const _FullReportSheet({required this.report});

  static Color get _primary => AppColors.primary;
  static Color get _text => NurseUi.text;

  final VisitReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: BoxDecoration(
        color: NurseUi.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    NurseUi.t('Full Report'),
                    style: TextStyle(
                      color: _text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                _section(NurseUi.t('Patient'), _patientName(report)),
                _section(NurseUi.t('Service Type'), _serviceType(report)),
                _section(NurseUi.t('Location'), _location(report)),
                _section(
                  NurseUi.t('Date & Time'),
                  _dateTime(report.scheduledDate),
                ),
                _section(NurseUi.t('Duration'), _duration(report)),
                _section(NurseUi.t('Summary'), report.visitSummary),
                _section(NurseUi.t('Vital Signs'), report.vitalSigns),
                _section(NurseUi.t('Medications'), report.medications),
                _section(NurseUi.t('Observations'), report.observations),
                _section(NurseUi.t('Recommendations'), report.recommendations),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: _primary, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            value.trim().isEmpty ? NurseUi.t('Not recorded') : value.trim(),
            style: TextStyle(
              color: _text,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CareItem {
  const _CareItem(this.label, this.icon, this.source);

  final String label;
  final IconData icon;
  final String source;
}

class _VitalItem {
  const _VitalItem(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

Widget _statusBadge(String status) {
  final label = _statusLabel(status);
  final color = _statusColor(label);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
    ),
  );
}

String _statusLabel(String status) {
  return NurseUi.t(_statusKey(status));
}

String _statusKey(String status) {
  final value = status.toLowerCase().trim().replaceAll('_', ' ');
  if (value.contains('progress')) return 'In Progress';
  if (value.contains('draft')) return 'Draft';
  return 'Completed';
}

Color _statusColor(String label) {
  if (label == NurseUi.t('In Progress')) return const Color(0xFF3B82F6);
  if (label == NurseUi.t('Draft')) return const Color(0xFFF59E0B);
  return const Color(0xFF22C55E);
}

String _patientName(VisitReport report) {
  final name = report.patientName.trim();
  if (name.isNotEmpty) return name;
  final id = report.patientId.trim();
  return id.isEmpty ? NurseUi.t('Patient') : '${NurseUi.t('Patient')} $id';
}

String _serviceType(VisitReport report) {
  final value = report.serviceType.trim();
  return value.isEmpty
      ? NurseUi.t('Nursing Care')
      : NurseUi.serviceLabel(value);
}

String _location(VisitReport report) {
  final value = report.location.trim();
  return value.isEmpty ? NurseUi.t('Location not recorded') : value;
}

String _duration(VisitReport report) {
  if (report.durationHours <= 0) return NurseUi.t('Not recorded');
  if (report.durationHours == 1) return '1 ${NurseUi.t('hour')}';
  return '${report.durationHours} ${NurseUi.t('hours')}';
}

String _initial(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return 'P';
  return clean.substring(0, 1).toUpperCase();
}

String _dateTime(DateTime date) {
  return '${NurseUi.formatDate(date)} - ${NurseUi.formatTime(date)}';
}

String _time(DateTime date) {
  return NurseUi.formatTime(date);
}

bool _hasCareData(String source, String label) {
  final text = source.trim().toLowerCase();
  if (text.isEmpty) return false;
  final cleanLabel = label.toLowerCase().replaceAll('\n', ' ');
  final words = cleanLabel.split(' ').where((word) => word.length > 3);
  return words.any(text.contains) || text.length > 8;
}

Map<String, String> _parseVitals(String value) {
  final result = <String, String>{};
  final normalized = value.replaceAll('\n', ';').replaceAll('|', ';');
  for (final part in normalized.split(';')) {
    final clean = part.trim();
    if (clean.isEmpty) continue;
    final separator = clean.contains(':')
        ? ':'
        : clean.contains('=')
        ? '='
        : '';
    if (separator.isEmpty) continue;
    final pieces = clean.split(separator);
    if (pieces.length < 2) continue;
    final key = pieces.first.trim().toLowerCase();
    final val = pieces.sublist(1).join(separator).trim();
    if (key.isNotEmpty && val.isNotEmpty) result[key] = val;
  }
  if (result.isEmpty && value.trim().isNotEmpty) {
    result['blood pressure'] = value.trim();
  }
  return result;
}

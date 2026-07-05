// ignore_for_file: use_null_aware_elements

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/admin/widgets/admin_ui_support.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

class AdminBookingReviewItem {
  const AdminBookingReviewItem({
    required this.id,
    required this.patientName,
    required this.providerName,
    required this.serviceType,
    required this.scheduledAt,
    required this.amount,
    required this.status,
    required this.paymentStatus,
    required this.reason,
    required this.systemNotes,
    this.profileImageUrl,
  });

  final String id;
  final String patientName;
  final String providerName;
  final String serviceType;
  final DateTime? scheduledAt;
  final double amount;
  final AdminBookingReviewStatus status;
  final String paymentStatus;
  final String reason;
  final String systemNotes;
  final String? profileImageUrl;

  factory AdminBookingReviewItem.fromJson(Map<String, dynamic> json) {
    return AdminBookingReviewItem(
      id: _text(json['requestId'] ?? json['id'], fallback: 'booking-review'),
      patientName: _text(json['patientName'], fallback: 'Patient'),
      providerName: _text(json['providerName'], fallback: 'Nurse'),
      serviceType: _text(json['serviceType'], fallback: 'Nursing Service'),
      scheduledAt: DateTime.tryParse(_text(json['scheduledAt'])),
      amount: _num(json['amount']),
      status: _statusFromApi(_text(json['status'])),
      paymentStatus: _text(json['paymentStatus'], fallback: 'Held for review'),
      reason: _text(
        json['reason'],
        fallback: 'This booking needs admin review.',
      ),
      systemNotes: _text(
        json['systemNotes'],
        fallback: 'Funds stay held until the admin decision is saved.',
      ),
      profileImageUrl: _text(json['profileImageUrl'], fallback: ''),
    );
  }

  factory AdminBookingReviewItem.fromAdminRequest(Map<String, dynamic> row) {
    return AdminBookingReviewItem(
      id: _text(row['requestId'], fallback: 'booking-review'),
      patientName: _text(row['patientName'], fallback: 'Patient'),
      providerName: _text(row['providerName'], fallback: 'Nurse'),
      serviceType: _text(row['serviceType'], fallback: 'Nursing Service'),
      scheduledAt: DateTime.tryParse(_text(row['scheduledAt'])),
      amount: _num(row['paidAmount']),
      status: _reviewStatusFor(_text(row['status'])),
      paymentStatus: _text(row['paymentStatus'], fallback: 'Held for review'),
      reason: 'This past nurse booking needs an admin decision.',
      systemNotes: 'Loaded from the current admin dashboard data.',
      profileImageUrl: _text(row['profileImageUrl'], fallback: ''),
    );
  }
}

enum AdminBookingReviewStatus {
  missedAppointment,
  requestExpired,
  waitingCompletion,
  dispute,
  underReview,
}

class AdminBookingReviewScreen extends StatefulWidget {
  const AdminBookingReviewScreen({super.key, this.serviceRequests = const []});

  final List<Map<String, dynamic>> serviceRequests;

  @override
  State<AdminBookingReviewScreen> createState() =>
      _AdminBookingReviewScreenState();
}

class _AdminBookingReviewScreenState extends State<AdminBookingReviewScreen> {
  static const _teal = Color(0xFF039D98);
  static const _darkTeal = Color(0xFF007B78);
  static const _ink = Color(0xFF0D1B2A);
  static const _muted = Color(0xFF6B7C86);
  static const _line = Color(0xFFD8E9E6);

  CarelinkPalette get _palette => CarelinkPalette.of(context);
  Color get _surface => _palette.surface;
  Color get _softSurface => _palette.surfaceSoft;
  Color get _onPrimary => Theme.of(context).colorScheme.onPrimary;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  AdminBookingReviewStatus? _filter;
  int _reviewTab = 0;
  List<AdminBookingReviewItem> _items = [];
  List<Map<String, dynamic>> _refundRequests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<AdminBookingReviewItem> get _visibleItems {
    final filter = _filter;
    if (filter == null) return _items;
    return _items.where((item) => item.status == filter).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        http.get(_uri('/admin/booking-review')),
        http.get(_uri('/admin/refund-requests')),
      ]);
      final response = responses[0];
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      if (responses[1].statusCode < 200 || responses[1].statusCode >= 300) {
        throw Exception(_message(responses[1]));
      }
      final decoded = jsonDecode(response.body);
      final list = decoded is List ? decoded : [];
      final items = list
          .whereType<Map>()
          .map(
            (item) => AdminBookingReviewItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
      final refundDecoded = jsonDecode(responses[1].body);
      final refundRequests = refundDecoded is List
          ? refundDecoded
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _items = items;
        _refundRequests = refundRequests;
      });
    } catch (e) {
      final fallback = _fallbackItems();
      if (!mounted) return;
      setState(() {
        _items = fallback;
        _error = fallback.isEmpty
            ? e.toString().replaceFirst('Exception: ', '')
            : null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AdminBookingReviewItem> _fallbackItems() {
    final now = DateTime.now();
    return widget.serviceRequests
        .where((row) {
          final role = _text(row['providerRole']).toLowerCase();
          final date = DateTime.tryParse(_text(row['scheduledAt']));
          if (role == 'doctor') return false;
          if (date == null || date.isAfter(now)) return false;
          final status = _text(row['status']).toLowerCase();
          return _reviewStatusForNullable(status) != null;
        })
        .map(AdminBookingReviewItem.fromAdminRequest)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: adminUiSettings,
      builder: (context, _) => _buildReviewScreen(context),
    );
  }

  Widget _buildReviewScreen(BuildContext context) {
    final p = _palette;
    return Theme(
      data: adminCareTheme(context),
      child: Directionality(
        textDirection: context.adminTextDirection,
        child: PatientScaffold(
          backgroundColor: p.surface,
          enabled: false,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: RefreshIndicator(
                  color: _teal,
                  onRefresh: _load,
                  child: _loading
                      ? const AdminLoadingState()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                          children: [
                            _topBar(),
                            const SizedBox(height: 10),
                            _reviewTabs(),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              _errorBox(_error!),
                            ],
                            const SizedBox(height: 12),
                            if (_reviewTab == 0) ...[
                              if (_visibleItems.isEmpty)
                                _empty()
                              else
                                ..._visibleItems.map(_bookingCard),
                            ] else ...[
                              _refundSummaryGrid(),
                              const SizedBox(height: 14),
                              if (_refundRequests.isEmpty)
                                const AdminEmptyState(
                                  message: 'No refund requests yet',
                                )
                              else
                                ..._refundRequests.map(_refundRequestCard),
                            ],
                            const SizedBox(height: 6),
                            OutlinedButton(
                              onPressed: _load,
                              child: const AdminLocalizedText('View All'),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              tooltip: context.adminTr('Back'),
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                context.adminBackIcon,
                color: _palette.inkDark,
                size: 23,
              ),
            ),
          ),
          const Align(
            alignment: AlignmentDirectional.centerEnd,
            child: PatientHeaderActions(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 92),
            child: AdminLocalizedText(
              'Booking Review',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _palette.inkDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewTabs() {
    final tabs = [
      ('Under Review', _items.length),
      ('Refund Requests', _refundRequests.length),
    ];
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        for (var index = 0; index < tabs.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _reviewTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: _reviewTab == index ? _teal : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: AdminLocalizedText(
                  tabs[index].$1,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _reviewTab == index ? _teal : _palette.inkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _refundSummaryGrid() {
    int count(String status) => _refundRequests
        .where((item) => _text(item['status']).toLowerCase() == status)
        .length;
    final items = [
      (Icons.schedule_rounded, 'Pending', count('pending'), adminSuccess),
      (
        Icons.hourglass_top_rounded,
        'Under Review',
        count('approved'),
        adminWarning,
      ),
      (
        Icons.check_circle_outline_rounded,
        'Approved',
        count('processed'),
        const Color(0xFF6657D9),
      ),
      (Icons.cancel_outlined, 'Rejected', count('rejected'), adminDanger),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 7,
            mainAxisSpacing: 0,
            childAspectRatio: constraints.maxWidth < 500 ? 1.05 : 1.35,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _palette.stroke),
                boxShadow: _shadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.$1, color: item.$4, size: 19),
                  const SizedBox(height: 3),
                  AdminLocalizedText(
                    '${item.$3}',
                    style: TextStyle(
                      color: _palette.inkDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AdminLocalizedText(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: item.$4,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Kept for the expanded review layout.
  // ignore: unused_element
  Widget _logicNotice() {
    return Container(
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _palette.stroke),
        boxShadow: _shadow,
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, color: _darkTeal, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: AdminLocalizedText(
              'Admin decisions are saved for nurse bookings only. Missed appointments are not treated as patient cancellations.',
              style: TextStyle(
                color: _muted,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _summaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        return GridView.count(
          crossAxisCount: compact ? 1 : 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: compact ? 3.5 : 1.72,
          children: [
            _summaryCard(
              'Under Review',
              _items.length,
              Icons.fact_check_outlined,
            ),
            _summaryCard(
              'Missed',
              _count(AdminBookingReviewStatus.missedAppointment),
              Icons.event_busy_rounded,
            ),
            _summaryCard(
              'Expired',
              _count(AdminBookingReviewStatus.requestExpired),
              Icons.hourglass_empty_rounded,
            ),
            _summaryCard(
              'Disputes',
              _count(AdminBookingReviewStatus.dispute),
              Icons.report_problem_outlined,
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String label, int value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _palette.stroke),
        boxShadow: _shadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _softSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _teal, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AdminLocalizedText(
                  '$value',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                AdminLocalizedText(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _filters() {
    final options = [
      (null, 'All'),
      (AdminBookingReviewStatus.missedAppointment, 'Missed'),
      (AdminBookingReviewStatus.requestExpired, 'Expired'),
      (AdminBookingReviewStatus.waitingCompletion, 'Waiting Completion'),
      (AdminBookingReviewStatus.dispute, 'Disputes'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options) ...[
            _filterChip(option.$1, option.$2),
            SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(AdminBookingReviewStatus? value, String label) {
    final selected = _filter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _teal : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _teal : _line),
        ),
        child: AdminLocalizedText(
          label,
          style: TextStyle(
            color: selected ? _onPrimary : _teal,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _bookingCard(AdminBookingReviewItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _palette.stroke),
        boxShadow: _shadow,
      ),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.ltr,
            children: [
              AdminAvatar(
                data: {'profileImageUrl': item.profileImageUrl},
                name: item.patientName,
                size: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminLocalizedText(
                      item.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _palette.inkDark,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AdminLocalizedText(
                      '${item.serviceType} - ${item.providerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _palette.inkMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(item.status),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            textDirection: TextDirection.ltr,
            children: [
              Icon(Icons.schedule_rounded, color: _teal, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: AdminLocalizedText(
                  _dateTime(item.scheduledAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _palette.inkMuted, fontSize: 9.5),
                ),
              ),
              AdminLocalizedText(
                _money(item.amount),
                style: TextStyle(
                  color: _palette.inkDark,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _saving ? null : () => _openReview(item),
                    child: const AdminLocalizedText('Approve'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _saving ? null : () => _openReview(item),
                    child: const AdminLocalizedText('Details'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(icon, color: _teal, size: 16),
          SizedBox(width: 7),
          AdminLocalizedText(
            label,
            style: TextStyle(
              color: _palette.inkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Spacer(),
          Flexible(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: AdminLocalizedText(
                value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _palette.inkDark,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(AdminBookingReviewStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: AdminLocalizedText(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _openReview(AdminBookingReviewItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.48,
        maxChildSize: 0.94,
        builder: (context, controller) => Container(
          padding: EdgeInsets.fromLTRB(18, 12, 18, 20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _palette.stroke,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              SizedBox(height: 16),
              AdminLocalizedText(
                'Review Details',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12),
              _reviewBlock('Patient', item.patientName),
              _reviewBlock('Nurse', item.providerName),
              _reviewBlock('Service', item.serviceType),
              _reviewBlock('Date & Time', _dateTime(item.scheduledAt)),
              _reviewBlock('Paid Amount', _money(item.amount)),
              _reviewBlock('Reason', item.reason),
              _reviewBlock('System Notes', item.systemNotes),
              SizedBox(height: 16),
              AdminLocalizedText(
                'Admin Decisions',
                style: TextStyle(fontWeight: FontWeight.w900, color: _ink),
              ),
              SizedBox(height: 10),
              _decisionButton(
                item,
                'Confirm Service Completed',
                'Use when the nurse delivered the service but the status was not updated.',
                'The booking will become Completed and the existing finance ledger will handle the split.',
                'confirm_completed',
                Icons.verified_rounded,
              ),
              _decisionButton(
                item,
                'Full Refund to Patient',
                'Use when the nurse did not approve or did not attend.',
                'Payment will be marked refunded. This is not a patient cancellation.',
                'full_refund',
                Icons.replay_rounded,
              ),
              _decisionButton(
                item,
                'Partial Refund',
                'Use when admin decides the patient should receive part of the payment back.',
                'Default is 80% refund, with the retained amount split between nurse and admin.',
                'partial_refund',
                Icons.price_change_outlined,
              ),
              _decisionButton(
                item,
                'Deny Refund',
                'Use when patient no-show is confirmed or no valid refund reason exists.',
                'The review will be resolved and no automatic refund will be made.',
                'deny_refund',
                Icons.block_rounded,
              ),
              _decisionButton(
                item,
                'Move to Dispute',
                'Use when patient and nurse reports conflict.',
                'Funds remain held while the admin continues the dispute review.',
                'mark_dispute',
                Icons.gavel_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewBlock(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _palette.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminLocalizedText(
            label,
            style: TextStyle(
              color: _palette.inkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          AdminLocalizedText(
            value,
            style: TextStyle(
              color: _palette.inkDark,
              height: 1.35,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _decisionButton(
    AdminBookingReviewItem item,
    String label,
    String description,
    String effect,
    String decision,
    IconData icon,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _saving
            ? null
            : () =>
                  _confirmDecision(item, label, description, effect, decision),
        child: Container(
          padding: EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _palette.stroke),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: _darkTeal),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminLocalizedText(
                      label,
                      style: TextStyle(
                        color: _darkTeal,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    AdminLocalizedText(
                      description,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: _darkTeal),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDecision(
    AdminBookingReviewItem item,
    String label,
    String description,
    String effect,
    String decision,
  ) async {
    final refundController = TextEditingController(
      text: decision == 'partial_refund' && item.amount > 0
          ? (item.amount * 0.8).toStringAsFixed(2)
          : '',
    );
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: AdminLocalizedText(label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reviewBlock('When to use it', description),
            _reviewBlock('What will happen', effect),
            if (decision == 'partial_refund')
              TextField(
                controller: refundController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.adminTr('Refund amount'),
                  prefixText: 'ILS ',
                ),
              ),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.adminTr('Admin notes (optional)'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: AdminLocalizedText('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _teal),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: AdminLocalizedText('Apply Decision'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      refundController.dispose();
      notesController.dispose();
      return;
    }
    final refundText = refundController.text.trim();
    final notes = notesController.text.trim();
    refundController.dispose();
    notesController.dispose();

    await _applyDecision(
      item: item,
      decision: decision,
      notes: notes,
      refundAmount: refundText.isEmpty ? null : double.tryParse(refundText),
    );
  }

  Future<void> _applyDecision({
    required AdminBookingReviewItem item,
    required String decision,
    String? notes,
    double? refundAmount,
  }) async {
    setState(() => _saving = true);
    try {
      final response = await http.put(
        _uri('/admin/booking-review/${Uri.encodeComponent(item.id)}/decision'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'decision': decision,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          if (refundAmount != null) 'refundAmount': refundAmount,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AdminLocalizedText(
            'Decision saved: ${decision.replaceAll('_', ' ')}',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AdminLocalizedText(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _refundRequestCard(Map<String, dynamic> request) {
    final status = _text(request['status'], fallback: 'pending');
    final patient = _text(request['patientName'], fallback: 'Patient');
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showRefundRequestDetails(request),
      child: Container(
        constraints: const BoxConstraints(minHeight: 124),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _palette.stroke),
          boxShadow: _shadow,
        ),
        child: Row(
          children: [
            AdminAvatar(data: request, name: patient, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AdminLocalizedText(
                    patient,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _palette.inkDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AdminLocalizedText(
                    _text(request['providerName'], fallback: 'Provider'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _palette.inkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: _palette.inkMuted,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: AdminLocalizedText(
                          _dateTime(
                            DateTime.tryParse(_text(request['scheduledAt'])),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _palette.inkMuted,
                            fontSize: 9.5,
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _refundStatusBadge(status),
                const SizedBox(height: 10),
                AdminLocalizedText(
                  _money(_num(request['refundAmount'])),
                  style: TextStyle(
                    color: _palette.inkDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AdminLocalizedText(
                      'View Details',
                      style: TextStyle(
                        color: _teal,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      context.adminTextDirection == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: _teal,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _refundStatusBadge(String status) {
    return AdminStatusBadge(status: status);
  }

  // Kept for the wide, expanded refund presentation.
  // ignore: unused_element
  Widget _refundDetails(Map<String, dynamic> request) {
    return Column(
      children: [
        _infoRow(
          Icons.person_outline_rounded,
          'Provider Name',
          _text(request['providerName'], fallback: 'Provider'),
        ),
        _infoRow(
          Icons.event_outlined,
          'Booking Date',
          _dateTime(DateTime.tryParse(_text(request['scheduledAt']))),
        ),
        _infoRow(
          Icons.cancel_schedule_send_outlined,
          'Cancellation Time',
          _dateTime(DateTime.tryParse(_text(request['createdAt']))),
        ),
        _infoRow(
          Icons.credit_card_rounded,
          'Payment Method',
          _paymentMethodLabel(request['paymentMethod']),
        ),
        _infoRow(
          Icons.payments_outlined,
          'Total paid',
          _money(_num(request['totalPaid'])),
        ),
        _infoRow(
          Icons.replay_rounded,
          'Refund',
          _money(_num(request['refundAmount'])),
        ),
        _infoRow(
          Icons.medical_services_outlined,
          'Provider compensation',
          _money(_num(request['providerCompensation'])),
        ),
        _infoRow(
          Icons.account_balance_outlined,
          'Platform',
          _money(_num(request['platformFee'])),
        ),
        _infoRow(
          Icons.percent_rounded,
          'Refund percentage',
          '${_num(request['refundPercentage']).toStringAsFixed(0)}%',
        ),
      ],
    );
  }

  Widget _refundReason(Map<String, dynamic> request) {
    final status = _text(request['status']).toLowerCase();
    final processed = status == 'processed' || status == 'approved';
    final message = processed
        ? 'Refund request processed successfully.'
        : status == 'rejected'
        ? _text(request['adminNote'], fallback: _text(request['reason']))
        : _text(request['reason']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _palette.stroke),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            processed ? Icons.check_circle_rounded : Icons.info_rounded,
            color: _teal,
            size: 21,
          ),
          const SizedBox(height: 10),
          AdminLocalizedText(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _palette.inkDark,
              height: 1.45,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRefundRequestDetails(Map<String, dynamic> request) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .78,
          minChildSize: .45,
          maxChildSize: .94,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: context.adminTr('Close'),
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: Icon(Icons.close_rounded, color: _palette.inkDark),
                  ),
                  Expanded(
                    child: AdminLocalizedText(
                      'Refund Request Details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _palette.inkDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _softSurface,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: _teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _softSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _palette.stroke),
                ),
                child: Row(
                  children: [
                    AdminAvatar(
                      data: request,
                      name: _text(request['patientName'], fallback: 'Patient'),
                      size: 58,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminLocalizedText(
                            _text(request['patientName'], fallback: 'Patient'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _palette.inkDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AdminLocalizedText(
                            '${_text(request['serviceType'], fallback: 'Service')} - ${_text(request['providerName'], fallback: 'Provider')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _palette.inkMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _refundStatusBadge(
                      _text(request['status'], fallback: 'pending'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AdminLocalizedText(
                'Booking Information',
                style: TextStyle(
                  color: _palette.inkDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _refundBookingGrid(request),
              const SizedBox(height: 16),
              AdminLocalizedText(
                'Financial Summary',
                style: TextStyle(
                  color: _palette.inkDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _refundFinancialGrid(request),
              _reviewBlock('Reason', _text(request['reason'])),
              _reviewBlock('Refund Explanation', _text(request['reason'])),
              if (_text(request['adminNote']).isNotEmpty)
                _reviewBlock('Admin Note', _text(request['adminNote'])),
              const SizedBox(height: 14),
              _refundReason(request),
              if (_text(request['status'], fallback: 'pending') ==
                  'pending') ...[
                const SizedBox(height: 16),
                AdminResponsiveActions(
                  children: [
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: adminDanger,
                          side: const BorderSide(color: adminDanger),
                        ),
                        onPressed: _saving
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _reviewRefundRequest(request, 'rejected');
                              },
                        icon: const Icon(Icons.close_rounded),
                        label: const AdminLocalizedText('Reject'),
                      ),
                    ),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _reviewRefundRequest(request, 'approved');
                              },
                        icon: const Icon(Icons.check_rounded),
                        label: const AdminLocalizedText('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _refundBookingGrid(Map<String, dynamic> request) {
    return _refundSheetGrid([
      (
        Icons.person_outline_rounded,
        'Provider Name',
        _text(request['providerName'], fallback: 'Provider'),
      ),
      (
        Icons.medical_services_outlined,
        'Service Type',
        _text(request['serviceType'], fallback: 'Service'),
      ),
      (
        Icons.event_outlined,
        'Booking Date',
        _dateTime(DateTime.tryParse(_text(request['scheduledAt']))),
      ),
      (
        Icons.timer_outlined,
        'Cancellation Time',
        _dateTime(DateTime.tryParse(_text(request['createdAt']))),
      ),
      (
        Icons.credit_card_rounded,
        'Payment Method',
        _paymentMethodLabel(request['paymentMethod']),
      ),
      (
        Icons.info_outline_rounded,
        'Refund Status',
        _text(request['status'], fallback: 'pending'),
      ),
    ]);
  }

  Widget _refundFinancialGrid(Map<String, dynamic> request) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _palette.stroke),
      ),
      child: _refundSheetGrid([
        (
          Icons.payments_outlined,
          'Total Paid',
          _money(_num(request['totalPaid'])),
        ),
        (
          Icons.currency_exchange_rounded,
          'Refund Amount',
          _money(_num(request['refundAmount'])),
        ),
        (
          Icons.medical_services_outlined,
          'Provider Compensation',
          _money(_num(request['providerCompensation'])),
        ),
        (
          Icons.account_balance_outlined,
          'Platform Fee',
          _money(_num(request['platformFee'])),
        ),
        (
          Icons.percent_rounded,
          'Refund Percentage',
          '${_num(request['refundPercentage']).toStringAsFixed(0)}%',
        ),
      ]),
    );
  }

  Widget _refundSheetGrid(List<(IconData, String, String)> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        final width = columns == 2
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _palette.stroke),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _softSurface,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(item.$1, color: _teal, size: 19),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AdminLocalizedText(
                              item.$2,
                              style: TextStyle(
                                color: _palette.inkMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            AdminLocalizedText(
                              item.$3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _palette.inkDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
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
        );
      },
    );
  }

  Future<void> _reviewRefundRequest(
    Map<String, dynamic> request,
    String decision,
  ) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AdminLocalizedText(
          decision == 'approved' ? 'Approve Refund' : 'Reject Refund',
        ),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.adminTr('Admin notes (optional)'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: AdminLocalizedText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: AdminLocalizedText('Apply Decision'),
          ),
        ],
      ),
    );
    final adminNote = note.text.trim();
    note.dispose();
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      final response = await http.put(
        _uri(
          '/admin/refund-requests/${Uri.encodeComponent(_text(request['id']))}/decision',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'decision': decision,
          if (adminNote.isNotEmpty) 'adminNote': adminNote,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _empty() {
    return const AdminEmptyState(
      message: 'No nurse bookings need admin review right now.',
      icon: Icons.event_available_rounded,
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _palette.isDark ? Color(0xFF3A1722) : Color(0xFFFFE8EE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: AdminLocalizedText(
        context.adminError(message),
        style: TextStyle(color: Color(0xFFD83A59), fontWeight: FontWeight.w800),
      ),
    );
  }

  int _count(AdminBookingReviewStatus status) {
    return _items.where((item) => item.status == status).length;
  }

  String _statusLabel(AdminBookingReviewStatus status) {
    switch (status) {
      case AdminBookingReviewStatus.missedAppointment:
        return 'Missed';
      case AdminBookingReviewStatus.requestExpired:
        return 'Expired';
      case AdminBookingReviewStatus.waitingCompletion:
        return 'Waiting';
      case AdminBookingReviewStatus.dispute:
        return 'Dispute';
      case AdminBookingReviewStatus.underReview:
        return 'Review';
    }
  }

  Color _statusColor(AdminBookingReviewStatus status) {
    switch (status) {
      case AdminBookingReviewStatus.missedAppointment:
        return Color(0xFFE07A1F);
      case AdminBookingReviewStatus.requestExpired:
        return Color(0xFFD83A59);
      case AdminBookingReviewStatus.waitingCompletion:
        return Color(0xFF1D7BC7);
      case AdminBookingReviewStatus.dispute:
        return Color(0xFF8A5BC9);
      case AdminBookingReviewStatus.underReview:
        return _darkTeal;
    }
  }

  String _dateTime(DateTime? date) {
    if (date == null) return 'Not scheduled';
    if (context.adminTextDirection == TextDirection.rtl) {
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.year}/$month/$day - $hour:$minute';
    }
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
    return '${date.day} ${months[date.month - 1]} ${date.year} - ${_time(date)}';
  }

  String _time(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _money(double amount) {
    final text = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return context.adminTextDirection == TextDirection.rtl
        ? '$text ش.ج'
        : '$text ILS';
  }

  String _paymentMethodLabel(dynamic value) {
    final method = _text(value).toLowerCase();
    if (method.isEmpty ||
        method == 'mock_card' ||
        method == 'mock card' ||
        method == 'card') {
      return 'Original payment method';
    }
    return _text(value);
  }

  Uri _uri(String path) => Uri.parse('${ApiService.baseUrl}$path');

  String _message(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return response.body.isEmpty ? 'Request failed' : response.body;
  }
}

AdminBookingReviewStatus _statusFromApi(String value) {
  switch (value.toLowerCase()) {
    case 'missed_appointment':
    case 'no_show':
      return AdminBookingReviewStatus.missedAppointment;
    case 'request_expired':
      return AdminBookingReviewStatus.requestExpired;
    case 'waiting_completion':
      return AdminBookingReviewStatus.waitingCompletion;
    case 'dispute':
      return AdminBookingReviewStatus.dispute;
    default:
      return AdminBookingReviewStatus.underReview;
  }
}

AdminBookingReviewStatus _reviewStatusFor(String value) {
  return _reviewStatusForNullable(value) ??
      AdminBookingReviewStatus.underReview;
}

AdminBookingReviewStatus? _reviewStatusForNullable(String value) {
  switch (value.toLowerCase()) {
    case 'pending':
    case 'pending_provider_approval':
    case 'pending_payment':
    case 'payment_pending':
      return AdminBookingReviewStatus.requestExpired;
    case 'confirmed':
    case 'upcoming':
    case 'accepted':
      return AdminBookingReviewStatus.missedAppointment;
    case 'in_progress':
    case 'waiting_report':
      return AdminBookingReviewStatus.waitingCompletion;
    case 'under_review':
      return AdminBookingReviewStatus.underReview;
    case 'dispute':
    case 'no_show':
      return AdminBookingReviewStatus.dispute;
    default:
      return null;
  }
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

// ignore: unused_element
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first;
  return '${parts.first.characters.first}${parts.last.characters.first}';
}

List<BoxShadow> get _shadow => [
  BoxShadow(
    color: const Color(0xFF002B28).withValues(alpha: 0.05),
    blurRadius: 14,
    offset: Offset(0, 7),
  ),
];

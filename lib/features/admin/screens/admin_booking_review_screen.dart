// ignore_for_file: use_null_aware_elements

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/shared/services/api_service.dart';

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
  static const _bg = Color(0xFFF1FAF9);
  static const _teal = Color(0xFF039D98);
  static const _darkTeal = Color(0xFF007B78);
  static const _mint = Color(0xFFE7F6F3);
  static const _ink = Color(0xFF0D1B2A);
  static const _muted = Color(0xFF6B7C86);
  static const _line = Color(0xFFD8E9E6);

  bool _loading = true;
  bool _saving = false;
  String? _error;
  AdminBookingReviewStatus? _filter;
  List<AdminBookingReviewItem> _items = const [];

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
      final response = await http.get(_uri('/admin/booking-review'));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      final decoded = jsonDecode(response.body);
      final list = decoded is List ? decoded : const [];
      final items = list
          .whereType<Map>()
          .map(
            (item) => AdminBookingReviewItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() => _items = items);
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
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: RefreshIndicator(
                color: _teal,
                onRefresh: _load,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _teal),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                        children: [
                          _topBar(),
                          const SizedBox(height: 16),
                          const Text(
                            'Booking Review',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Review nurse bookings that need an admin decision after the appointment time has passed.',
                            style: TextStyle(
                              color: _muted,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _logicNotice(),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            _errorBox(_error!),
                          ],
                          const SizedBox(height: 18),
                          _summaryGrid(),
                          const SizedBox(height: 18),
                          _filters(),
                          const SizedBox(height: 16),
                          if (_visibleItems.isEmpty)
                            _empty()
                          else
                            ..._visibleItems.map(_bookingCard),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _teal),
        ),
        const Spacer(),
        const Text(
          'Admin Review',
          style: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, color: _teal),
        ),
      ],
    );
  }

  Widget _logicNotice() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: _shadow,
      ),
      child: const Row(
        children: [
          Icon(Icons.link_rounded, color: _darkTeal, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
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

  Widget _summaryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.72,
      children: [
        _summaryCard('Under Review', _items.length, Icons.fact_check_outlined),
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
  }

  Widget _summaryCard(String label, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: _shadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
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
            const SizedBox(width: 8),
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _teal : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _teal : _line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _teal,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _bookingCard(AdminBookingReviewItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: _shadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: _mint,
                child: Text(
                  _initials(item.patientName),
                  style: const TextStyle(
                    color: _teal,
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
                      item.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _statusBadge(item.status),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.medical_services_outlined,
            'Service',
            item.serviceType,
          ),
          _infoRow(Icons.schedule_rounded, 'Time', _dateTime(item.scheduledAt)),
          _infoRow(Icons.payments_outlined, 'Paid', _money(item.amount)),
          _infoRow(Icons.lock_outline_rounded, 'Payment', item.paymentStatus),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _teal,
                side: const BorderSide(color: _line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _saving ? null : () => _openReview(item),
              icon: const Icon(Icons.manage_search_rounded, size: 18),
              label: const Text(
                'Review',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(icon, color: _teal, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
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
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
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
                    color: _line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Review Details',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _reviewBlock('Patient', item.patientName),
              _reviewBlock('Nurse', item.providerName),
              _reviewBlock('Service', item.serviceType),
              _reviewBlock('Date & Time', _dateTime(item.scheduledAt)),
              _reviewBlock('Paid Amount', _money(item.amount)),
              _reviewBlock('Reason', item.reason),
              _reviewBlock('System Notes', item.systemNotes),
              const SizedBox(height: 16),
              const Text(
                'Admin Decisions',
                style: TextStyle(fontWeight: FontWeight.w900, color: _ink),
              ),
              const SizedBox(height: 10),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
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
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _saving
            ? null
            : () =>
                  _confirmDecision(item, label, description, effect, decision),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: _darkTeal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: _darkTeal,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: _darkTeal),
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
        title: Text(label),
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
                decoration: const InputDecoration(
                  labelText: 'Refund amount',
                  prefixText: 'ILS ',
                ),
              ),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Admin notes (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _teal),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apply Decision'),
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
        headers: const {'Content-Type': 'application/json'},
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
          content: Text('Decision saved: ${decision.replaceAll('_', ' ')}'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: const Text(
        'No nurse bookings need admin review right now.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8EE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFD83A59),
          fontWeight: FontWeight.w800,
        ),
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
        return const Color(0xFFE07A1F);
      case AdminBookingReviewStatus.requestExpired:
        return const Color(0xFFD83A59);
      case AdminBookingReviewStatus.waitingCompletion:
        return const Color(0xFF1D7BC7);
      case AdminBookingReviewStatus.dispute:
        return const Color(0xFF8A5BC9);
      case AdminBookingReviewStatus.underReview:
        return _darkTeal;
    }
  }

  String _dateTime(DateTime? date) {
    if (date == null) return 'Not scheduled';
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
    return '$text ILS';
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first;
  return '${parts.first.characters.first}${parts.last.characters.first}';
}

List<BoxShadow> get _shadow => [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 14,
    offset: const Offset(0, 7),
  ),
];

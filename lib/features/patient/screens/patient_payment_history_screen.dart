import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/services/api_service.dart';

/// Lists booking payments from `GET /api/payments/patient/:id` (DEMO ledger).
class PatientPaymentHistoryScreen extends StatefulWidget {
  const PatientPaymentHistoryScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<PatientPaymentHistoryScreen> createState() =>
      _PatientPaymentHistoryScreenState();
}

class _PatientPaymentHistoryScreenState
    extends State<PatientPaymentHistoryScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getPatientPaymentsApi(widget.patientUserId);
      final enriched = await Future.wait(
        list.map((item) async {
          final row = Map<String, dynamic>.from(item as Map);
          final appointmentId = (row['appointmentId'] ?? row['bookingId'] ?? '')
              .toString();
          if (appointmentId.isNotEmpty) {
            try {
              final result = await _api.getRefundRequest(
                appointmentId: appointmentId,
                patientUserId: widget.patientUserId,
              );
              if (result['request'] is Map) {
                row['refundRequest'] = Map<String, dynamic>.from(
                  result['request'] as Map,
                );
              }
            } catch (_) {}
          }
          return row;
        }),
      );
      if (!mounted) return;
      setState(() {
        _rows = enriched;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.userMessage(e);
        _loading = false;
      });
    }
  }

  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  String _statusLabel(dynamic v) {
    final isAr = context.l10n.isArabic;
    final s = (v ?? '').toString().toLowerCase();
    switch (s) {
      case 'paid':
        return isAr ? 'مدفوع' : 'Paid';
      case 'pending':
        return isAr ? 'قيد الانتظار' : 'Pending';
      case 'unpaid':
        return isAr ? 'غير مدفوع' : 'Unpaid';
      case 'failed':
        return isAr ? 'فشل' : 'Failed';
      case 'refunded':
        return isAr ? 'مسترد' : 'Refunded';
      default:
        return s.isEmpty ? (isAr ? 'غير معروف' : 'Unknown') : s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final isAr = context.l10n.isArabic;
    return PatientScaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(title: isAr ? 'سجل الدفع' : 'Payment history'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _rows.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 40),
                        Center(
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: p.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isAr ? 'لا توجد مدفوعات بعد.' : 'No payments yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.inkMuted, fontSize: 15),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _rows.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final r = Map<String, dynamic>.from(
                          _rows[index] as Map,
                        );
                        final amt = r['amount'];
                        final cur = (r['currency'] ?? '').toString();
                        final prov =
                            (r['providerName'] ??
                                    (isAr ? 'مقدم الرعاية' : 'Provider'))
                                .toString();
                        final method = (r['paymentMethod'] ?? '').toString();
                        final st = _statusLabel(r['paymentStatus']);
                        final refundRequest = r['refundRequest'] is Map
                            ? Map<String, dynamic>.from(
                                r['refundRequest'] as Map,
                              )
                            : null;
                        final amtStr = amt == null
                            ? '—'
                            : '${amt is num ? amt.toStringAsFixed(2) : amt} ${cur.trim()}';
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.stroke),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prov,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: p.inkDark,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                amtStr,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (refundRequest != null) ...[
                                _refundBadge(
                                  p,
                                  (refundRequest['status'] ?? 'pending')
                                      .toString(),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  _chip(p, isAr ? 'الحالة' : 'Status', st),
                                  if (method.isNotEmpty)
                                    _chip(
                                      p,
                                      isAr ? 'الطريقة' : 'Method',
                                      method,
                                    ),
                                  if ((r['appointmentId'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    _chip(
                                      p,
                                      isAr ? 'الزيارة' : 'Visit',
                                      _shortId(r['appointmentId']!.toString()),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _chip(CarelinkPalette p, String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
      ),
      child: Text('$k: $v', style: TextStyle(fontSize: 12, color: p.inkMuted)),
    );
  }

  Widget _refundBadge(CarelinkPalette p, String status) {
    final isAr = context.l10n.isArabic;
    final normalized = status.toLowerCase();
    final rejected = normalized == 'rejected';
    final approved = normalized == 'approved' || normalized == 'processed';
    final color = rejected
        ? const Color(0xFFD93636)
        : approved
        ? const Color(0xFF15803D)
        : const Color(0xFFF59E0B);
    final label = rejected
        ? (isAr ? 'تم رفض طلب الاسترداد' : 'Refund Rejected')
        : approved
        ? (isAr ? 'تمت الموافقة على الاسترداد' : 'Refund Approved')
        : (isAr ? 'طلب الاسترداد قيد المراجعة' : 'Refund Request Pending');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

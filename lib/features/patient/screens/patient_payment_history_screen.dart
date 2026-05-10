import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/shared/services/api_service.dart';

/// Lists booking payments from `GET /api/payments/patient/:id` (DEMO ledger).
class PatientPaymentHistoryScreen extends StatefulWidget {
  const PatientPaymentHistoryScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<PatientPaymentHistoryScreen> createState() =>
      _PatientPaymentHistoryScreenState();
}

class _PatientPaymentHistoryScreenState extends State<PatientPaymentHistoryScreen> {
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
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  static String _statusLabel(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();
    switch (s) {
      case 'paid':
        return 'Paid';
      case 'pending':
        return 'Pending';
      case 'unpaid':
        return 'Unpaid';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: AppBar(
        centerTitle: true,
        title: const CarelinkAppBarTitle('Payment history'),
        actions: carelinkAppBarActions(),
      ),
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
                            const CarelinkBrandLogo(height: 32),
                            const SizedBox(height: 24),
                            Text(
                              'No payments yet.',
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
                                (r['providerName'] ?? 'Provider').toString();
                            final method =
                                (r['paymentMethod'] ?? '').toString();
                            final st = _statusLabel(r['paymentStatus']);
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
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 6,
                                    children: [
                                      _chip(p, 'Status', st),
                                      if (method.isNotEmpty)
                                        _chip(p, 'Method', method),
                                      if ((r['appointmentId'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        _chip(
                                          p,
                                          'Visit',
                                          _shortId(
                                            r['appointmentId']!.toString(),
                                          ),
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
      child: Text(
        '$k: $v',
        style: TextStyle(fontSize: 12, color: p.inkMuted),
      ),
    );
  }
}

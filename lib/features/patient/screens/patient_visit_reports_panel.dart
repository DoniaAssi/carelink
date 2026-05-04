import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'booking_details_screen.dart';

/// تقارير الزيارات على المدى الطويل: دمج تاريخ المواعيد مع الملاحظات الظاهرة في تفاصيل كل زيارة.
class PatientVisitReportsPanel extends StatefulWidget {
  const PatientVisitReportsPanel({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<PatientVisitReportsPanel> createState() =>
      _PatientVisitReportsPanelState();
}

class _PatientVisitReportsPanelState extends State<PatientVisitReportsPanel> {
  final ApiService _api = ApiService();
  List<AppointmentModel> _visits = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.patientUserId.trim().isEmpty) {
      setState(() {
        _loading = false;
        _visits = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _api.getAppointmentHistory(widget.patientUserId);
      if (!mounted) return;
      final list = <AppointmentModel>[];
      for (final e in raw) {
        if (e is! Map<String, dynamic>) continue;
        list.add(AppointmentModel.fromJson(e));
      }
      list.sort((a, b) {
        final ta = a.scheduledAt;
        final tb = b.scheduledAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      setState(() {
        _visits = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _formatWhen(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _excerpt(AppointmentModel a) {
    final parts = <String>[];
    final s = a.symptoms.trim();
    if (s.isNotEmpty) parts.add(s);
    final n = a.notes.trim();
    if (n.isNotEmpty) parts.add(n);
    final an = a.additionalNotes.trim();
    if (an.isNotEmpty) parts.add(an);
    if (parts.isEmpty) {
      if (a.visitAddress.trim().isNotEmpty) {
        return a.visitAddress.trim();
      }
      return 'Open for visit details and any clinical notes from your provider.';
    }
    final merged = parts.join(' · ');
    if (merged.length > 200) {
      return '${merged.substring(0, 200)}…';
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 48),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
        children: [
          _intro(p),
          const SizedBox(height: 14),
          if (_visits.isEmpty)
            _empty(p)
          else
            ..._visits.map((a) => _card(context, p, a)),
        ],
      ),
    );
  }

  Widget _intro(CarelinkPalette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline_rounded,
                size: 22,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تقارير الزيارات · Visit timeline',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: p.inkDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'سجلٌ مرتب بالتاريخ يضم زياراتك وملخصاً للأعراض والملاحظات. '
            'للملف الطبي الثابت (حالات مزمنة، أدوية، حساسية) استخدمي تبويب «الملف الطبي».',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: p.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(CarelinkPalette p) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
      ),
      child: Text(
        'لا يوجد سجل زيارات بعد. بعد إتمام أول زيارة ستظهر هنا مرتّبة لسهولة المتابعة.',
        textAlign: TextAlign.center,
        style: TextStyle(color: p.inkMuted, fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    CarelinkPalette p,
    AppointmentModel a,
  ) {
    final st = a.status.toLowerCase();
    final isCompleted = st == 'completed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingDetailsScreen(
                  appointmentId: a.appointmentId,
                  patientUserId: widget.patientUserId,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 20,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.providerName.isNotEmpty
                            ? a.providerName
                            : 'مقدم الخدمة',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: p.inkDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: p.surfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCompleted
                              ? AppColors.primary.withValues(alpha: 0.35)
                              : p.stroke,
                        ),
                      ),
                      child: Text(
                        a.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isCompleted
                              ? AppColors.primaryDark
                              : p.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (a.specialization.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    a.specialization,
                    style: TextStyle(fontSize: 12, color: p.inkMuted),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatWhen(a.scheduledAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.inkDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _excerpt(a),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: p.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    'التفاصيل · Details ›',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

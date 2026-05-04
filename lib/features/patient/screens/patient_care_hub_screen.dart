import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'appointments_screen.dart';
import 'booking_details_screen.dart';
import 'medical_records_screen.dart';
import 'schedule_screen.dart';

/// مركز واحد: تنظيم المواعيد، الملف الصحي الإلكتروني، وإبراز آخر الزيارات.
class PatientCareHubScreen extends StatefulWidget {
  const PatientCareHubScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<PatientCareHubScreen> createState() => _PatientCareHubScreenState();
}

class _PatientCareHubScreenState extends State<PatientCareHubScreen> {
  final ApiService _api = ApiService();
  List<AppointmentModel> _recentVisits = [];
  bool _loadingVisits = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    if (widget.patientUserId.trim().isEmpty) {
      setState(() {
        _loadingVisits = false;
        _recentVisits = [];
      });
      return;
    }
    setState(() => _loadingVisits = true);
    try {
      final raw = await _api.getAppointmentHistory(widget.patientUserId);
      if (!mounted) return;
      final all = raw
          .map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      all.sort((a, b) {
        final ta = a.scheduledAt;
        final tb = b.scheduledAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      setState(() {
        _recentVisits = all.take(5).toList();
        _loadingVisits = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _recentVisits = [];
          _loadingVisits = false;
        });
      }
    }
  }

  String _formatVisitDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final uid = widget.patientUserId;

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: AppBar(
        backgroundColor: p.isDark ? const Color(0xFF06313A) : AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const CarelinkAppBarTitle('My care'),
        actions: carelinkAppBarActions(),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadRecent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _introCard(p),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final first = _hubTile(
                    p,
                    icon: Icons.calendar_view_month_rounded,
                    title: 'Appointment schedule',
                    subtitle: 'Filter by status, open each booking',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScheduleScreen(patientUserId: uid),
                        ),
                      );
                    },
                  );
                  final second = _hubTile(
                    p,
                    icon: Icons.folder_open_rounded,
                    title: 'Medical records',
                    subtitle: 'Electronic file, add or edit entries',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicalRecordsScreen(userId: uid),
                        ),
                      );
                    },
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                      children: [first, const SizedBox(height: 12), second],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: first),
                      const SizedBox(width: 12),
                      Expanded(child: second),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _linkRow(
                p,
                icon: Icons.receipt_long_rounded,
                label: 'Visit reports (long-term)',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MedicalRecordsScreen(userId: uid, initialTab: 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _linkRow(
                p,
                icon: Icons.event_note_rounded,
                label: 'Upcoming & history (simple list)',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppointmentsScreen(patientUserId: uid),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Documented visits',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: p.inkDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Completed and cancelled visits stay listed for your records.',
                style: TextStyle(fontSize: 12, color: p.inkMuted, height: 1.35),
              ),
              const SizedBox(height: 12),
              if (_loadingVisits)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_recentVisits.isEmpty)
                _emptyVisits(p)
              else
                ..._recentVisits.map((v) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: _cardColor(p),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingDetailsScreen(
                                appointmentId: v.appointmentId,
                                patientUserId: uid,
                              ),
                            ),
                          );
                          _loadRecent();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _borderColor(p)),
                            boxShadow: [
                              BoxShadow(
                                color: _shadowColor(p),
                                blurRadius: p.isDark ? 18 : 12,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.assignment_turned_in_rounded,
                                color: _accentColor(p),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.providerName.isNotEmpty
                                          ? v.providerName
                                          : 'Provider',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: p.inkDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatVisitDate(v.scheduledAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _chipColor(p),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _borderColor(p),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  v.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: p.inkDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _introCard(CarelinkPalette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor(p),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(p)),
        boxShadow: [
          BoxShadow(
            color: _shadowColor(p),
            blurRadius: p.isDark ? 22 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appointments & health file',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Plan visits, maintain your medical file, and use Visit reports for a '
            'long-term timeline (symptoms & notes per visit).',
            style: TextStyle(fontSize: 13, height: 1.45, color: p.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _hubTile(
    CarelinkPalette p, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _cardColor(p),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 132,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor(p)),
            boxShadow: [
              BoxShadow(
                color: _shadowColor(p),
                blurRadius: p.isDark ? 18 : 10,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _iconBubbleColor(p),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _accentColor(p), size: 25),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: p.inkDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: p.inkMuted, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkRow(
    CarelinkPalette p, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _cardColor(p),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor(p)),
            boxShadow: [
              BoxShadow(
                color: _shadowColor(p),
                blurRadius: p.isDark ? 16 : 8,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: _accentColor(p)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: p.inkDark,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyVisits(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor(p),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(p)),
      ),
      child: Text(
        'No past visits yet. When visits are completed or cancelled, they appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: p.inkMuted, fontSize: 13, height: 1.4),
      ),
    );
  }

  Color _cardColor(CarelinkPalette p) =>
      p.isDark ? const Color(0xFF08242D) : p.surface;

  Color _chipColor(CarelinkPalette p) =>
      p.isDark ? const Color(0xFF0E323B) : p.surfaceSoft;

  Color _borderColor(CarelinkPalette p) =>
      p.isDark ? const Color(0xFF25505A) : p.stroke;

  Color _shadowColor(CarelinkPalette p) =>
      Colors.black.withValues(alpha: p.isDark ? 0.28 : 0.05);

  Color _accentColor(CarelinkPalette p) =>
      p.isDark ? const Color(0xFF5BE1D4) : AppColors.primaryDark;

  Color _iconBubbleColor(CarelinkPalette p) =>
      p.isDark ? const Color(0xFF0D3841) : const Color(0xFFE7F8F6);
}

import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/utils/appointment_time_utils.dart';
import 'booking_details_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  final String patientUserId;

  const AppointmentsScreen({super.key, required this.patientUserId});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<AppointmentModel> upcoming = [];
  List<AppointmentModel> history = [];
  int currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final upcomingRaw = await ApiService().getUpcomingAppointments(
        widget.patientUserId,
      );
      final historyRaw = await ApiService().getAppointmentHistory(
        widget.patientUserId,
      );

      if (!mounted) return;
      setState(() {
        upcoming = upcomingRaw
            .map((e) => AppointmentModel.fromJson(e))
            .where(_isValidBooking)
            .toList();
        history = historyRaw
            .map((e) => AppointmentModel.fromJson(e))
            .where(_isValidBooking)
            .toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = context.l10n.userMessage(e);
        isLoading = false;
      });
    }
  }

  bool _isValidBooking(AppointmentModel a) {
    final status = a.status.toLowerCase();
    if (status == 'draft' ||
        status == 'pending_payment' ||
        status == 'payment_pending') {
      return false;
    }

    final payStatus = a.paymentStatus.toLowerCase();
    final payMethod = a.paymentMethod.toLowerCase();

    if (payStatus == 'unpaid' &&
        payMethod != 'cash' &&
        payMethod != 'cash_on_visit') {
      return false;
    }

    return true;
  }

  List<AppointmentModel> get _activeList =>
      currentTab == 0 ? upcoming : history;

  String _formatDate(DateTime? date) {
    if (date == null) return context.tr('patient.appointments.dateUnavailable');
    return AppointmentTimeUtils.formatDateTime(context, date);
  }

  Color _statusColor(AppointmentModel appointment) {
    if (appointment.subStatus.toLowerCase().trim() == 'reschedule_requested' || appointment.status.toLowerCase().trim() == 'pending_reschedule') {
      return AppColors.warning;
    }
    final status = appointment.status;
    switch (status.toLowerCase()) {
      case 'pending_provider_approval':
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return AppColors.primary;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return AppColors.textLight;
    }
  }

  String _translateStatus(AppointmentModel appointment) {
    if (appointment.subStatus.toLowerCase().trim() == 'reschedule_requested' || appointment.status.toLowerCase().trim() == 'pending_reschedule') {
      return context.l10n.isArabic
          ? 'طلب تغيير الموعد بانتظار الموافقة'
          : 'Reschedule request pending approval';
    }
    final lower = appointment.status.toLowerCase();
    final isAr = context.l10n.isArabic;
    switch (lower) {
      case 'pending_provider_approval':
      case 'pending':
        return isAr
            ? 'بانتظار موافقة مقدم الرعاية'
            : 'Waiting for provider approval';
      case 'pending_payment':
      case 'payment_pending':
        return isAr ? 'بانتظار الدفع' : 'Pending Payment';
      case 'confirmed':
        return isAr ? 'مؤكد' : 'Confirmed';
      case 'completed':
        return isAr ? 'مكتمل' : 'Completed';
      case 'cancelled':
        return isAr ? 'ملغي' : 'Cancelled';
      case 'in_progress':
        return isAr ? 'قيد التنفيذ' : 'In Progress';
      case 'request_expired':
      case 'expired':
        return isAr ? 'انتهت صلاحية الطلب' : 'Request Expired';
      case 'missed':
      case 'no_show':
        return isAr ? 'موعد فائت' : 'Missed Appointment';
      case 'pending_completion':
        return isAr ? 'بانتظار تأكيد الإتمام' : 'Pending Completion';
      default:
        return isAr ? 'غير معروف' : 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return PatientScaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(title: context.tr('patient.appointments.title')),
      body: RefreshIndicator(
        onRefresh: _loadAppointments,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _tabButton(
                      context.tr('patient.appointments.upcoming'),
                      0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _tabButton(
                      context.tr('patient.appointments.history'),
                      1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else if (errorMessage != null)
                _emptyCard(errorMessage!)
              else if (_activeList.isEmpty)
                _emptyCard(context.tr('patient.appointments.empty'))
              else
                Column(
                  children: _activeList.map((item) {
                    return PatientPressable(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingDetailsScreen(
                              appointmentId: item.appointmentId,
                              patientUserId: widget.patientUserId,
                            ),
                          ),
                        );
                        _loadAppointments();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: p.stroke),
                          boxShadow: [_cardShadow(p)],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: p.isDark ? 0.16 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.providerName.isEmpty
                                        ? (context.l10n.isArabic
                                              ? 'مقدم رعاية'
                                              : 'Provider')
                                        : item.providerName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: p.inkDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(item.scheduledAt),
                                    style: TextStyle(
                                      color: p.inkMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (item.status.toLowerCase() ==
                                          'completed' &&
                                      (item.patientRatingStars == null ||
                                          item.patientRatingStars! < 1)) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFFB020,
                                        ).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        context.l10n.isArabic
                                            ? 'بانتظار تقييمك'
                                            : 'Waiting for your rating',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFB77900),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  item,
                                ).withValues(alpha: p.isDark ? 0.18 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _translateStatus(item),
                                style: TextStyle(
                                  color: _statusColor(item),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, int tab) {
    final p = CarelinkPalette.of(context);
    final selected = currentTab == tab;
    return PatientPressable(
      onTap: () => setState(() => currentTab = tab),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : p.surface,
          border: Border.all(color: selected ? AppColors.primary : p.stroke),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : p.inkDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    final p = CarelinkPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
        boxShadow: [_cardShadow(p)],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: p.inkMuted),
      ),
    );
  }

  BoxShadow _cardShadow(CarelinkPalette p) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: p.isDark ? 0.22 : 0.045),
      blurRadius: 16,
      offset: const Offset(0, 8),
    );
  }
}

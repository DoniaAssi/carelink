import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart'
    show carelinkLocaleThemeChipRow;
import 'package:carelink/shared/services/api_service.dart';
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
            .toList();
        history = historyRaw.map((e) => AppointmentModel.fromJson(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  List<AppointmentModel> get _activeList =>
      currentTab == 0 ? upcoming : history;

  String _formatDate(BuildContext context, DateTime? date) {
    if (date == null) return context.tr('patient.dateUnavailable');
    final loc = localeController.locale.toLanguageTag();
    try {
      return DateFormat.yMMMd(loc).add_jm().format(date.toLocal());
    } catch (_) {
      return DateFormat.yMMMd('en').add_jm().format(date.toLocal());
    }
  }

  String _statusLabel(BuildContext context, String raw) {
    switch (raw.toLowerCase()) {
      case 'pending':
        return context.tr('patient.status.pending');
      case 'confirmed':
        return context.tr('patient.status.confirmed');
      case 'completed':
        return context.tr('patient.status.completed');
      case 'cancelled':
        return context.tr('patient.status.cancelled');
      default:
        return raw;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      body: RefreshIndicator(
        onRefresh: _loadAppointments,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              _buildHeader(p),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child:
                        _tabButton(context.tr('patient.tab.upcoming'), 0),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _tabButton(context.tr('patient.tab.history'), 1)),
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
                _emptyCard(context.tr('patient.noAppointments'))
              else
                Column(
                  children: _activeList.map((item) {
                    return GestureDetector(
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
                                        ? context
                                            .tr('patient.providerFallback')
                                        : item.providerName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: p.inkDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(context, item.scheduledAt),
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
                                    Text(
                                      context.tr('patient.rateVisitHint'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
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
                                  item.status,
                                ).withValues(alpha: p.isDark ? 0.18 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _statusLabel(context, item.status),
                                style: TextStyle(
                                  color: _statusColor(item.status),
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
    return GestureDetector(
      onTap: () => setState(() => currentTab = tab),
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

  Widget _buildHeader(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
        boxShadow: [_cardShadow(p)],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.stroke),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: p.inkDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CarelinkBrandLogo(
            height: 28,
            fallbackTextColor: p.inkDark,
            forceDarkLogo: p.isDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('patient.appointments.header'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.inkDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.stroke),
            ),
            child: carelinkLocaleThemeChipRow(iconColor: p.inkDark, gap: 4),
          ),
        ],
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

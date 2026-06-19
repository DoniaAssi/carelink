// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/widgets/patient_navigation_shell.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/payment_service.dart';
import 'package:carelink/features/patient/utils/appointment_action_helper.dart';
import 'package:carelink/features/patient/utils/rebook_flow_helper.dart';
import 'package:carelink/features/patient/screens/messages_screen.dart';

import 'booking_details_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

enum _BookingFilter { all, waiting, upcoming, completed, cancelled }

enum _BookingState {
  waitingProvider,
  waitingPayment,
  confirmed,
  inProgress,
  completed,
  cancelled,
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ApiService _api = ApiService();
  final PaymentService _payments = PaymentService();

  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  String? _error;
  String? _payingId;
  _BookingFilter _filter = _BookingFilter.all;
  DateTime? _selectedDay;

  bool get _isArabic => context.l10n.isArabic;
  String _t(String english, String arabic) => _isArabic ? arabic : english;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (widget.patientUserId.trim().isEmpty) {
      setState(() {
        _appointments = [];
        _isLoading = false;
        _error = _t(
          'Patient account is missing. Please sign in again.',
          'حساب المريض غير متوفر. يرجى تسجيل الدخول مجدداً.',
        );
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getAppointments(widget.patientUserId),
        _api.getUpcomingAppointments(widget.patientUserId),
        _api.getAppointmentHistory(widget.patientUserId),
      ]);
      final byId = <String, Map<String, dynamic>>{};
      for (final list in results) {
        for (final raw in list.whereType<Map>()) {
          final row = Map<String, dynamic>.from(raw);
          final id = (row['appointmentId'] ?? row['requestId'] ?? '')
              .toString();
          if (id.isNotEmpty) byId[id] = row;
        }
      }

      final merged = byId.values.toList()
        ..sort((a, b) {
          final first = _dateOf(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final second = _dateOf(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final firstPast = first.isBefore(DateTime.now());
          final secondPast = second.isBefore(DateTime.now());
          if (firstPast != secondPast) return firstPast ? 1 : -1;
          return firstPast ? second.compareTo(first) : first.compareTo(second);
        });

      if (!mounted) return;
      setState(() {
        _appointments = merged;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  _BookingState _stateOf(Map<String, dynamic> row) {
    final status = _normalizedStatus(row);
    final payment = _normalizedPaymentStatus(row);
    final method = (row['paymentMethod'] ?? '').toString().trim().toLowerCase();
    final isPaid = payment == 'paid';
    final cashOnVisit = method == 'cash' || method == 'cash_on_visit';

    if (status == 'cancelled' || status == 'canceled' || status == 'rejected') {
      return _BookingState.cancelled;
    }
    if (status == 'completed' || status == 'done') {
      return _BookingState.completed;
    }
    if (status == 'in_progress' || status == 'waiting_report') {
      return _BookingState.inProgress;
    }
    if (status == 'pending_payment' ||
        status == 'payment_pending' ||
        ((status == 'confirmed' ||
                status == 'accepted' ||
                status == 'scheduled' ||
                status == 'approved') &&
            !isPaid &&
            !cashOnVisit)) {
      return _BookingState.waitingPayment;
    }
    if (status == 'confirmed' ||
        status == 'accepted' ||
        status == 'scheduled' ||
        status == 'approved') {
      return _BookingState.confirmed;
    }
    return _BookingState.waitingProvider;
  }

  bool _hasProviderId(Map<String, dynamic> row) {
    return (row['providerUserId'] ?? row['doctorUserId'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
  }

  String _normalizedStatus(Map<String, dynamic> row) {
    return (row['status'] ?? row['bookingStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }

  String _normalizedPaymentStatus(Map<String, dynamic> row) {
    return (row['paymentStatus'] ?? '').toString().trim().toLowerCase();
  }

  List<Map<String, dynamic>> get _visibleAppointments {
    return _appointments.where((row) {
      final state = _stateOf(row);
      final matchesFilter = switch (_filter) {
        _BookingFilter.all => state != _BookingState.cancelled,
        _BookingFilter.waiting =>
          state == _BookingState.waitingProvider ||
              state == _BookingState.waitingPayment,
        _BookingFilter.upcoming =>
          state == _BookingState.confirmed || state == _BookingState.inProgress,
        _BookingFilter.completed => state == _BookingState.completed,
        _BookingFilter.cancelled => state == _BookingState.cancelled,
      };
      if (!matchesFilter) return false;
      final selected = _selectedDay;
      final date = _dateOf(row);
      return selected == null || (date != null && _sameDay(selected, date));
    }).toList();
  }

  Map<DateTime, List<Map<String, dynamic>>> get _dateGroups {
    final groups = <DateTime, List<Map<String, dynamic>>>{};
    for (final row in _visibleAppointments) {
      final date = _dateOf(row) ?? DateTime(1970);
      final key = DateTime(date.year, date.month, date.day);
      groups.putIfAbsent(key, () => []).add(row);
    }
    return groups;
  }

  DateTime? _dateOf(Map<String, dynamic> row) {
    final raw = row['scheduledAt']?.toString() ?? '';
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toLocal();
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  Future<void> _openDetails(Map<String, dynamic> row) async {
    final id = (row['appointmentId'] ?? row['requestId'] ?? '').toString();
    if (id.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingDetailsScreen(
          appointmentId: id,
          patientUserId: widget.patientUserId,
        ),
      ),
    );
    await _loadAppointments();
  }

  Future<void> _payNow(Map<String, dynamic> row) async {
    final id = (row['appointmentId'] ?? row['requestId'] ?? '').toString();
    final providerId = (row['providerUserId'] ?? row['doctorUserId'] ?? '')
        .toString();
    if (id.isEmpty || providerId.isEmpty || _payingId != null) return;
    setState(() => _payingId = id);
    try {
      final result = await _payments.payForBooking(
        appointmentId: id,
        patientUserId: widget.patientUserId,
        providerUserId: providerId,
        paymentMethod: 'mock_card',
      );
      if (!mounted) return;
      final paid =
          (result['paymentStatus'] ?? '').toString().toLowerCase() == 'paid';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paid
                ? _t(
                    'Payment completed. Your appointment is confirmed.',
                    'تم الدفع. تم تأكيد موعدك.',
                  )
                : _t(
                    'Please complete payment before your appointment is confirmed.',
                    'يرجى إكمال الدفع قبل تأكيد الموعد.',
                  ),
          ),
        ),
      );
      await _loadAppointments();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _payingId = null);
    }
  }

  void _bookCare() => PatientNavigationShell.switchTab(context, 0);

  Future<void> _showRebookChoices(Map<String, dynamic> row) async {
    final providerId = (row['providerUserId'] ?? row['doctorUserId'] ?? '')
        .toString()
        .trim();
    if (providerId.isEmpty) {
      _showSnack(
        _t(
          'This provider is currently unavailable.',
          'مقدم الرعاية غير متاح حالياً.',
        ),
      );
      return;
    }

    await RebookFlowHelper.startFromRow(
      context: context,
      row: row,
      patientUserId: widget.patientUserId,
    );
  }

  BookingRequestModel _rebookRequestFrom(
    Map<String, dynamic> row,
    ProviderModel provider,
  ) {
    final serviceType = (row['serviceType'] ?? provider.serviceType)
        .toString()
        .trim();
    final notes = (row['notes'] ?? '').toString();
    final parsedType = _noteValue(notes, 'AppointmentType');
    final reason =
        _noteValue(notes, 'Reason') ??
        _noteValue(notes, 'CurrentCase') ??
        (row['reasonForVisit'] ?? '').toString();
    return BookingRequestModel(
      patientId: widget.patientUserId,
      providerId: provider.userId,
      providerName: provider.fullName.isNotEmpty
          ? provider.fullName
          : _providerDisplayName(row),
      providerRole: provider.role,
      providerImageUrl: provider.profileImageUrl ?? '',
      specialization: provider.specialization,
      serviceType: serviceType.isEmpty
          ? _t('Care Service', 'خدمة رعاية')
          : serviceType,
      appointmentType: (parsedType == null || parsedType.isEmpty)
          ? 'home'
          : parsedType,
      appointmentDate: '',
      appointmentTime: '',
      visitLatitude: _doubleFrom(row['visitLatitude']) ?? provider.gpsLat ?? 0,
      visitLongitude:
          _doubleFrom(row['visitLongitude']) ?? provider.gpsLng ?? 0,
      visitAddress: (row['visitAddress'] ?? row['location'] ?? '').toString(),
      locationNote: (row['locationNote'] ?? '').toString(),
      patientReason: reason.trim(),
      symptoms: (row['symptoms'] ?? '').toString(),
      isUrgent:
          row['isUrgent'] == true ||
          row['isUrgent'] == 1 ||
          (row['isUrgent'] ?? '').toString() == '1',
      additionalNotes: (row['additionalNotes'] ?? '').toString(),
      price: provider.consultationFee ?? 0,
      paymentMethod: '',
      paymentStatus: 'unpaid',
      bookingStatus: 'pending_provider_approval',
    );
  }

  Future<ProviderModel?> _loadRebookProvider(Map<String, dynamic> row) async {
    final providerId = (row['providerUserId'] ?? row['doctorUserId'] ?? '')
        .toString()
        .trim();
    if (providerId.isEmpty) {
      _showSnack(
        _t(
          'This provider is currently unavailable.',
          'مقدم الرعاية غير متاح حالياً.',
        ),
      );
      return null;
    }
    try {
      final provider = ProviderModel.fromJson(
        await _api.getProviderById(providerId, realAvailability: true),
      );
      return provider;
    } catch (error) {
      if (mounted) _showSnack(error.toString().replaceFirst('Exception: ', ''));
      return null;
    }
  }

  String? _noteValue(String notes, String key) {
    final pattern = RegExp(
      '(^|\\|)\\s*${RegExp.escape(key)}\\s*:\\s*([^|]+)',
      caseSensitive: false,
    );
    return pattern.firstMatch(notes)?.group(2)?.trim();
  }

  double? _doubleFrom(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _showSnack(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: palette.pageBg,
      appBar: PatientAppBar(
        title: _t('My Bookings', 'مواعيدي'),
        showBack: false,
        showMessages: true,
        onMessageTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MessagesScreen(userId: widget.patientUserId),
            ),
          );
        },
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadAppointments,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _weekStrip(palette)),
              SliverToBoxAdapter(child: _filters(palette)),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _errorState(palette),
                )
              else if (_visibleAppointments.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyState(palette),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  sliver: SliverList.list(
                    children: _dateGroups.entries
                        .map((entry) => _dateGroup(entry, palette))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekStrip(CarelinkPalette palette) {
    final today = DateTime.now();
    final start = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 9),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.stroke),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 6.0;
            final minimumCardWidth = _isArabic ? 76.0 : 64.0;
            final fittedCardWidth =
                (constraints.maxWidth - (spacing * 6)) / days.length;
            final cardWidth = fittedCardWidth > minimumCardWidth
                ? fittedCardWidth
                : minimumCardWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(days.length, (index) {
                  final day = days[index];
                  final selected =
                      _selectedDay != null && _sameDay(_selectedDay!, day);
                  final isToday = _sameDay(today, day);
                  final hasBooking = _appointments.any((row) {
                    final date = _dateOf(row);
                    return date != null && _sameDay(date, day);
                  });

                  return Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: index == days.length - 1 ? 0 : spacing,
                    ),
                    child: SizedBox(
                      width: cardWidth,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() {
                          _selectedDay = selected ? null : day;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : palette.surfaceSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : isToday
                                  ? AppColors.primary
                                  : palette.stroke,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _shortDay(day),
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : palette.inkDark,
                                  fontSize: _isArabic ? 12 : 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : palette.inkDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasBooking
                                      ? selected
                                            ? Colors.white
                                            : AppColors.primary
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _filters(CarelinkPalette palette) {
    final filters = [
      (_BookingFilter.all, _t('All', 'الكل')),
      (_BookingFilter.waiting, _t('Waiting', 'بانتظار إجراء')),
      (_BookingFilter.upcoming, _t('Upcoming', 'القادمة')),
      (_BookingFilter.completed, _t('Completed', 'المكتملة')),
      (_BookingFilter.cancelled, _t('Cancelled', 'الملغاة')),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = filter.$1 == _filter;
          return ChoiceChip(
            label: Text(filter.$2),
            selected: selected,
            onSelected: (_) => setState(() => _filter = filter.$1),
            selectedColor: AppColors.primary,
            backgroundColor: palette.surface,
            side: BorderSide(
              color: selected ? AppColors.primary : palette.stroke,
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : palette.inkDark,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _dateGroup(
    MapEntry<DateTime, List<Map<String, dynamic>>> entry,
    CarelinkPalette palette,
  ) {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final date = entry.key;
    final title = _sameDay(date, today)
        ? _t('Today', 'اليوم')
        : _sameDay(date, tomorrow)
        ? _t('Tomorrow', 'غداً')
        : _longDay(date);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title, ${_monthDay(date)}',
                  style: TextStyle(
                    color: palette.inkDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _t(
                  '${entry.value.length} appointment${entry.value.length == 1 ? '' : 's'}',
                  '${entry.value.length} موعد',
                ),
                style: TextStyle(
                  color: palette.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.stroke),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < entry.value.length; index++) ...[
                  PatientAnimatedListItem(
                    index: index,
                    child: _appointmentRow(entry.value[index], palette),
                  ),
                  if (index < entry.value.length - 1)
                    Divider(height: 1, color: palette.stroke),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentRow(Map<String, dynamic> row, CarelinkPalette palette) {
    final date = _dateOf(row);
    final state = _stateOf(row);
    final name = _providerDisplayName(row);
    final service = _serviceDisplayName(row);
    final image = _absoluteImage(
      (row['profileImageUrl'] ?? row['profilePictureUrl'])?.toString(),
    );
    return PatientPressable(
      onTap: () => _openDetails(row),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 55,
              child: Text(
                date == null
                    ? '--:--'
                    : intl.DateFormat('h:mm\na').format(date),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: palette.inkDark,
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              width: 2,
              height: 54,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _statusColor(row, state),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            CircleAvatar(
              radius: 21,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              foregroundImage: image == null ? null : NetworkImage(image),
              child: image == null
                  ? const Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.primary,
                      size: 19,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.inkDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    service.isEmpty
                        ? _t('Healthcare appointment', 'موعد رعاية صحية')
                        : service,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.inkMuted, fontSize: 11.5),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _badge(
                        _statusLabel(row, state),
                        _statusColor(row, state),
                        palette,
                      ),
                      _badge(_paymentLabel(row), _paymentColor(row), palette),
                      if (state == _BookingState.completed && !_hasRating(row))
                        _badge(
                          _t('Waiting for your rating', 'بانتظار تقييمك'),
                          const Color(0xFFFFB020),
                          palette,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _rowAction(row, state, palette),
          ],
        ),
      ),
    );
  }

  Widget _rowAction(
    Map<String, dynamic> row,
    _BookingState state,
    CarelinkPalette palette,
  ) {
    final id = (row['appointmentId'] ?? row['requestId'] ?? '').toString();
    if (state == _BookingState.waitingPayment) {
      return FilledButton(
        onPressed: _payingId == null ? () => _payNow(row) : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size(68, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        child: _payingId == id
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(_t('Pay Now', 'ادفع الآن')),
      );
    }
    final status = _normalizedStatus(row);
    final paymentStatus = _normalizedPaymentStatus(row);

    if (state == _BookingState.cancelled) {
      return _bookAgainButton(row, palette);
    }

    // Convert requestedRescheduleAt if present
    DateTime? requestedRescheduleAt;
    final rawReschedule = row['requestedRescheduleAt']?.toString();
    if (rawReschedule != null && rawReschedule.trim().isNotEmpty) {
      requestedRescheduleAt = DateTime.tryParse(
        rawReschedule.replaceFirst(' ', 'T'),
      )?.toLocal();
    }

    final actionState = AppointmentActionHelper.getActionState(
      status: status,
      paymentStatus: paymentStatus,
      requestedRescheduleAt: requestedRescheduleAt,
    );

    if (actionState.type == AppointmentActionType.bookAgain) {
      if (!_hasProviderId(row) || !actionState.isEnabled) {
        return Tooltip(
          message: _t(
            'You cannot rebook this appointment right now',
            'لا يمكن إعادة الحجز لهذا الموعد حالياً',
          ),
          child: OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(68, 34),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              disabledForegroundColor: palette.inkMuted.withValues(alpha: 0.72),
              disabledBackgroundColor: palette.surfaceSoft,
              side: BorderSide(color: palette.stroke),
              textStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(_t('Book Again', 'احجز مجدداً')),
          ),
        );
      }

      return OutlinedButton(
        onPressed: () => _showRebookChoices(row),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(68, 34),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          textStyle: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(_t('Book Again', 'احجز مجدداً')),
      );
    }
    return IconButton(
      tooltip: _t('Details', 'التفاصيل'),
      onPressed: () => _openDetails(row),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      ),
      icon: Icon(
        _isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      ),
    );
  }

  Widget _bookAgainButton(
    Map<String, dynamic> row,
    CarelinkPalette palette, {
    bool enabled = true,
  }) {
    final canRebook = enabled && _hasProviderId(row);
    if (!canRebook) {
      return Tooltip(
        message: _t(
          'You cannot rebook this appointment right now',
          'لا يمكن إعادة الحجز لهذا الموعد حالياً',
        ),
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(68, 34),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            disabledForegroundColor: palette.inkMuted.withValues(alpha: 0.72),
            disabledBackgroundColor: palette.surfaceSoft,
            side: BorderSide(color: palette.stroke),
            textStyle: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(_t('Book Again', 'احجز مجدداً')),
        ),
      );
    }

    return OutlinedButton(
      onPressed: () => _showRebookChoices(row),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(68, 34),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
      child: Text(_t('Book Again', 'احجز مجدداً')),
    );
  }

  Widget _badge(String label, Color color, CarelinkPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _statusLabel(Map<String, dynamic> row, _BookingState state) {
    final subStatus = (row['subStatus'] ?? '').toString().trim().toLowerCase();
    if (subStatus == 'reschedule_requested') {
      return _t(
        'Reschedule request pending approval',
        'طلب تغيير الموعد بانتظار الموافقة',
      );
    }
    return switch (state) {
      _BookingState.waitingProvider => _t(
        'Waiting Provider',
        'بانتظار مقدم الرعاية',
      ),
      _BookingState.waitingPayment => _t('Waiting Payment', 'بانتظار الدفع'),
      _BookingState.confirmed => _t('Confirmed', 'مؤكد'),
      _BookingState.inProgress => _t('In Progress', 'قيد التنفيذ'),
      _BookingState.completed => _t('Completed', 'مكتمل'),
      _BookingState.cancelled => _t('Cancelled', 'ملغي'),
    };
  }

  Color _statusColor(Map<String, dynamic> row, _BookingState state) {
    final subStatus = (row['subStatus'] ?? '').toString().trim().toLowerCase();
    if (subStatus == 'reschedule_requested') return AppColors.warning;
    return switch (state) {
      _BookingState.waitingProvider => const Color(0xFFD58A14),
      _BookingState.waitingPayment => const Color(0xFFE56B16),
      _BookingState.confirmed => AppColors.primary,
      _BookingState.inProgress => const Color(0xFF2583C5),
      _BookingState.completed => const Color(0xFF4D7FA7),
      _BookingState.cancelled => const Color(0xFFC95353),
    };
  }

  String _paymentLabel(Map<String, dynamic> row) {
    final status = (row['paymentStatus'] ?? '').toString().trim().toLowerCase();
    return switch (status) {
      'paid' => _t('Paid', 'مدفوع'),
      'refunded' => _t('Refunded', 'مسترد'),
      'pending_refund' => _t('Pending Refund', 'بانتظار الاسترداد'),
      'pending' => _t('Payment Pending', 'الدفع قيد المعالجة'),
      _ => _t('Unpaid', 'غير مدفوع'),
    };
  }

  Color _paymentColor(Map<String, dynamic> row) {
    final status = (row['paymentStatus'] ?? '').toString().trim().toLowerCase();
    return switch (status) {
      'paid' => AppColors.success,
      'refunded' => const Color(0xFF64748B),
      'pending_refund' => const Color(0xFF7C6FA8),
      _ => const Color(0xFFE56B16),
    };
  }

  bool _hasRating(Map<String, dynamic> row) {
    final value = row['patientRatingStars'];
    return (value is num && value > 0) ||
        (int.tryParse(value?.toString() ?? '') ?? 0) > 0;
  }

  String _providerDisplayName(Map<String, dynamic> row) {
    final raw = (row['providerName'] ?? row['doctorName'] ?? '')
        .toString()
        .trim();
    if (raw.isEmpty || _looksLikeTechnicalId(raw)) {
      return _t('Provider', 'مقدم رعاية');
    }
    return raw;
  }

  String _serviceDisplayName(Map<String, dynamic> row) {
    final raw = (row['specialization'] ?? row['serviceType'] ?? '')
        .toString()
        .trim();
    if (raw.isEmpty) {
      return _t('Care Service', 'خدمة رعاية');
    }
    return raw;
  }

  bool _looksLikeTechnicalId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return true;
    if (RegExp(
      r'^[0-9a-f]{8}-[0-9a-f-]{27,}$',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return true;
    }
    if (RegExp(
      r'^(carid|careid|user_|usr_|provider_)[a-z0-9_-]*$',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return true;
    }
    return false;
  }

  String? _absoluteImage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${ApiService.baseUrl}${raw.startsWith('/') ? raw : '/$raw'}';
  }

  String _shortDay(DateTime date) {
    if (!_isArabic) {
      return intl.DateFormat('EEE').format(date);
    }
    const days = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];
    return days[date.weekday - 1];
  }

  String _longDay(DateTime date) {
    if (!_isArabic) return intl.DateFormat('EEEE').format(date);
    const days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return days[date.weekday - 1];
  }

  String _monthDay(DateTime date) {
    if (!_isArabic) return intl.DateFormat('MMM d').format(date);
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Widget _emptyState(CarelinkPalette palette) {
    final message = switch (_filter) {
      _BookingFilter.upcoming => _t(
        'You have no upcoming appointments.',
        'لا توجد مواعيد قادمة.',
      ),
      _BookingFilter.completed => _t(
        'Completed visits will appear here.',
        'ستظهر الزيارات المكتملة هنا.',
      ),
      _BookingFilter.cancelled => _t(
        'No cancelled appointments.',
        'لا توجد مواعيد ملغاة.',
      ),
      _BookingFilter.waiting => _t(
        'No appointments waiting for action.',
        'لا توجد مواعيد بانتظار إجراء.',
      ),
      _BookingFilter.all => _t(
        'You have no bookings yet.',
        'لا توجد حجوزات حتى الآن.',
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.event_note_outlined,
                color: AppColors.primary,
                size: 31,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.inkDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _bookCare,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_t('Book Care', 'احجز رعاية')),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(CarelinkPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 20, 30, 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: palette.inkMuted, size: 42),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.inkMuted),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadAppointments,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_t('Try Again', 'إعادة المحاولة')),
            ),
          ],
        ),
      ),
    );
  }
}

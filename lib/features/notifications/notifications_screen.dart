import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/doctors/doctor/doctor_booking_request_details_screen.dart';
import 'package:carelink/features/patient/screens/booking_details_screen.dart';
import 'package:carelink/features/patient/screens/medical_record_details_screen.dart';
import 'package:carelink/features/patient/screens/patient_payment_history_screen.dart';
import 'package:carelink/features/patient/screens/schedule_screen.dart';
import 'package:carelink/shared/services/notification_center.dart';

enum NotificationCategory {
  appointment,
  medicalRecord,
  recommendation,
  payment,
  provider,
  system,
  message,
}

class NotificationCardData {
  const NotificationCardData({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.read,
    this.at,
    this.relatedId,
  });

  factory NotificationCardData.fromJson(
    Map<String, dynamic> json,
    NotificationCenter center,
  ) {
    final rawDate = json['createdAt'] ?? json['created'] ?? json['timestamp'];
    return NotificationCardData(
      id: (json['id'] ?? json['notificationId'] ?? '').toString(),
      title: (json['title'] ?? json['subject'] ?? 'Notification').toString(),
      description: (json['body'] ?? json['message'] ?? json['text'] ?? '')
          .toString(),
      category: _categoryFromType(
        (json['type'] ?? json['category'] ?? '').toString(),
      ),
      read: center.isRead(json),
      at: rawDate == null ? null : DateTime.tryParse(rawDate.toString()),
      relatedId:
          (json['relatedRequestId'] ??
                  json['relatedId'] ??
                  json['requestId'] ??
                  json['appointmentId'] ??
                  json['serviceRequestId'])
              ?.toString(),
    );
  }

  final String id;
  final String title;
  final String description;
  final DateTime? at;
  final NotificationCategory category;
  final bool read;
  final String? relatedId;

  Color get accent {
    switch (category) {
      case NotificationCategory.appointment:
        return const Color(0xFF16896B);
      case NotificationCategory.medicalRecord:
        return const Color(0xFF3478C5);
      case NotificationCategory.recommendation:
        return const Color(0xFF8A56C2);
      case NotificationCategory.payment:
        return const Color(0xFFD58324);
      case NotificationCategory.provider:
        return const Color(0xFF1595A3);
      case NotificationCategory.message:
        return const Color(0xFF5269C7);
      case NotificationCategory.system:
        return const Color(0xFF667780);
    }
  }

  IconData get icon {
    switch (category) {
      case NotificationCategory.appointment:
        return Icons.calendar_month_rounded;
      case NotificationCategory.medicalRecord:
        return Icons.description_rounded;
      case NotificationCategory.recommendation:
        return Icons.auto_awesome_rounded;
      case NotificationCategory.payment:
        return Icons.credit_card_rounded;
      case NotificationCategory.provider:
        return Icons.medical_services_rounded;
      case NotificationCategory.message:
        return Icons.chat_bubble_rounded;
      case NotificationCategory.system:
        return Icons.notifications_rounded;
    }
  }

  String actionLabel(bool isArabic) {
    switch (category) {
      case NotificationCategory.appointment:
        return isArabic ? 'عرض الموعد' : 'View Appointment';
      case NotificationCategory.medicalRecord:
        return isArabic ? 'عرض السجل' : 'View Record';
      case NotificationCategory.recommendation:
        return isArabic ? 'عرض التوصية' : 'View Recommendation';
      case NotificationCategory.payment:
        return isArabic ? 'عرض الدفعة' : 'View Payment';
      case NotificationCategory.provider:
        return isArabic ? 'عرض مقدم الرعاية' : 'View Provider';
      case NotificationCategory.message:
        return isArabic ? 'عرض الرسالة' : 'View Message';
      case NotificationCategory.system:
        return isArabic ? 'عرض التفاصيل' : 'View Details';
    }
  }

  bool get isActionable {
    return category == NotificationCategory.appointment ||
        category == NotificationCategory.medicalRecord ||
        category == NotificationCategory.payment;
  }

  String displayTitle(bool isArabic) {
    if (!isArabic) return title;
    final normalized = title.trim().toLowerCase();
    if (normalized == 'booking request sent') {
      return 'تم إرسال طلب الحجز';
    }
    if (normalized == 'payment required') {
      return 'مطلوب الدفع';
    }
    if (normalized == 'appointment confirmed') {
      return 'تم تأكيد الموعد';
    }
    if (normalized == 'new message') {
      return 'رسالة جديدة';
    }
    if (normalized == 'medical record uploaded') {
      return 'تم رفع سجل طبي';
    }
    if (normalized == 'appointment reminder') {
      return 'تذكير بالموعد';
    }
    if (normalized == 'account security') {
      return 'أمان الحساب';
    }
    if (normalized == 'notification') {
      return 'إشعار';
    }
    return title;
  }

  String displayDescription(bool isArabic) {
    if (!isArabic) return description;
    final text = description.trim();
    final normalized = text.toLowerCase();
    final bookingMatch = RegExp(
      r'^your booking request for (.+) was sent to the care provider\.?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (bookingMatch != null) {
      final appointmentText = bookingMatch.group(1)!.trim();
      return 'تم إرسال طلب الحجز في $appointmentText إلى مقدم الرعاية.';
    }
    if (normalized ==
        'your doctor accepted the request. please complete payment before the appointment is confirmed.') {
      return 'قبِل مقدم الرعاية طلبك. يرجى إكمال الدفع قبل تأكيد الموعد.';
    }
    if (normalized == 'your appointment has been confirmed.' ||
        normalized == 'your appointment is confirmed.') {
      return 'تم تأكيد موعدك.';
    }
    if (normalized == 'doctor sent you a new message.' ||
        normalized == 'doctor sent you a message.') {
      return 'أرسل لك مقدم الرعاية رسالة جديدة.';
    }
    if (normalized == 'a provider added a file to your records.') {
      return 'أضاف مقدم الرعاية ملفاً إلى سجلاتك.';
    }
    return description;
  }
}

NotificationCategory _categoryFromType(String raw) {
  final type = raw.toLowerCase().replaceAll(' ', '_');
  if (type.contains('recommend') ||
      type.contains('match') ||
      type.contains('ai')) {
    return NotificationCategory.recommendation;
  }
  if (type.contains('payment') ||
      type.contains('invoice') ||
      type.contains('refund') ||
      type.contains('wallet')) {
    return NotificationCategory.payment;
  }
  if (type.contains('medical') ||
      type.contains('record') ||
      type.contains('report') ||
      type.contains('document')) {
    return NotificationCategory.medicalRecord;
  }
  if (type.contains('provider') ||
      type.contains('doctor') ||
      type.contains('nurse')) {
    return NotificationCategory.provider;
  }
  if (type.contains('message') || type.contains('chat')) {
    return NotificationCategory.message;
  }
  if (type.contains('appoint') ||
      type.contains('booking') ||
      type.contains('confirm') ||
      type.contains('remind') ||
      type.contains('reschedul') ||
      type.contains('cancel')) {
    return NotificationCategory.appointment;
  }
  return NotificationCategory.system;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.userId, this.userRole});

  final String? userId;
  final String? userRole;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool get _isDoctor =>
      (widget.userRole ?? '').trim().toLowerCase() == 'doctor';
  bool get _isArabic =>
      _isDoctor ? localeController.isDoctorArabic : localeController.isArabic;
  String _text(String english, String arabic) => _isArabic ? arabic : english;

  @override
  void initState() {
    super.initState();
    notificationCenter.load(widget.userId ?? '', force: true);
  }

  Future<void> _open(NotificationCardData notification) async {
    await notificationCenter.markRead(notification.id);
    if (!mounted) return;

    final userId = widget.userId ?? '';
    final role = (widget.userRole ?? '').trim().toLowerCase();
    switch (notification.category) {
      case NotificationCategory.appointment:
        final relatedId = notification.relatedId;
        if (role == 'doctor') {
          if (relatedId != null && relatedId.isNotEmpty) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DoctorBookingRequestDetailsScreen(requestId: relatedId),
              ),
            );
          }
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => relatedId != null && relatedId.isNotEmpty
                ? BookingDetailsScreen(
                    appointmentId: relatedId,
                    patientUserId: userId,
                  )
                : ScheduleScreen(patientUserId: userId),
          ),
        );
        return;
      case NotificationCategory.medicalRecord:
        final relatedId = notification.relatedId;
        if (relatedId != null && relatedId.isNotEmpty) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MedicalRecordDetailsScreen(
                recordId: relatedId,
                patientUserId: userId,
                requesterRole: 'patient',
              ),
            ),
          );
        }
        return;
      case NotificationCategory.payment:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientPaymentHistoryScreen(patientUserId: userId),
          ),
        );
        return;
      case NotificationCategory.recommendation:
      case NotificationCategory.provider:
      case NotificationCategory.message:
      case NotificationCategory.system:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        notificationCenter,
        localeController,
        themeController,
      ]),
      builder: (context, _) {
        final palette = CarelinkPalette.of(context);
        return Directionality(
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: PatientScaffold(
            enabled: !_isDoctor,
            backgroundColor: palette.pageBg,
            appBar: _buildAppBar(palette),
            body: _buildBody(palette),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(CarelinkPalette palette) {
    final count = notificationCenter.unreadCount;
    return AppBar(
      backgroundColor: palette.pageBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => Navigator.maybePop(context),
        icon: Icon(
          _isArabic
              ? Icons.arrow_forward_ios_rounded
              : Icons.arrow_back_ios_new_rounded,
          size: 19,
          color: palette.inkDark,
        ),
      ),
      titleSpacing: 0,
      title: Text(
        count == 0
            ? _text('Notifications', 'الإشعارات')
            : '${_text('Notifications', 'الإشعارات')} ($count)',
        style: TextStyle(
          color: palette.inkDark,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        if (count > 0)
          TextButton(
            onPressed: notificationCenter.markAllRead,
            child: Text(
              _text('Mark all as read', 'تعليم الكل كمقروء'),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildBody(CarelinkPalette palette) {
    if (notificationCenter.isLoading && notificationCenter.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final notifications =
        notificationCenter.items
            .map(
              (item) => NotificationCardData.fromJson(item, notificationCenter),
            )
            .toList()
          ..sort((a, b) {
            final aTime = a.at?.millisecondsSinceEpoch ?? 0;
            final bTime = b.at?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });

    if (notifications.isEmpty) {
      return _EmptyState(
        palette: palette,
        isArabic: _isArabic,
        hasError: notificationCenter.error != null,
        onRetry: () =>
            notificationCenter.load(widget.userId ?? '', force: true),
      );
    }

    final groups = <_DateGroup, List<NotificationCardData>>{
      _DateGroup.today: [],
      _DateGroup.yesterday: [],
      _DateGroup.earlier: [],
    };
    for (final notification in notifications) {
      groups[_dateGroup(notification.at)]!.add(notification);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          notificationCenter.load(widget.userId ?? '', force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (notificationCenter.error != null)
            _InlineError(palette: palette, isArabic: _isArabic),
          for (final group in _DateGroup.values)
            if (groups[group]!.isNotEmpty) ...[
              _GroupHeader(
                label: _groupLabel(group),
                count: groups[group]!.length,
                palette: palette,
              ),
              for (final notification in groups[group]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NotificationCard(
                    notification: notification,
                    palette: palette,
                    isArabic: _isArabic,
                    onTap: () => _open(notification),
                  ),
                ),
            ],
        ],
      ),
    );
  }

  String _groupLabel(_DateGroup group) {
    switch (group) {
      case _DateGroup.today:
        return _text('Today', 'اليوم');
      case _DateGroup.yesterday:
        return _text('Yesterday', 'أمس');
      case _DateGroup.earlier:
        return _text('Earlier', 'سابقاً');
    }
  }
}

enum _DateGroup { today, yesterday, earlier }

_DateGroup _dateGroup(DateTime? date) {
  if (date == null) return _DateGroup.earlier;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final value = date.isUtc ? date.toLocal() : date;
  final day = DateTime(value.year, value.month, value.day);
  final difference = today.difference(day).inDays;
  if (difference <= 0) return _DateGroup.today;
  if (difference == 1) return _DateGroup.yesterday;
  return _DateGroup.earlier;
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.count,
    required this.palette,
  });

  final String label;
  final int count;
  final CarelinkPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.inkDark,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$count',
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: palette.stroke)),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.palette,
    required this.isArabic,
    required this.onTap,
  });

  final NotificationCardData notification;
  final CarelinkPalette palette;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const unreadRed = Color(0xFFD93636);
    final unread = !notification.read;
    final title = notification.displayTitle(isArabic);
    final description = notification.displayDescription(isArabic);
    final tint = unread
        ? Color.alphaBlend(
            notification.accent.withValues(alpha: palette.isDark ? 0.10 : 0.05),
            palette.surface,
          )
        : palette.surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: palette.isDark ? 0.14 : 0.035,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 4,
                  color: unread ? notification.accent : Colors.transparent,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: notification.accent.withValues(
                              alpha: palette.isDark ? 0.18 : 0.11,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            notification.icon,
                            color: notification.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.inkDark,
                                        fontSize: 14,
                                        height: 1.25,
                                        fontWeight: unread
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (unread) ...[
                                    const SizedBox(width: 8),
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: SizedBox(
                                        width: 9,
                                        height: 9,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: unreadRed,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (description.trim().isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.inkMuted,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  Text(
                                    _relativeTime(notification.at, isArabic),
                                    style: TextStyle(
                                      color: palette.inkMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (notification.isActionable) ...[
                                    const Spacer(),
                                    Text(
                                      notification.actionLabel(isArabic),
                                      style: TextStyle(
                                        color: notification.accent,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      isArabic
                                          ? Icons.arrow_back_rounded
                                          : Icons.arrow_forward_rounded,
                                      color: notification.accent,
                                      size: 15,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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

String _relativeTime(DateTime? date, bool isArabic) {
  if (date == null) return '';
  final value = date.isUtc ? date.toLocal() : date;
  final difference = DateTime.now().difference(value);
  if (difference.isNegative || difference.inMinutes < 1) {
    return isArabic ? 'الآن' : 'Just now';
  }
  if (difference.inMinutes < 60) {
    return isArabic
        ? 'قبل ${difference.inMinutes} د'
        : '${difference.inMinutes}m ago';
  }
  if (difference.inHours < 24) {
    return isArabic
        ? 'قبل ${difference.inHours} س'
        : '${difference.inHours}h ago';
  }
  return isArabic ? 'قبل ${difference.inDays} ي' : '${difference.inDays}d ago';
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.palette, required this.isArabic});

  final CarelinkPalette palette;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFD93636).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isArabic
            ? 'تعذر تحديث الإشعارات. تعرض آخر نسخة محفوظة.'
            : 'Could not refresh notifications. Showing the latest saved state.',
        textAlign: TextAlign.center,
        style: TextStyle(color: palette.inkMuted, fontSize: 12),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.palette,
    required this.isArabic,
    required this.hasError,
    required this.onRetry,
  });

  final CarelinkPalette palette;
  final bool isArabic;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRetry(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 90, 28, 30),
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              color: AppColors.primary,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            hasError
                ? (isArabic
                      ? 'تعذر تحميل الإشعارات'
                      : 'Notifications unavailable')
                : (isArabic ? 'أنت على اطلاع بكل شيء' : "You're all caught up"),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.inkDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            hasError
                ? (isArabic
                      ? 'تحقق من اتصالك وحاول مرة أخرى.'
                      : 'Check your connection and try again.')
                : (isArabic
                      ? 'ستظهر هنا تحديثات المواعيد والتوصيات والسجلات والمدفوعات.'
                      : 'Appointment updates, recommendations, records, and payments will appear here.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 20),
            Center(
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isArabic ? 'إعادة المحاولة' : 'Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

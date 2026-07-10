import 'dart:async';

import 'package:flutter/material.dart';

import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';

import 'nurse_ui.dart';

enum _NurseNotificationFilter { all, requests, visits, messages, system }

enum _NurseNotificationKind {
  request,
  arrival,
  inProgress,
  completed,
  report,
  message,
  reminder,
  system,
}

class _NurseNotificationItem {
  const _NurseNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.isRead,
    required this.createdAt,
    this.location = '',
    this.timeText = '',
    this.status = '',
    this.relatedRequestId,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final bool isRead;
  final DateTime createdAt;
  final String location;
  final String timeText;
  final String status;
  final String? relatedRequestId;

  factory _NurseNotificationItem.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['createdAt']?.toString() ?? '';
    return _NurseNotificationItem(
      id: (json['notificationId'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? 'Notification').toString(),
      description: (json['message'] ?? json['body'] ?? '').toString(),
      isRead:
          json['isRead'] == true ||
          json['isRead'] == 1 ||
          json['isRead']?.toString() == '1',
      createdAt: DateTime.tryParse(rawCreated) ?? DateTime.now(),
      location: (json['location'] ?? json['address'] ?? '').toString(),
      timeText: (json['time'] ?? json['scheduledTime'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      relatedRequestId: (json['relatedRequestId'] ?? '').toString().trim(),
    );
  }

  _NurseNotificationKind get kind {
    final source = '$type $title $description'.toLowerCase();
    if (source.contains('message') || source.contains('chat')) {
      return _NurseNotificationKind.message;
    }
    if (source.contains('arrival') || source.contains('arrived')) {
      return _NurseNotificationKind.arrival;
    }
    if (source.contains('progress') || source.contains('started')) {
      return _NurseNotificationKind.inProgress;
    }
    if (source.contains('completed') || source.contains('complete')) {
      return _NurseNotificationKind.completed;
    }
    if (source.contains('report')) return _NurseNotificationKind.report;
    if (source.contains('reminder') || source.contains('upcoming')) {
      return _NurseNotificationKind.reminder;
    }
    if (source.contains('request') ||
        source.contains('appointment') ||
        source.contains('booking')) {
      return _NurseNotificationKind.request;
    }
    return _NurseNotificationKind.system;
  }
}

class NotificationsReadOnlyScreen extends StatefulWidget {
  const NotificationsReadOnlyScreen({super.key, required this.user});

  final User user;

  @override
  State<NotificationsReadOnlyScreen> createState() =>
      _NotificationsReadOnlyScreenState();
}

class NurseNotificationsScreen extends NotificationsReadOnlyScreen {
  const NurseNotificationsScreen({super.key, required super.user});
}

class _NotificationsReadOnlyScreenState
    extends State<NotificationsReadOnlyScreen> {
  final api = ApiService();
  Timer? refreshTimer;
  var selectedFilter = _NurseNotificationFilter.all;
  var isLoading = true;
  List<_NurseNotificationItem> notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => isLoading = true);
    try {
      final raw = await api.getNotifications(widget.user.userId);
      final loaded = raw
          .whereType<Map>()
          .map((item) => _NurseNotificationItem.fromJson(Map.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        notifications = loaded;
        isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((item) => !item.isRead).length;
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(unreadCount),
              _filters(),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0F766E),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF0F766E),
                        onRefresh: _load,
                        child: _visibleNotifications.isEmpty
                            ? _emptyState()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  112,
                                ),
                                itemBuilder: (context, index) {
                                  return _notificationCard(
                                    _visibleNotifications[index],
                                  );
                                },
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemCount: _visibleNotifications.length,
                              ),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _bottomNav(),
      ),
    );
  }

  Widget _topBar(int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF0F766E),
                size: 34,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -7,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Text(
              NurseUi.t('Notifications'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NurseUi.text,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(
            Icons.filter_alt_outlined,
            color: Color(0xFF0F766E),
            size: 32,
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    final filters = [
      (_NurseNotificationFilter.all, NurseUi.t('All'), notifications.length),
      (
        _NurseNotificationFilter.requests,
        NurseUi.isArabic.value ? 'طلبات جديدة' : 'New Requests',
        _count(_NurseNotificationFilter.requests),
      ),
      (
        _NurseNotificationFilter.visits,
        NurseUi.isArabic.value ? 'حالة الزيارة' : 'Visit Status',
        _count(_NurseNotificationFilter.visits),
      ),
      (
        _NurseNotificationFilter.messages,
        NurseUi.t('Messages'),
        _count(_NurseNotificationFilter.messages),
      ),
      (
        _NurseNotificationFilter.system,
        NurseUi.t('System'),
        _count(_NurseNotificationFilter.system),
      ),
    ];
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index].$1;
          final selected = selectedFilter == filter;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: index == 0 ? 150 : 178,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF0F766E) : NurseUi.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF0F766E)
                      : NurseUi.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Text(
                '${filters[index].$2} (${filters[index].$3})',
                style: TextStyle(
                  color: selected ? Colors.white : NurseUi.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<_NurseNotificationItem> get _visibleNotifications {
    return notifications.where((item) {
      switch (selectedFilter) {
        case _NurseNotificationFilter.all:
          return true;
        case _NurseNotificationFilter.requests:
          return item.kind == _NurseNotificationKind.request;
        case _NurseNotificationFilter.visits:
          return item.kind == _NurseNotificationKind.arrival ||
              item.kind == _NurseNotificationKind.inProgress ||
              item.kind == _NurseNotificationKind.completed ||
              item.kind == _NurseNotificationKind.report ||
              item.kind == _NurseNotificationKind.reminder;
        case _NurseNotificationFilter.messages:
          return item.kind == _NurseNotificationKind.message;
        case _NurseNotificationFilter.system:
          return item.kind == _NurseNotificationKind.system;
      }
    }).toList();
  }

  Widget _notificationCard(_NurseNotificationItem item) {
    final meta = _meta(item.kind);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NurseUi.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _leadingIcon(meta),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.kind == _NurseNotificationKind.request)
                  _newBadge(meta.color),
                Text(
                  item.title.isEmpty ? meta.fallbackTitle : item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: item.kind == _NurseNotificationKind.reminder
                        ? const Color(0xFFEF4444)
                        : NurseUi.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description.isEmpty
                      ? meta.fallbackDescription
                      : item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: NurseUi.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    if (item.location.trim().isNotEmpty)
                      _infoChip(
                        Icons.location_on_outlined,
                        item.location.trim(),
                        meta.color,
                      ),
                    _infoChip(
                      Icons.access_time_rounded,
                      _timeText(item),
                      meta.color,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _relativeTime(item.createdAt),
                style: TextStyle(
                  color: NurseUi.muted,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.isRead ? const Color(0xFFCBD5E1) : meta.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leadingIcon(_NotificationMeta meta) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: meta.color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(meta.icon, color: meta.color, size: 38),
        ),
        Positioned(
          right: -2,
          bottom: 5,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: meta.color,
              shape: BoxShape.circle,
              border: Border.all(color: NurseUi.surface, width: 3),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _newBadge(Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        NurseUi.isArabic.value ? 'جديد' : 'New',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: NurseUi.muted,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 140),
      children: [
        const Icon(
          Icons.notifications_none_rounded,
          size: 64,
          color: Color(0xFF94A3B8),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            NurseUi.isArabic.value ? 'لا توجد إشعارات' : 'No notifications available',
            style: TextStyle(
              color: NurseUi.muted,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomNav() {
    final items = [
      (Icons.home_rounded, NurseUi.t('Home')),
      (Icons.calendar_month_rounded, NurseUi.t('Sessions')),
      (Icons.groups_rounded, NurseUi.t('Patients')),
      (Icons.description_rounded, NurseUi.t('Reports')),
      (Icons.person_rounded, NurseUi.t('Profile')),
    ];
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: NurseUi.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NurseUi.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, color: NurseUi.muted),
                const SizedBox(height: 3),
                Text(
                  item.$2,
                  style: TextStyle(
                    color: NurseUi.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  int _count(_NurseNotificationFilter filter) {
    return notifications.where((item) {
      switch (filter) {
        case _NurseNotificationFilter.all:
          return true;
        case _NurseNotificationFilter.requests:
          return item.kind == _NurseNotificationKind.request;
        case _NurseNotificationFilter.visits:
          return item.kind == _NurseNotificationKind.arrival ||
              item.kind == _NurseNotificationKind.inProgress ||
              item.kind == _NurseNotificationKind.completed ||
              item.kind == _NurseNotificationKind.report ||
              item.kind == _NurseNotificationKind.reminder;
        case _NurseNotificationFilter.messages:
          return item.kind == _NurseNotificationKind.message;
        case _NurseNotificationFilter.system:
          return item.kind == _NurseNotificationKind.system;
      }
    }).length;
  }

  String _timeText(_NurseNotificationItem item) {
    final explicit = item.timeText.trim();
    if (explicit.isNotEmpty) return explicit;
    return _formatTime(item.createdAt);
  }

  String _formatTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:${m.padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour ago';
    return '${diff.inDays} day ago';
  }

  _NotificationMeta _meta(_NurseNotificationKind kind) {
    switch (kind) {
      case _NurseNotificationKind.request:
        return const _NotificationMeta(
          Icons.assignment_turned_in_rounded,
          Color(0xFF0F766E),
          'New Service Request',
          'You have a new home nursing request.',
        );
      case _NurseNotificationKind.arrival:
        return const _NotificationMeta(
          Icons.location_on_rounded,
          Color(0xFF22C55E),
          'Arrival Verified',
          'You have arrived at the patient location.',
        );
      case _NurseNotificationKind.inProgress:
        return const _NotificationMeta(
          Icons.timer_rounded,
          Color(0xFF3B82F6),
          'Visit In Progress',
          'The visit with the patient has started.',
        );
      case _NurseNotificationKind.completed:
        return const _NotificationMeta(
          Icons.assignment_turned_in_rounded,
          Color(0xFF8B5CF6),
          'Service Completed',
          'You have completed the visit successfully.',
        );
      case _NurseNotificationKind.report:
        return const _NotificationMeta(
          Icons.description_rounded,
          Color(0xFF0F766E),
          'Report Submitted',
          'The visit report has been submitted.',
        );
      case _NurseNotificationKind.message:
        return const _NotificationMeta(
          Icons.chat_bubble_rounded,
          Color(0xFFF59E0B),
          'New Message from Patient',
          'You have a new message from the patient.',
        );
      case _NurseNotificationKind.reminder:
        return const _NotificationMeta(
          Icons.notifications_rounded,
          Color(0xFFEF4444),
          'Upcoming Visit Reminder',
          'You have a visit scheduled soon.',
        );
      case _NurseNotificationKind.system:
        return const _NotificationMeta(
          Icons.info_rounded,
          Color(0xFF64748B),
          'System Notification',
          'You have a new system update.',
        );
    }
  }
}

class _NotificationMeta {
  const _NotificationMeta(
    this.icon,
    this.color,
    this.fallbackTitle,
    this.fallbackDescription,
  );

  final IconData icon;
  final Color color;
  final String fallbackTitle;
  final String fallbackDescription;
}



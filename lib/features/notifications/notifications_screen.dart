import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/shared/services/api_service.dart';

const Color _kTimeGrey = Color(0xFF8A9BA3);

enum NotificationStyle { appointment, message, medical, reminder, security }

class NotificationCardData {
  NotificationCardData({
    required this.id,
    required this.title,
    required this.description,
    this.at,
    required this.style,
    this.read = false,
  });

  final String id;
  final String title;
  final String description;
  final DateTime? at;
  final NotificationStyle style;
  bool read;

  Color get _accent {
    switch (style) {
      case NotificationStyle.appointment:
        return const Color(0xFF0D9488);
      case NotificationStyle.message:
        return const Color(0xFF2563EB);
      case NotificationStyle.medical:
        return const Color(0xFF7C3AED);
      case NotificationStyle.reminder:
        return const Color(0xFFEA580C);
      case NotificationStyle.security:
        return const Color(0xFF059669);
    }
  }

  Color get chipBackground {
    switch (style) {
      case NotificationStyle.appointment:
        return const Color(0xFFCCF2EE);
      case NotificationStyle.message:
        return const Color(0xFFDCEBFC);
      case NotificationStyle.medical:
        return const Color(0xFFE6E0FC);
      case NotificationStyle.reminder:
        return const Color(0xFFFEE8D4);
      case NotificationStyle.security:
        return const Color(0xFFD1FAE4);
    }
  }

  Color get iconColor => _accent;

  Color get dotColor => read ? const Color(0xFFCBD5E0) : _accent;

  IconData get icon {
    switch (style) {
      case NotificationStyle.appointment:
        return Icons.event_available_rounded;
      case NotificationStyle.message:
        return Icons.chat_bubble_rounded;
      case NotificationStyle.medical:
        return Icons.description_rounded;
      case NotificationStyle.reminder:
        return Icons.schedule_rounded;
      case NotificationStyle.security:
        return Icons.verified_user_rounded;
    }
  }
}

String _formatRelativeTimeShort(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.isNegative) return 'Just now';
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) {
    return d.inMinutes <= 1 ? '1 min ago' : '${d.inMinutes} min ago';
  }
  if (d.inHours < 24) {
    return d.inHours <= 1 ? '1 hr ago' : '${d.inHours} hr ago';
  }
  if (d.inDays < 7) {
    return d.inDays == 1 ? '1 day ago' : '${d.inDays} days ago';
  }
  return '${t.day}/${t.month}/${t.year}';
}

NotificationStyle? _styleFromType(String? raw) {
  if (raw == null) return null;
  final s = raw.toLowerCase().replaceAll(' ', '_');
  if (s.contains('message') || s.contains('chat')) {
    return NotificationStyle.message;
  }
  if (s.contains('medical') || s.contains('record') || s.contains('document')) {
    return NotificationStyle.medical;
  }
  if (s.contains('remind')) return NotificationStyle.reminder;
  if (s.contains('security') || s.contains('account')) {
    return NotificationStyle.security;
  }
  if (s.contains('appoint') || s.contains('confirm')) {
    return NotificationStyle.appointment;
  }
  return null;
}

NotificationCardData? _fromJson(Map<String, dynamic> m) {
  var id = (m['id'] ?? m['notificationId'] ?? '').toString();
  final title = (m['title'] ?? m['subject'] ?? m['type'] ?? 'Notification')
      .toString();
  final body = (m['body'] ?? m['message'] ?? m['text'] ?? '').toString();
  final read = m['isRead'] == true || m['read'] == true;
  final createdRaw = m['createdAt'] ?? m['created'] ?? m['timestamp'];
  DateTime? at;
  if (createdRaw != null) {
    if (createdRaw is DateTime) {
      at = createdRaw;
    } else {
      at = DateTime.tryParse(createdRaw.toString());
    }
  }
  final st =
      _styleFromType(m['type']?.toString() ?? m['category']?.toString()) ??
      _styleFromType(title) ??
      NotificationStyle.appointment;
  if (id.isEmpty) {
    id = 'n-${(title + body + (at?.toIso8601String() ?? '')).hashCode}';
  }
  return NotificationCardData(
    id: id,
    title: title,
    description: body.isNotEmpty
        ? body
        : 'You have a new notification for your CareLink account.',
    at: at,
    style: st,
    read: read,
  );
}

List<NotificationCardData> _demoList() {
  final now = DateTime.now();
  return [
    NotificationCardData(
      id: 'demo-1',
      title: 'Appointment Confirmed',
      description: 'Your appointment has been confirmed.',
      at: now.subtract(const Duration(minutes: 2)),
      style: NotificationStyle.appointment,
      read: false,
    ),
    NotificationCardData(
      id: 'demo-2',
      title: 'New Message',
      description: 'Doctor sent you a new message.',
      at: now.subtract(const Duration(hours: 1)),
      style: NotificationStyle.message,
      read: false,
    ),
    NotificationCardData(
      id: 'demo-3',
      title: 'Medical Record Uploaded',
      description: 'A new file was added to your records.',
      at: now.subtract(const Duration(days: 1)),
      style: NotificationStyle.medical,
      read: true,
    ),
    NotificationCardData(
      id: 'demo-4',
      title: 'Appointment Reminder',
      description: 'Appointment tomorrow at 10:00 AM.',
      at: now.subtract(const Duration(days: 1, hours: 2)),
      style: NotificationStyle.reminder,
      read: true,
    ),
    NotificationCardData(
      id: 'demo-5',
      title: 'Account Security',
      description: 'Your email was used to sign in on a new device.',
      at: now.subtract(const Duration(days: 2)),
      style: NotificationStyle.security,
      read: true,
    ),
  ];
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.userId});

  final String? userId;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationCardData> _items = [];
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

    final id = widget.userId?.trim();
    if (id == null || id.isEmpty) {
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }

    try {
      final raw = await ApiService().getNotifications(id);
      if (!mounted) return;
      final list = <NotificationCardData>[];
      for (final e in raw) {
        if (e is! Map<String, dynamic>) continue;
        final p = _fromJson(e);
        if (p != null) list.add(p);
      }
      setState(() {
        _items = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _items = _demoList();
        _loading = false;
      });
    }
  }

  void _markAllRead() {
    setState(() {
      for (final n in _items) {
        n.read = true;
      }
    });
  }

  void _onTapCard(NotificationCardData n) {
    if (!n.read) setState(() => n.read = true);
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildHeader(p),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _items.isEmpty
                ? _buildEmpty()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                          child: Text(
                            'Could not connect to the server. Showing sample notifications.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: p.inkMuted),
                          ),
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _load,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    16,
                                    20,
                                    8,
                                  ),
                                  child: Text(
                                    'Recent',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: p.inkDark,
                                    ),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  32,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    i,
                                  ) {
                                    final n = _items[i];
                                    return _NotificationCard(
                                      data: n,
                                      onTap: () => _onTapCard(n),
                                    );
                                  }, childCount: _items.length),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final p = CarelinkPalette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        if (widget.userId == null || widget.userId!.trim().isEmpty) ...[
          Text(
            'Sign in to load your notifications.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
        ],
        _DashedEmptyPanel(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ...List.generate(8, (i) {
                        return Positioned(
                          top: 8 + (i * 2.0) * (i % 2 == 0 ? 1 : -0.6),
                          left: 10 + (i * 4.0) * (i % 3 == 0 ? 1 : 0.3),
                          child: Opacity(
                            opacity: 0.4,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: i.isEven
                                    ? const Color(0xFF99F6E4)
                                    : const Color(0xFFBAE6FD),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFECFDF5,
                          ).withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 44,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No notifications yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: p.inkDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You will see your updates here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: p.inkMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
              'Notifications',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.inkDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: _items.isEmpty ? null : _markAllRead,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              disabledForegroundColor: p.inkMuted.withValues(alpha: 0.45),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Read all',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.stroke),
            ),
            child: CarelinkThemeIconButton(color: p.inkDark),
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

/// Rounded-rect dash border (no extra package).
class _DashedRRectPainter extends CustomPainter {
  static const Color _c = Color(0xFFCCCCCC);
  static const double _sw = 1.2;
  static const double _r = 16;
  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(_sw / 2, _sw / 2, size.width - _sw, size.height - _sw),
      const Radius.circular(_r),
    );
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = _c
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sw;

    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final len = (d + _dash).clamp(0.0, metric.length) - d;
        if (len > 0) {
          canvas.drawPath(metric.extractPath(d, d + len), paint);
        }
        d += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedEmptyPanel extends StatelessWidget {
  const _DashedEmptyPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DashedRRectPainter(), child: child);
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.data, required this.onTap});

  final NotificationCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.stroke, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: p.isDark ? 0.18 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: data.chipBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(data.icon, color: data.iconColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: p.inkDark,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: p.inkMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: _kTimeGrey.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatRelativeTimeShort(data.at),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _kTimeGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 56,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: data.dotColor,
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(
                          Icons.chevron_right,
                          color: p.inkMuted.withValues(alpha: 0.5),
                          size: 24,
                        ),
                      ),
                    ],
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

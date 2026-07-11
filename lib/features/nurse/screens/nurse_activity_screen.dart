import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/chat_repository.dart';
import 'package:carelink/shared/widgets/carelink_floating_bottom_nav.dart';

import 'nurse_conversation_threads.dart';
import 'nurse_contact_patient_flow.dart';
import 'nurse_service_requests.dart';
import 'nurse_ui.dart';

enum ActivityTab { messages, ratings, alerts }

enum _RatingFilter { allTime, lastMonth, lastWeek }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    required this.user,
    this.initialTab = ActivityTab.messages,
    this.onBottomNavigationTap,
    this.onRateAccepted,
    this.showBottomNavigation = true,
  });

  final User user;
  final ActivityTab initialTab;
  final ValueChanged<int>? onBottomNavigationTap;
  final VoidCallback? onRateAccepted;
  final bool showBottomNavigation;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static Color get _background => NurseUi.background;
  static Color get _primary => AppColors.primary;
  static Color get _border => NurseUi.border;
  static const Color _star = Color(0xFFFBBF24);
  static Color get _text => NurseUi.text;
  static Color get _muted => NurseUi.muted;

  final ChatRepository chatRepository = ChatRepository();
  final ApiService api = ApiService();

  Timer? refreshTimer;
  var selectedTab = ActivityTab.messages;
  var ratingFilter = _RatingFilter.allTime;
  var isLoading = true;
  String? error;

  List<ChatConversation> messages = [];
  List<_PatientRating> ratings = [];
  List<_ActivityAlert> alerts = [];

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialTab;
    _load();
    refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        isLoading = true;
        error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        chatRepository.getConversations(widget.user.userId),
        api.getProviderRatingsAggregate(widget.user.userId, limit: 200),
        api.getNotifications(widget.user.userId),
      ]);
      if (!mounted) return;
      final ratingMap = Map<String, dynamic>.from(results[1] as Map);
      final ratingItems = (ratingMap['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => _PatientRating.fromJson(Map.from(item)))
          .toList();
      final alertItems = (results[2] as List)
          .whereType<Map>()
          .map((item) => _ActivityAlert.fromJson(Map.from(item)))
          .toList();
      setState(() {
        messages = List<ChatConversation>.from(
          results[0] as List<ChatConversation>,
        );
        ratings = ratingItems;
        alerts = alertItems;
        isLoading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        isLoading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifications = alerts.where((alert) => !alert.isRead).length;
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(unreadNotifications),
              _tabs(),
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator(color: _primary))
                    : error != null
                    ? _errorState()
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: RefreshIndicator(
                          key: ValueKey(selectedTab),
                          color: _primary,
                          onRefresh: _load,
                          child: _tabBody(),
                        ),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: widget.showBottomNavigation
            ? _bottomNavigationBar()
            : null,
      ),
    );
  }

  Widget _topBar(int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              NurseUi.t('Notifications'),
              style: TextStyle(
                color: _text,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          NurseModeControls(providerUserId: widget.user.userId),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none_rounded, color: _primary, size: 32),
              if (unreadCount > 0)
                Positioned(right: -7, top: -7, child: _badge(unreadCount)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    final tabs = [
      (ActivityTab.messages, Icons.chat_bubble_outline_rounded, 'Messages'),
      (ActivityTab.ratings, Icons.star_border_rounded, 'Ratings'),
      (ActivityTab.alerts, Icons.notifications_none_rounded, 'Alerts'),
    ];
    return Container(
      height: 58,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: _shadow,
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _selectTab(tab.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectedTab == tab.$1 ? _primary : NurseUi.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.$2,
                        color: selectedTab == tab.$1 ? Colors.white : _muted,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          NurseUi.t(tab.$3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selectedTab == tab.$1
                                ? Colors.white
                                : _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabBody() {
    switch (selectedTab) {
      case ActivityTab.messages:
        return _messagesList();
      case ActivityTab.ratings:
        return _ratingsList();
      case ActivityTab.alerts:
        return _alertsList();
    }
  }

  void _selectTab(ActivityTab tab) {
    if (selectedTab == tab) return;
    setState(() => selectedTab = tab);
    _load(silent: true);
  }

  Widget _messagesList() {
    final threads = groupNurseConversationsByPatient(messages);
    if (threads.isEmpty) {
      return _emptyList(Icons.chat_bubble_outline_rounded, 'No messages yet');
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 112),
      itemCount: threads.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _messageCard(threads[index]),
    );
  }

  Widget _messageCard(NurseConversationThread thread) {
    final conversation = thread.latest;
    final name = thread.patientName.trim().isEmpty
        ? 'Patient'
        : thread.patientName.trim();
    return _activityCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientMessageScreen(
              request: ServiceRequest(
                id: conversation.requestId,
                patientId: conversation.patientId,
                providerId: conversation.nurseId,
                patientName: name,
                serviceType: '',
                location: '',
                scheduledDate: DateTime.now(),
                status: 'assigned',
                createdAt: DateTime.now(),
              ),
              currentUserId: widget.user.userId,
              threadConversations: thread.conversations,
            ),
          ),
        ).then((_) => _load(silent: true));
      },
      child: Row(
        children: [
          _avatar(name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      conversation.lastMessageAt == null
                          ? ''
                          : _relativeTime(conversation.lastMessageAt!),
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  thread.lastMessage.trim().isEmpty
                      ? 'No messages yet'
                      : thread.lastMessage.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (thread.unreadCount > 0) _greenBadge(thread.unreadCount),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, color: _primary, size: 17),
        ],
      ),
    );
  }

  Widget _ratingsList() {
    final visible = _filteredRatings;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 112),
      children: [
        _ratingFilter(),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          _emptyContent(Icons.star_border_rounded, 'No ratings yet')
        else
          for (final rating in visible) ...[
            _ratingCard(rating),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  List<_PatientRating> get _filteredRatings {
    final now = DateTime.now();
    return ratings.where((rating) {
      switch (ratingFilter) {
        case _RatingFilter.allTime:
          return true;
        case _RatingFilter.lastMonth:
          return rating.createdAt.isAfter(
            now.subtract(const Duration(days: 30)),
          );
        case _RatingFilter.lastWeek:
          return rating.createdAt.isAfter(
            now.subtract(const Duration(days: 7)),
          );
      }
    }).toList();
  }

  Widget _ratingFilter() {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: _shadow,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_RatingFilter>(
            value: ratingFilter,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            borderRadius: BorderRadius.circular(14),
            items: [
              DropdownMenuItem(
                value: _RatingFilter.allTime,
                child: Text(NurseUi.t('All Time')),
              ),
              DropdownMenuItem(
                value: _RatingFilter.lastMonth,
                child: Text(NurseUi.t('Last Month')),
              ),
              DropdownMenuItem(
                value: _RatingFilter.lastWeek,
                child: Text(NurseUi.t('Last Week')),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => ratingFilter = value);
            },
          ),
        ),
      ),
    );
  }

  Widget _ratingCard(_PatientRating rating) {
    return _activityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(rating.patientName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rating.serviceType.isEmpty
                          ? NurseUi.t('Nursing service')
                          : NurseUi.serviceLabel(rating.serviceType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dateTime(rating.createdAt),
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _ratingValue(rating.ratingValue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  Icons.star_rounded,
                  color: i <= rating.ratingValue.round()
                      ? _star
                      : const Color(0xFFE5E7EB),
                  size: 22,
                ),
            ],
          ),
          if (rating.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '"${rating.comment.trim()}"',
                style: TextStyle(
                  color: _text,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _alertsList() {
    if (alerts.isEmpty) {
      return _emptyList(Icons.notifications_none_rounded, 'No alerts yet');
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 112),
      itemCount: alerts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _alertCard(alerts[index]),
    );
  }

  Widget _alertCard(_ActivityAlert alert) {
    final meta = alert.meta;
    final title = _localizedAlertTitle(alert, meta);
    final description = _localizedAlertDescription(alert, meta);
    return _activityCard(
      onTap: () {
        if (alert.isRateDecisionAlert) {
          _showRateDecisionDialog(alert);
          return;
        }
        if (alert.relatedRequestId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NurseServiceRequests(user: widget.user),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(meta.icon, color: meta.color, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  _relativeTime(alert.createdAt),
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (alert.isRateDecisionAlert) ...[
                  const SizedBox(height: 8),
                  Text(
                    NurseUi.t('Tap to accept or reject this hourly rate.'),
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: alert.isRead ? const Color(0xFFCBD5E1) : meta.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  String _localizedAlertTitle(_ActivityAlert alert, _AlertMeta meta) {
    final raw = alert.title.trim();
    if (raw.isEmpty) return NurseUi.t(meta.title);
    final lower = raw.toLowerCase();
    if (alert.isRateDecisionAlert || lower.contains('hourly rate')) {
      return NurseUi.t('Hourly rate set');
    }
    if (lower.contains('booking') || lower.contains('request')) {
      return NurseUi.t('New booking request');
    }
    return NurseUi.t(raw);
  }

  String _localizedAlertDescription(_ActivityAlert alert, _AlertMeta meta) {
    final raw = alert.description.trim();
    if (raw.isEmpty) return NurseUi.t(meta.description);
    final lower = raw.toLowerCase();
    if (alert.isRateDecisionAlert ||
        lower.contains('hourly rate') ||
        lower.contains('accept it before starting work')) {
      final amountMatch = RegExp(r'(\d+(?:\.\d+)?)\s*ILS').firstMatch(raw);
      final amount = amountMatch?.group(1);
      if (amount != null && amount.isNotEmpty) {
        return NurseUi.isArabic.value
            ? 'حددت الإدارة سعر الساعة الخاص بك بقيمة $amount ${NurseUi.t('ILS')}. يرجى قبوله قبل بدء العمل.'
            : 'Admin set your hourly rate to $amount ILS. Please accept it before starting work.';
      }
      return NurseUi.t(
        'Please accept the admin hourly rate before starting work.',
      );
    }
    if (lower.contains('booked') ||
        lower.contains('booking') ||
        lower.contains('service requests')) {
      return NurseUi.t('You have a new service request.');
    }
    return NurseUi.t(raw);
  }

  Future<void> _showRateDecisionDialog(_ActivityAlert alert) async {
    final description = _localizedAlertDescription(alert, alert.meta);
    final decision = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          NurseUi.t('Hourly rate approval'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          description.isEmpty
              ? NurseUi.t(
                  'Admin set your hourly rate. Please accept it before starting work.',
                )
              : description,
          style: const TextStyle(height: 1.45, fontWeight: FontWeight.w700),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'rejected'),
                  icon: const Icon(Icons.close_rounded),
                  label: Text(NurseUi.t('Reject Rate')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, 'accepted'),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(NurseUi.t('Accept Rate')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (decision == null) return;
    await _submitRateDecision(decision);
  }

  Future<void> _submitRateDecision(String decision) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiService.baseUrl}/nurse/rate-status/${widget.user.userId}/decision',
        ),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'decision': decision}),
      );
      final body = response.body.trim().isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = body is Map<String, dynamic>
            ? body['error']?.toString()
            : null;
        throw Exception(message ?? 'Failed to update hourly rate decision');
      }
      await _load(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'accepted'
                ? NurseUi.t(
                    'Hourly rate accepted. You can add slots and accept patients now.',
                  )
                : NurseUi.t(
                    'Hourly rate rejected. Availability and patient requests stay locked.',
                  ),
          ),
        ),
      );
      if (decision == 'accepted') {
        widget.onRateAccepted?.call();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _activityCard({required Widget child, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NurseUi.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border.withValues(alpha: 0.7)),
            boxShadow: _shadow,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _avatar(String name) {
    final clean = name.trim();
    return CircleAvatar(
      radius: 25,
      backgroundColor: const Color(0xFFDDF2EF),
      child: Text(
        clean.isEmpty ? 'P' : clean.characters.first.toUpperCase(),
        style: TextStyle(
          color: _primary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _ratingValue(double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _star.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: _star, size: 17),
          const SizedBox(width: 4),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(color: _text, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _badge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _greenBadge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
      child: Center(
        child: Text(
          count > 9 ? '9+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _emptyList(IconData icon, String text) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 150),
      children: [_emptyContent(icon, text)],
    );
  }

  Widget _emptyContent(IconData icon, String text) {
    return Center(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 54),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(color: _muted, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 150, 24, 24),
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFEF4444),
          size: 52,
        ),
        const SizedBox(height: 12),
        Text(
          error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFEF4444),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton(
            onPressed: _load,
            child: Text(NurseUi.t('Retry')),
          ),
        ),
      ],
    );
  }

  List<BoxShadow> get _shadow => NurseUi.softShadow;

  Widget _bottomNavigationBar() {
    final items = [
      CarelinkFloatingNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: NurseUi.t('Home'),
      ),
      CarelinkFloatingNavItem(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month_rounded,
        label: NurseUi.t('Sessions'),
      ),
      CarelinkFloatingNavItem(
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: NurseUi.t('Patients'),
      ),
      CarelinkFloatingNavItem(
        icon: Icons.notifications_none_rounded,
        activeIcon: Icons.notifications_rounded,
        label: NurseUi.t('Alerts'),
      ),
      CarelinkFloatingNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: NurseUi.t('Profile'),
      ),
    ];
    return CarelinkFloatingBottomNav(
      items: items,
      currentIndex: 3,
      onTap: _handleBottomNavigationTap,
    );
  }

  void _handleBottomNavigationTap(int index) {
    if (index == 3) return;
    final handler = widget.onBottomNavigationTap;
    if (handler != null) {
      handler(index);
      return;
    }
    Navigator.maybePop(context);
  }
}

class PatientRatingsScreen extends StatelessWidget {
  const PatientRatingsScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return ActivityScreen(user: user, initialTab: ActivityTab.ratings);
  }
}

class _PatientRating {
  const _PatientRating({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.ratingValue,
    required this.comment,
    required this.serviceType,
    required this.createdAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final double ratingValue;
  final String comment;
  final String serviceType;
  final DateTime createdAt;

  factory _PatientRating.fromJson(Map<String, dynamic> json) {
    return _PatientRating(
      id: (json['ratingId'] ?? json['id'] ?? '').toString(),
      patientId: (json['patientUserId'] ?? json['patientId'] ?? '').toString(),
      patientName: (json['patientName'] ?? 'Patient').toString(),
      ratingValue:
          double.tryParse(json['stars']?.toString() ?? '') ??
          double.tryParse(json['ratingValue']?.toString() ?? '') ??
          0,
      comment: (json['comment'] ?? '').toString(),
      serviceType: (json['reasonForVisit'] ?? json['serviceType'] ?? '')
          .toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class _ActivityAlert {
  const _ActivityAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.isRead,
    required this.relatedRequestId,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final DateTime createdAt;
  final bool isRead;
  final String relatedRequestId;

  factory _ActivityAlert.fromJson(Map<String, dynamic> json) {
    return _ActivityAlert(
      id: (json['notificationId'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['message'] ?? json['body'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead:
          json['isRead'] == true ||
          json['isRead'] == 1 ||
          json['isRead']?.toString() == '1',
      relatedRequestId: (json['relatedRequestId'] ?? '').toString(),
    );
  }

  bool get isRateDecisionAlert {
    final value = '$type $title $description'.toLowerCase();
    return value.contains('hourly rate') ||
        value.contains('rate set') ||
        value.contains('accept it before starting work');
  }

  _AlertMeta get meta {
    final value = '$type $title $description'.toLowerCase();
    if (isRateDecisionAlert) {
      return const _AlertMeta(
        Icons.payments_outlined,
        Color(0xFF0F766E),
        'Hourly rate set',
        'Please accept the admin hourly rate before starting work.',
      );
    }
    if (value.contains('arrival') || value.contains('arrived')) {
      return const _AlertMeta(
        Icons.location_on_outlined,
        Color(0xFF22C55E),
        'Arrival Verified',
        'You have arrived at patient location.',
      );
    }
    if (value.contains('progress') || value.contains('started')) {
      return const _AlertMeta(
        Icons.timer_outlined,
        Color(0xFF3B82F6),
        'Visit In Progress',
        'Visit is currently in progress.',
      );
    }
    if (value.contains('completed') || value.contains('complete')) {
      return const _AlertMeta(
        Icons.check_circle_outline_rounded,
        Color(0xFF22C55E),
        'Completed Visit',
        'The visit has been completed.',
      );
    }
    if (value.contains('message') || value.contains('chat')) {
      return const _AlertMeta(
        Icons.chat_bubble_outline_rounded,
        Color(0xFFF59E0B),
        'Message Alert',
        'You have a new patient message.',
      );
    }
    if (value.contains('request') || value.contains('booking')) {
      return const _AlertMeta(
        Icons.assignment_rounded,
        Color(0xFF0F766E),
        'New Service Request',
        'You have a new service request.',
      );
    }
    return const _AlertMeta(
      Icons.notifications_none_rounded,
      Color(0xFF6B7280),
      'Alert',
      'You have a new system alert.',
    );
  }
}

class _AlertMeta {
  const _AlertMeta(this.icon, this.color, this.title, this.description);

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  return '${diff.inDays}d';
}

String _dateTime(DateTime date) {
  final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final m = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '${date.month}/${date.day}/${date.year} - $h:$m $suffix';
}

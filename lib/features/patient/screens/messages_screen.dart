import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/features/patient/screens/chat_screen.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';
import 'package:carelink/shared/widgets/patient_app_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.userId});

  final String userId;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<_ConversationItem> _conversations = const [];
  List<_ConversationItem> _filteredConversations = const [];
  bool _loading = true;
  String? _error;

  bool get _isArabic => localeController.isArabic;
  String _t(String english, String arabic) => _isArabic ? arabic : english;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_applySearch)
      ..dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (!kDebugMode) return;

    // Flutter Web preserves State objects during hot reload. This screen used
    // to store raw Maps, so a reload after the typed conversation migration
    // can otherwise leave old objects whose new fields are JS `undefined`.
    _conversations = const [];
    _filteredConversations = const [];
    _loading = true;
    _error = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadConversations();
    });
  }

  Future<void> _loadConversations() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await _api.getMessages(widget.userId);
      final rows = response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final grouped = _groupByProvider(rows);
      if (!mounted) return;
      setState(() {
        _conversations = grouped;
        _filteredConversations = grouped;
        _loading = false;
      });
      _applySearch();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.userMessage(error);
      });
    }
  }

  List<_ConversationItem> _groupByProvider(List<Map<String, dynamic>> rows) {
    final groups = <String, _ConversationAccumulator>{};
    for (final row in rows) {
      final patientId = _firstText(row, [
        'patientUserId',
        'patientId',
      ], fallback: widget.userId);
      final providerId = _firstText(row, [
        'providerUserId',
        'providerId',
        'doctorId',
        'nurseId',
      ]);
      if (providerId.isEmpty) continue;

      final key =
          '${patientId.trim().toLowerCase()}::${providerId.trim().toLowerCase()}';
      groups
          .putIfAbsent(
            key,
            () => _ConversationAccumulator(
              patientId: patientId,
              providerId: providerId,
            ),
          )
          .add(row);
    }

    final conversations = groups.values.map((group) => group.build()).toList()
      ..sort((a, b) {
        final first = a.latestMessageAt;
        final second = b.latestMessageAt;
        if (first == null && second == null) {
          return a.providerName.compareTo(b.providerName);
        }
        if (first == null) return 1;
        if (second == null) return -1;
        return second.compareTo(first);
      });
    return conversations;
  }

  void _applySearch() {
    if (!mounted) return;
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredConversations = query.isEmpty
          ? List<_ConversationItem>.from(_conversations)
          : _conversations.where((conversation) {
              return conversation.providerName.toLowerCase().contains(query) ||
                  conversation.providerRole.toLowerCase().contains(query) ||
                  conversation.specialty.toLowerCase().contains(query) ||
                  _previewText(conversation).toLowerCase().contains(query);
            }).toList();
    });
  }

  void _openConversation(_ConversationItem conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          name: conversation.providerName,
          userId: widget.userId,
          doctorId: conversation.providerId,
          requestId: conversation.primaryRequestId,
          requestIds: conversation.requestIds,
          patientUserId: conversation.patientId,
          providerUserId: conversation.providerId,
          peerImageUrl: conversation.avatarUrl,
        ),
      ),
    );
  }

  String _previewText(_ConversationItem conversation) {
    if (conversation.latestIsAttachment) return _t('Attachment', 'مرفق');
    final message = conversation.latestMessage.trim();
    if (message.isEmpty) {
      return _t('No messages yet', 'لا توجد رسائل بعد');
    }
    return message;
  }

  String _formatConversationTime(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final now = DateTime.now();
    final today =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (today) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      if (_isArabic) {
        final period = local.hour < 12 ? 'ص' : 'م';
        return 'اليوم $hour:$minute $period';
      }
      final period = local.hour < 12 ? 'AM' : 'PM';
      return 'Today $hour:$minute $period';
    }

    const englishMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const arabicMonths = [
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
    if (_isArabic) {
      return '${local.day} ${arabicMonths[local.month - 1]}';
    }
    return '${englishMonths[local.month - 1]} ${local.day}';
  }

  String _providerMeta(_ConversationItem conversation) {
    final role = switch (conversation.providerRole.toLowerCase()) {
      'doctor' => _t('Doctor', 'طبيب'),
      'nurse' => _t('Nurse', 'ممرض/ة'),
      _ => conversation.providerRole,
    };
    return [
      role,
      conversation.specialty,
    ].where((value) => value.trim().isNotEmpty).join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final palette = CarelinkPalette.of(context);
    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: PatientScaffold(
        backgroundColor: palette.pageBg,
        appBar: PatientAppBar(
          titleWidget: Text(
            _t('Messages', 'الرسائل'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F766E),
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: _searchBar(palette),
              ),
              Expanded(child: _body(palette)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar(CarelinkPalette palette) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: _searchController,
        cursorColor: AppColors.primary,
        style: TextStyle(
          color: palette.inkDark,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: _t('Search conversations...', 'ابحث في المحادثات...'),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF64748B),
            size: 21,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: const Color(0xFF64748B),
                ),
          filled: true,
          fillColor: palette.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: palette.stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: palette.stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _body(CarelinkPalette palette) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 34,
              ),
              const SizedBox(height: 9),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadConversations,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_t('Try again', 'إعادة المحاولة')),
              ),
            ],
          ),
        ),
      );
    }
    if (_filteredConversations.isEmpty) return _emptyState(palette);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadConversations,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
        itemCount: _filteredConversations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _conversationCard(palette, _filteredConversations[index]),
      ),
    );
  }

  Widget _conversationCard(
    CarelinkPalette palette,
    _ConversationItem conversation,
  ) {
    final preview = _previewText(conversation);
    final meta = _providerMeta(conversation);
    final time = _formatConversationTime(conversation.latestMessageAt);
    final statusColor = _statusColor(conversation.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openConversation(conversation),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.stroke.withValues(alpha: 0.78)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: palette.isDark ? 0.18 : 0.045,
                ),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundImage: conversation.avatarUrl.isEmpty
                    ? null
                    : NetworkImage(conversation.avatarUrl),
                child: conversation.avatarUrl.isEmpty
                    ? const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.primary,
                        size: 24,
                      )
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.providerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.inkDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (conversation.status.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 86),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              _statusLabel(conversation.status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: conversation.unreadCount > 0
                            ? palette.inkDark
                            : const Color(0xFF64748B),
                        fontSize: 12.5,
                        fontWeight: conversation.unreadCount > 0
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      maxLines: 2,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: conversation.unreadCount > 0
                            ? AppColors.primary
                            : const Color(0xFF64748B),
                        fontSize: 10.5,
                        height: 1.25,
                        fontWeight: conversation.unreadCount > 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (conversation.unreadCount > 0) ...[
                      const SizedBox(height: 7),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          conversation.unreadCount > 99
                              ? '99+'
                              : '${conversation.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(CarelinkPalette palette) {
    final searching = _searchController.text.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching
                  ? Icons.search_off_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 44,
              color: palette.inkMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              searching
                  ? _t('No matching conversations', 'لا توجد محادثات مطابقة')
                  : _t('No conversations yet', 'لا توجد محادثات بعد'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.inkDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!searching) ...[
              const SizedBox(height: 5),
              Text(
                _t(
                  'Conversations with your care providers will appear here.',
                  'ستظهر محادثاتك مع مقدمي الرعاية هنا.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'pending' || 'pending_provider_approval' => const Color(0xFFD97706),
      'confirmed' || 'accepted' || 'paid' => const Color(0xFF2563EB),
      'in_progress' => const Color(0xFF0F766E),
      'completed' => const Color(0xFF15803D),
      'cancelled' || 'rejected' => const Color(0xFFDC2626),
      _ => const Color(0xFF64748B),
    };
  }

  String _statusLabel(String status) {
    return switch (status.toLowerCase()) {
      'pending' || 'pending_provider_approval' => _t('Pending', 'قيد الانتظار'),
      'confirmed' || 'accepted' => _t('Confirmed', 'مؤكد'),
      'paid' => _t('Paid', 'مدفوع'),
      'in_progress' => _t('In progress', 'قيد التنفيذ'),
      'completed' => _t('Completed', 'مكتمل'),
      'cancelled' || 'rejected' => _t('Cancelled', 'ملغي'),
      _ => _t('Unknown', 'غير معروف'),
    };
  }
}

class _ConversationAccumulator {
  _ConversationAccumulator({required this.patientId, required this.providerId});

  final String patientId;
  final String providerId;
  final List<Map<String, dynamic>> _rows = [];
  final Set<String> _requestIds = <String>{};
  final Map<String, int> _unreadByConversation = <String, int>{};
  Map<String, dynamic>? _latestRow;

  void add(Map<String, dynamic> row) {
    _rows.add(row);
    final requestId = _firstText(row, ['requestId', 'appointmentId']);
    if (requestId.isNotEmpty) _requestIds.add(requestId);

    final conversationId = _firstText(row, ['conversationId']);
    final unreadKey = conversationId.isEmpty ? 'legacy' : conversationId;
    final unread =
        int.tryParse((row['unreadCount'] ?? row['unread'] ?? 0).toString()) ??
        0;
    final existing = _unreadByConversation[unreadKey] ?? 0;
    if (unread > existing) _unreadByConversation[unreadKey] = unread;

    if (_latestRow == null) {
      _latestRow = row;
      return;
    }
    final candidate = _parseDate(row);
    final current = _parseDate(_latestRow!);
    if (candidate != null && (current == null || candidate.isAfter(current))) {
      _latestRow = row;
    }
  }

  _ConversationItem build() {
    final latest = _latestRow ?? _rows.first;
    final latestMessage = _firstText(latest, ['lastMessage', 'message']);
    final requestIds = _requestIds.toList(growable: false);
    final latestRequestId = _firstText(latest, ['requestId', 'appointmentId']);

    return _ConversationItem(
      patientId: patientId,
      providerId: providerId,
      providerName: _metadata([
        'providerName',
        'name',
        'doctorName',
      ], fallback: localeController.isArabic ? 'مقدم رعاية' : 'Care Provider'),
      providerRole: _metadata(['providerRole', 'role']),
      specialty: _metadata([
        'specialization',
        'providerSpecialization',
        'specialty',
      ]),
      avatarUrl: _metadata([
        'profileImageUrl',
        'providerImage',
        'doctorPhoto',
        'photo',
        'profilePicture',
      ]),
      status: _firstText(latest, [
        'requestStatus',
        'appointmentStatus',
        'status',
      ]),
      latestMessage: latestMessage,
      latestMessageAt: _parseDate(latest),
      latestIsAttachment: _isAttachmentPreview(
        latestMessage,
        hasTimestamp: _parseDate(latest) != null,
      ),
      unreadCount: _unreadByConversation.values.fold<int>(
        0,
        (total, value) => total + value,
      ),
      primaryRequestId: latestRequestId.isNotEmpty
          ? latestRequestId
          : (requestIds.isEmpty ? null : requestIds.first),
      requestIds: requestIds,
    );
  }

  String _metadata(List<String> keys, {String fallback = ''}) {
    for (final row in [_latestRow, ..._rows]) {
      if (row == null) continue;
      final value = _firstText(row, keys);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }
}

class _ConversationItem {
  const _ConversationItem({
    required this.patientId,
    required this.providerId,
    required this.providerName,
    required this.providerRole,
    required this.specialty,
    required this.avatarUrl,
    required this.status,
    required this.latestMessage,
    required this.latestMessageAt,
    required this.latestIsAttachment,
    required this.unreadCount,
    required this.primaryRequestId,
    required this.requestIds,
  });

  final String patientId;
  final String providerId;
  final String providerName;
  final String providerRole;
  final String specialty;
  final String avatarUrl;
  final String status;
  final String latestMessage;
  final DateTime? latestMessageAt;
  final bool latestIsAttachment;
  final int unreadCount;
  final String? primaryRequestId;
  final List<String> requestIds;
}

String _firstText(
  Map<String, dynamic> row,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return fallback;
}

DateTime? _parseDate(Map<String, dynamic> row) {
  for (final key in ['lastMessageAt', 'latestMessageAt', 'sentAt', 'time']) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isEmpty) continue;
    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (parsed != null) return parsed.toLocal();
  }
  return null;
}

bool _isAttachmentPreview(String value, {required bool hasTimestamp}) {
  final text = value.trim().toLowerCase();
  if (text.isEmpty) return hasTimestamp;
  return text.startsWith('http://') ||
      text.startsWith('https://') ||
      text.startsWith('/uploads/') ||
      text.contains('localhost:') ||
      RegExp(
        r'\b(?:www\.)?[^\s]+\.(?:pdf|png|jpe?g|webp|docx?)\b',
      ).hasMatch(text);
}

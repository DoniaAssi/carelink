import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/chat_message_model.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/services/chat_repository.dart';

import 'nurse_ui.dart';

class ContactPatientScreen extends StatelessWidget {
  final ServiceRequest request;
  final String currentUserId;

  const ContactPatientScreen({
    super.key,
    required this.request,
    this.currentUserId = '',
  });

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: _contactAppBar(context, 'Contact Patient'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
          children: [
            NurseContactPatientCard(request: request),
            const SizedBox(height: 34),
            const Text(
              'Choose an option to contact the patient',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 22),
            _optionCard(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Message Patient',
              subtitle: 'Send and receive messages\nwith the patient',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientMessageScreen(
                      request: request,
                      currentUserId: currentUserId,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            _optionCard(
              icon: Icons.location_on_outlined,
              title: 'View Location',
              subtitle: 'View patient location on map\nand get directions',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientLocationScreen(request: request),
                  ),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: const _ContactBottomNav(),
      ),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: _contactCardDecoration(),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 34),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF607D8B),
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF9AAAB0),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class PatientMessageScreen extends StatefulWidget {
  final ServiceRequest request;
  final String currentUserId;
  final List<ChatConversation> threadConversations;

  const PatientMessageScreen({
    super.key,
    required this.request,
    required this.currentUserId,
    this.threadConversations = const <ChatConversation>[],
  });

  @override
  State<PatientMessageScreen> createState() => _PatientMessageScreenState();
}

class _PatientMessageScreenState extends State<PatientMessageScreen> {
  final repository = ChatRepository();
  final controller = TextEditingController();
  final scrollController = ScrollController();
  ChatConversation? conversation;
  List<ChatMessage> messages = [];
  final Set<String> failedMessageIds = {};
  Timer? pollTimer;
  bool isLoading = true;
  bool isSending = false;
  bool isLoadingOlder = false;
  String? error;

  String get nurseId {
    final clean = widget.currentUserId.trim();
    if (clean.isNotEmpty) return clean;
    return widget.request.providerId.trim();
  }

  String get patientId => widget.request.patientId.trim();

  List<ChatConversation> get _activeConversations {
    final items = widget.threadConversations
        .where((item) => item.conversationId.trim().isNotEmpty)
        .toList();
    if (items.isEmpty) {
      final c = conversation;
      return c == null ? const <ChatConversation>[] : <ChatConversation>[c];
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_handleScroll);
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    _initializeConversation();
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    controller.dispose();
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeConversation() async {
    if (nurseId.isEmpty || patientId.isEmpty || widget.request.id.isEmpty) {
      setState(() {
        isLoading = false;
        error = 'Unable to open conversation. Missing request participants.';
      });
      return;
    }
    try {
      if (widget.threadConversations.isNotEmpty) {
        final sorted = [...widget.threadConversations]
          ..sort((a, b) {
            final aTime =
                a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
        setState(() => conversation = sorted.first);
        await _refreshMessages(scrollToBottom: true);
        await _markRead();
        pollTimer = Timer.periodic(
          const Duration(seconds: 3),
          (_) => _refreshMessages(),
        );
        return;
      }
      final loadedConversation = await repository.getOrCreateConversation(
        nurseId: nurseId,
        patientId: patientId,
        requestId: widget.request.id,
        appointmentId: widget.request.id,
        visitId: widget.request.id,
      );
      if (!mounted) return;
      setState(() => conversation = loadedConversation);
      await _refreshMessages(scrollToBottom: true);
      await _markRead();
      pollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _refreshMessages(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refreshMessages({bool scrollToBottom = false}) async {
    final active = _activeConversations;
    if (active.isEmpty) return;
    try {
      final loadedGroups = await Future.wait(
        active.map(
          (c) => repository.loadMessages(
            conversationId: c.conversationId,
            viewerId: nurseId,
          ),
        ),
      );
      final loaded = loadedGroups.expand((group) => group).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (!mounted) return;
      final existingOlder = messages.where((m) {
        if (loaded.any((next) => next.messageId == m.messageId)) return false;
        return !m.isPending && !failedMessageIds.contains(m.messageId);
      }).toList();
      final pending = messages.where((m) {
        return m.isPending || failedMessageIds.contains(m.messageId);
      }).toList();
      final merged = [...existingOlder, ...loaded, ...pending]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final wasNearBottom = _isNearBottom;
      setState(() {
        messages = _uniqueMessages(merged);
        isLoading = false;
        error = null;
      });
      if (scrollToBottom || wasNearBottom) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      if (isLoading) {
        setState(() {
          isLoading = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    final c = conversation;
    if (c == null || messages.isEmpty || isLoadingOlder) return;
    setState(() => isLoadingOlder = true);
    final before = messages.first.createdAt;
    final oldPixels = scrollController.hasClients
        ? scrollController.position.pixels
        : 0.0;
    try {
      final older = await repository.loadMessages(
        conversationId: c.conversationId,
        viewerId: nurseId,
        before: before,
      );
      if (!mounted) return;
      setState(() {
        messages = _uniqueMessages([...older, ...messages])
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.jumpTo(oldPixels + 80);
        }
      });
    } finally {
      if (mounted) setState(() => isLoadingOlder = false);
    }
  }

  List<ChatMessage> _uniqueMessages(List<ChatMessage> input) {
    final byId = <String, ChatMessage>{};
    for (final message in input) {
      byId[message.messageId] = message;
    }
    return byId.values.toList();
  }

  void _handleScroll() {
    if (!scrollController.hasClients || isLoadingOlder) return;
    if (scrollController.position.pixels <= 70 && messages.length >= 25) {
      _loadOlderMessages();
    }
  }

  Future<void> _markRead() async {
    final active = _activeConversations;
    if (active.isEmpty) return;
    try {
      await Future.wait(
        active.map(
          (c) => repository.markConversationRead(
            conversationId: c.conversationId,
            readerId: nurseId,
          ),
        ),
      );
    } catch (_) {}
  }

  bool get _isNearBottom {
    if (!scrollController.hasClients) return true;
    final position = scrollController.position;
    return position.maxScrollExtent - position.pixels < 160;
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: NurseUi.background,
        appBar: _contactAppBar(
          context,
          'Message',
          trailing: Icons.more_vert_rounded,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: NurseContactPatientCard(request: widget.request),
            ),
            Expanded(child: _messagesBody()),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _messagesBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    error = null;
                  });
                  _initializeConversation();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.primaryDark,
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'No messages yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text(
              'Start the conversation with the patient.',
              style: TextStyle(
                color: Color(0xFF607D8B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      itemCount: messages.length + (isLoadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (isLoadingOlder && index == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final messageIndex = index - (isLoadingOlder ? 1 : 0);
        final message = messages[messageIndex];
        final showDate =
            messageIndex == 0 ||
            !_sameDay(messages[messageIndex - 1].createdAt, message.createdAt);
        return Column(
          children: [
            if (showDate) _dateSeparator(message.createdAt),
            _bubble(message),
          ],
        );
      },
    );
  }

  Widget _dateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4F3),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _dateLabel(date),
            style: const TextStyle(
              color: Color(0xFF607D8B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage message) {
    final mine = message.senderId == nurseId;
    final failed = failedMessageIds.contains(message.messageId);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 270),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: mine
              ? AppColors.primary.withValues(alpha: 0.14)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: Color(0xFF151823),
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(message.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 11,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 5),
                  _messageStatusIcon(message, failed),
                ],
              ],
            ),
            if (failed)
              GestureDetector(
                onTap: () => _retry(message),
                child: const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Tap to retry',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _messageStatusIcon(ChatMessage message, bool failed) {
    if (failed) {
      return const Icon(
        Icons.error_outline_rounded,
        color: Colors.redAccent,
        size: 15,
      );
    }
    if (message.isPending) {
      return const SizedBox(
        width: 13,
        height: 13,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (message.readAt != null || message.isRead) {
      return const Icon(
        Icons.done_all_rounded,
        color: AppColors.primaryDark,
        size: 15,
      );
    }
    if (message.deliveredAt != null) {
      return const Icon(
        Icons.done_all_rounded,
        color: Color(0xFF78909C),
        size: 15,
      );
    }
    return const Icon(Icons.check_rounded, color: Color(0xFF78909C), size: 15);
  }

  Widget _composer() {
    final canSend = controller.text.trim().isNotEmpty && !isSending;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (canSend) _send();
                },
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  prefixIcon: const Icon(
                    Icons.emoji_emotions_outlined,
                    color: Color(0xFF78909C),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: NurseUi.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: NurseUi.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: canSend ? _send : null,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: canSend ? AppColors.primary : const Color(0xFFB9D8D3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    final c = conversation;
    if (text.isEmpty || isSending || c == null) return;
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage(
      messageId: localId,
      senderId: nurseId,
      receiverId: patientId,
      type: ChatMessageType.text,
      text: text,
      createdAt: DateTime.now(),
      isPending: true,
    );
    setState(() {
      isSending = true;
      messages = [...messages, optimistic];
      controller.clear();
    });
    _scrollToBottom();
    try {
      final sent = await repository.sendTextMessage(
        conversationId: c.conversationId,
        senderId: nurseId,
        senderRole: 'nurse',
        receiverId: patientId,
        receiverRole: 'patient',
        text: text,
        clientMessageId: localId,
      );
      if (!mounted) return;
      setState(() {
        messages = messages
            .map((message) => message.messageId == localId ? sent : message)
            .toList();
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => failedMessageIds.add(localId));
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _retry(ChatMessage message) {
    controller.text = message.text;
    setState(() {
      messages = messages
          .where((item) => item.messageId != message.messageId)
          .toList();
      failedMessageIds.remove(message.messageId);
    });
    _send();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}

class PatientLocationScreen extends StatelessWidget {
  final ServiceRequest request;

  const PatientLocationScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: _contactAppBar(context, 'View Location'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
          children: [
            NurseContactPatientCard(request: request),
            const SizedBox(height: 18),
            _locationInfoCard(context),
            const SizedBox(height: 18),
            _mapPreview(),
            const SizedBox(height: 18),
            _distanceCard(context),
          ],
        ),
        bottomNavigationBar: const _ContactBottomNav(),
      ),
    );
  }

  Widget _locationInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _contactCardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primaryDark, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Patient Location',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  _address,
                  style: const TextStyle(
                    color: Color(0xFF607D8B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _openMaps(context),
            icon: const Icon(Icons.navigation_outlined, size: 17),
            label: const Text('Open in Maps'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapPreview() {
    return Container(
      height: 330,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NurseUi.border),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _RouteMapPainter())),
          const Positioned(
            right: 40,
            top: 42,
            child: Icon(Icons.location_on, color: Colors.redAccent, size: 58),
          ),
          Positioned(
            left: 42,
            bottom: 36,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 5),
              ),
            ),
          ),
          const Positioned(
            right: 42,
            top: 98,
            child: Text(
              'Patient',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 18,
            child: Column(
              children: [
                _mapButton(Icons.my_location),
                const SizedBox(height: 10),
                _mapButton(Icons.add),
                const SizedBox(height: 10),
                _mapButton(Icons.remove),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapButton(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: const Color(0xFF151823)),
    );
  }

  Widget _distanceCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _contactCardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stats = Row(
            children: const [
              Expanded(
                child: _MapStat(icon: Icons.social_distance, value: '6.4 km'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MapStat(icon: Icons.access_time, value: '14 min'),
              ),
            ],
          );
          final button = ElevatedButton.icon(
            onPressed: () => _openMaps(context),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Open in Maps'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          if (constraints.maxWidth < 370) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [stats, const SizedBox(height: 14), button],
            );
          }
          return Row(
            children: [
              Expanded(child: stats),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }

  Future<void> _openMaps(BuildContext context) async {
    final hasGps = request.gpsLat != null && request.gpsLng != null;
    final query = hasGps
        ? '${request.gpsLat},${request.gpsLng}'
        : Uri.encodeComponent(_address);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
    }
  }

  String get _address {
    if (request.location.trim().isNotEmpty) return request.location.trim();
    if (request.patientAddress.trim().isNotEmpty) {
      return request.patientAddress.trim();
    }
    return 'Location not available';
  }
}

class NurseContactPatientCard extends StatelessWidget {
  final ServiceRequest request;

  const NurseContactPatientCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final name = _patientName(request);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _contactCardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              name.characters.first.toLowerCase(),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  request.patientAge > 0
                      ? '${request.patientAge} years'
                      : 'Age not set',
                  style: const TextStyle(
                    color: Color(0xFF607D8B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  request.serviceType.isEmpty
                      ? 'Home Nursing Care'
                      : request.serviceType,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primaryDark,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        request.location.isEmpty
                            ? request.patientAddress
                            : request.location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF151823),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _acceptedBadge(),
        ],
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.2;
    for (var x = 20.0; x < size.width; x += 52) {
      canvas.drawLine(Offset(x, 0), Offset(x + 60, size.height), roadPaint);
    }
    for (var y = 18.0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 24), roadPaint);
    }
    final route = Path()
      ..moveTo(size.width * 0.2, size.height * 0.82)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.68,
        size.width * 0.48,
        size.height * 0.65,
        size.width * 0.55,
        size.height * 0.5,
      )
      ..cubicTo(
        size.width * 0.63,
        size.height * 0.36,
        size.width * 0.75,
        size.height * 0.32,
        size.width * 0.82,
        size.height * 0.2,
      );
    final routePaint = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapStat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _MapStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF607D8B)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

PreferredSizeWidget _contactAppBar(
  BuildContext context,
  String title, {
  IconData? trailing,
}) {
  return AppBar(
    title: Text(title),
    centerTitle: true,
    backgroundColor: NurseUi.background,
    foregroundColor: NurseUi.text,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      color: AppColors.primaryDark,
      onPressed: () => Navigator.pop(context),
    ),
    actions: [
      if (trailing != null)
        IconButton(
          icon: Icon(trailing),
          color: AppColors.primaryDark,
          onPressed: () {},
        ),
    ],
  );
}

BoxDecoration _contactCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.045),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

Widget _acceptedBadge() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFC9F2D7),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      'Accepted',
      style: TextStyle(
        color: Color(0xFF159957),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

String _patientName(ServiceRequest request) {
  return request.patientName.trim().isEmpty ? 'Patient' : request.patientName;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _dateLabel(DateTime date) {
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  if (_sameDay(date, now)) return 'Today';
  if (_sameDay(date, yesterday)) return 'Yesterday';
  const months = [
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _timeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

class _ContactBottomNav extends StatelessWidget {
  const _ContactBottomNav();

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.home_rounded, 'Home'),
      (Icons.calendar_month_rounded, 'Schedule'),
      (Icons.people_rounded, 'Patients'),
      (Icons.folder_copy_rounded, 'Reports'),
      (Icons.person_rounded, 'Profile'),
    ];
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < items.length; i++)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  items[i].$1,
                  color: i == 1
                      ? AppColors.primaryDark
                      : const Color(0xFF9AAAB0),
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  items[i].$2,
                  style: TextStyle(
                    color: i == 1
                        ? AppColors.primaryDark
                        : const Color(0xFF9AAAB0),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

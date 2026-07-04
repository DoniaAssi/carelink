import 'dart:async';

import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/chat_repository.dart';

import 'nurse_conversation_threads.dart';
import 'nurse_contact_patient_flow.dart';
import 'nurse_ui.dart';

class NurseMessagesScreen extends StatefulWidget {
  const NurseMessagesScreen({super.key, required this.user});

  final User user;

  @override
  State<NurseMessagesScreen> createState() => _NurseMessagesScreenState();
}

class _NurseMessagesScreenState extends State<NurseMessagesScreen> {
  final repository = ChatRepository();
  List<ChatConversation> conversations = [];
  Timer? timer;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
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
      final loaded = await repository.getConversations(widget.user.userId);
      if (!mounted) return;
      setState(() {
        conversations = loaded;
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
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: const Text('Messages'),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
        ),
        body: RefreshIndicator(onRefresh: () => _load(), child: _body()),
      ),
    );
  }

  Widget _body() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 160),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              onPressed: () => _load(),
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }
    final threads = groupNurseConversationsByPatient(conversations);
    if (threads.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 160),
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.primaryDark,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'No conversations yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            'Your patient conversations will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF607D8B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: threads.length,
      itemBuilder: (context, index) => _conversationTile(threads[index]),
    );
  }

  Widget _conversationTile(NurseConversationThread thread) {
    final conversation = thread.latest;
    final patientName = thread.patientName.trim().isEmpty
        ? 'Patient'
        : thread.patientName.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientMessageScreen(
              request: ServiceRequest(
                id: conversation.requestId,
                patientId: conversation.patientId,
                providerId: conversation.nurseId,
                patientName: patientName,
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                patientName.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          _relativeTime(conversation.lastMessageAt!),
                          style: const TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    thread.lastMessage.isEmpty
                        ? 'No messages yet'
                        : thread.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF607D8B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (thread.unreadCount > 0) ...[
              const SizedBox(width: 10),
              UnreadBadge(count: thread.unreadCount),
            ],
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.primaryDark,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFFF3347),
        shape: BoxShape.circle,
      ),
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
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  return '${diff.inDays}d';
}

import 'package:carelink/shared/services/chat_repository.dart';

class NurseConversationThread {
  const NurseConversationThread({
    required this.patientId,
    required this.patientName,
    required this.conversations,
    required this.latest,
    required this.unreadCount,
  });

  final String patientId;
  final String patientName;
  final List<ChatConversation> conversations;
  final ChatConversation latest;
  final int unreadCount;

  String get lastMessage => latest.lastMessage;
  DateTime? get lastMessageAt => latest.lastMessageAt;
}

List<NurseConversationThread> groupNurseConversationsByPatient(
  List<ChatConversation> conversations,
) {
  final grouped = <String, List<ChatConversation>>{};
  for (final conversation in conversations) {
    final key = conversation.patientId.trim().isNotEmpty
        ? conversation.patientId.trim()
        : conversation.patientName.trim().toLowerCase();
    if (key.isEmpty) continue;
    grouped.putIfAbsent(key, () => <ChatConversation>[]).add(conversation);
  }

  final threads =
      grouped.entries.map((entry) {
        final items = [...entry.value]
          ..sort((a, b) {
            final aTime =
                a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
        final latest = items.first;
        final unread = items.fold<int>(
          0,
          (total, next) => total + next.unreadCount,
        );
        final patientName = items
            .map((item) => item.patientName.trim())
            .firstWhere((name) => name.isNotEmpty, orElse: () => 'Patient');
        return NurseConversationThread(
          patientId: latest.patientId,
          patientName: patientName,
          conversations: items,
          latest: latest,
          unreadCount: unread,
        );
      }).toList()..sort((a, b) {
        final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

  return threads;
}

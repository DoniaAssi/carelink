enum ChatMessageType { text, image, pdf, medicalRecord, voice, system }

class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.createdAt,
    this.text = '',
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentMimeType,
    this.medicalRecordId,
    this.voiceDurationSeconds,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.isRead = false,
    this.isPending = false,
  });

  final String messageId;
  final String senderId;
  final String receiverId;
  final ChatMessageType type;
  final String text;
  final String? attachmentUrl;
  final String? attachmentName;
  final int? attachmentSize;
  final String? attachmentMimeType;
  final String? medicalRecordId;
  final int? voiceDurationSeconds;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool isRead;
  final bool isPending;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    return ChatMessage(
      messageId: (json['messageId'] ?? json['_localId'] ?? '').toString(),
      senderId: json['senderId']?.toString() ?? '',
      receiverId: json['receiverId']?.toString() ?? '',
      type: _typeFrom(json['messageType']?.toString()),
      text: json['message']?.toString() ?? '',
      attachmentUrl: json['attachmentUrl']?.toString(),
      attachmentName: json['attachmentName']?.toString(),
      attachmentSize: int.tryParse(json['attachmentSize']?.toString() ?? ''),
      attachmentMimeType: json['attachmentMimeType']?.toString(),
      medicalRecordId: json['medicalRecordId']?.toString(),
      voiceDurationSeconds: int.tryParse(
        json['voiceDurationSeconds']?.toString() ?? '',
      ),
      createdAt: createdAt,
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '')?.toLocal(),
      deliveredAt: DateTime.tryParse(
        json['deliveredAt']?.toString() ?? '',
      )?.toLocal(),
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? '')?.toLocal(),
      isRead:
          json['isRead'] == true ||
          json['isRead'] == 1 ||
          json['isRead']?.toString() == '1',
      isPending: json['_pending'] == true,
    );
  }

  ChatMessage copyWith({
    String? messageId,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    bool? isRead,
    bool? isPending,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      senderId: senderId,
      receiverId: receiverId,
      type: type,
      text: text,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentSize: attachmentSize,
      attachmentMimeType: attachmentMimeType,
      medicalRecordId: medicalRecordId,
      voiceDurationSeconds: voiceDurationSeconds,
      createdAt: createdAt,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      isPending: isPending ?? this.isPending,
    );
  }

  static ChatMessageType _typeFrom(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'image':
        return ChatMessageType.image;
      case 'pdf':
        return ChatMessageType.pdf;
      case 'medical_record':
        return ChatMessageType.medicalRecord;
      case 'voice':
        return ChatMessageType.voice;
      case 'system':
        return ChatMessageType.system;
      default:
        return ChatMessageType.text;
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:carelink/shared/models/chat_message_model.dart';
import 'package:carelink/shared/services/api_service.dart';

class ChatConversation {
  const ChatConversation({
    required this.conversationId,
    required this.patientId,
    required this.nurseId,
    required this.requestId,
    this.appointmentId = '',
    this.visitId = '',
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCount = 0,
    this.patientName = '',
    this.nurseName = '',
  });

  final String conversationId;
  final String patientId;
  final String nurseId;
  final String requestId;
  final String appointmentId;
  final String visitId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String patientName;
  final String nurseName;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] is Map
        ? Map<String, dynamic>.from(json['patient'] as Map)
        : const <String, dynamic>{};
    final nurse = json['nurse'] is Map
        ? Map<String, dynamic>.from(json['nurse'] as Map)
        : const <String, dynamic>{};
    return ChatConversation(
      conversationId: (json['conversationId'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      nurseId: (json['nurseId'] ?? '').toString(),
      requestId: (json['requestId'] ?? '').toString(),
      appointmentId: (json['appointmentId'] ?? '').toString(),
      visitId: (json['visitId'] ?? '').toString(),
      lastMessage: (json['lastMessage'] ?? '').toString(),
      lastMessageAt: DateTime.tryParse(
        json['lastMessageAt']?.toString() ?? '',
      )?.toLocal(),
      unreadCount: int.tryParse(json['unreadCount']?.toString() ?? '') ?? 0,
      patientName: (json['patientName'] ?? patient['fullName'] ?? '')
          .toString(),
      nurseName: (json['nurseName'] ?? nurse['fullName'] ?? '').toString(),
    );
  }
}

class ChatRepository {
  ChatRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('${ApiService.baseUrl}$normalized');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: query);
  }

  Map<String, String> get _headers => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<ChatConversation> getOrCreateConversation({
    required String nurseId,
    required String patientId,
    required String requestId,
    String? appointmentId,
    String? visitId,
  }) async {
    final response = await _client
        .post(
          _uri('/patient/chat/conversations/get-or-create'),
          headers: _headers,
          body: jsonEncode({
            'nurseId': nurseId,
            'patientId': patientId,
            'requestId': requestId,
            'appointmentId': appointmentId ?? requestId,
            'visitId': visitId ?? requestId,
          }),
        )
        .timeout(const Duration(seconds: 12));
    return ChatConversation.fromJson(_decodeMap(response));
  }

  Future<List<ChatConversation>> getConversations(String userId) async {
    final response = await _client
        .get(
          _uri('/patient/chat/conversations', {'userId': userId}),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 12));
    final decoded = _decodeList(response);
    return decoded
        .map(
          (item) => ChatConversation.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<int> getUnreadCount(String userId) async {
    final response = await _client
        .get(_uri('/patient/chat/unread-count/$userId'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    final map = _decodeMap(response);
    return int.tryParse(map['unreadCount']?.toString() ?? '') ?? 0;
  }

  Future<List<ChatMessage>> loadMessages({
    required String conversationId,
    required String viewerId,
    int limit = 30,
    DateTime? before,
  }) async {
    final query = {
      'viewerId': viewerId,
      'limit': limit.toString(),
      if (before != null) 'before': _sqlDateTime(before),
    };
    final response = await _client
        .get(
          _uri('/patient/chat/conversations/$conversationId/messages', query),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 12));
    return _decodeList(response)
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Stream<List<ChatMessage>> watchMessages({
    required String conversationId,
    required String viewerId,
    Duration interval = const Duration(seconds: 3),
  }) async* {
    yield await loadMessages(
      conversationId: conversationId,
      viewerId: viewerId,
    );
    yield* Stream.periodic(interval).asyncMap(
      (_) => loadMessages(conversationId: conversationId, viewerId: viewerId),
    );
  }

  Future<ChatMessage> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String senderRole,
    required String receiverId,
    required String receiverRole,
    required String text,
    required String clientMessageId,
  }) async {
    final response = await _client
        .post(
          _uri('/patient/chat/conversations/$conversationId/messages'),
          headers: _headers,
          body: jsonEncode({
            'senderId': senderId,
            'senderRole': senderRole,
            'receiverId': receiverId,
            'receiverRole': receiverRole,
            'messageType': 'text',
            'text': text,
            'clientMessageId': clientMessageId,
          }),
        )
        .timeout(const Duration(seconds: 12));
    return ChatMessage.fromJson(_decodeMap(response));
  }

  Future<void> markConversationRead({
    required String conversationId,
    required String readerId,
  }) async {
    final response = await _client
        .post(
          _uri('/patient/chat/conversations/$conversationId/read'),
          headers: _headers,
          body: jsonEncode({'readerId': readerId}),
        )
        .timeout(const Duration(seconds: 12));
    _decodeMap(response);
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }
    throw Exception(_error(response));
  }

  List<dynamic> _decodeList(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception(_error(response));
  }

  String _error(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'Chat request failed (${response.statusCode})';
  }

  String _sqlDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

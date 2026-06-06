import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PatientRecentChatsService {
  static const String _key = 'carelink_patient_recent_chats';

  static Future<List<Map<String, dynamic>>> getRecentChats() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    return data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<void> logChat(Map<String, dynamic> provider, {String lastMessage = 'Tap to continue conversation', int unreadCount = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final chats = await getRecentChats();
    
    // Remove if exists to bring it to top
    chats.removeWhere((e) => e['providerId'] == provider['providerId']);
    
    // Add to top
    chats.insert(0, {
      ...provider,
      'lastMessage': lastMessage,
      'timestamp': DateTime.now().toIso8601String(),
      'unreadCount': unreadCount,
    });
    
    // Keep only last 20 chats locally
    if (chats.length > 20) {
      chats.removeLast();
    }
    
    final data = chats.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(_key, data);
  }
}

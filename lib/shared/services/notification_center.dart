import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class NotificationCenter extends ChangeNotifier {
  NotificationCenter({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;
  final List<Map<String, dynamic>> _items = [];
  final Set<String> _localReadIds = {};

  String? _userId;
  bool _loading = false;
  Object? _error;

  List<Map<String, dynamic>> get items =>
      List<Map<String, dynamic>>.unmodifiable(_items);
  bool get isLoading => _loading;
  Object? get error => _error;
  int get unreadCount => _items.where((item) => !_isRead(item)).length;

  String _prefsKey(String userId) => 'notif_read_$userId';

  Future<void> load(String userId, {bool force = false}) async {
    final id = userId.trim();
    if (id.isEmpty) {
      _userId = null;
      _items.clear();
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }
    if (_loading || (!force && _userId == id && _items.isNotEmpty)) return;

    _userId = id;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _localReadIds
        ..clear()
        ..addAll(prefs.getStringList(_prefsKey(id)) ?? const []);

      final raw = await _api.getNotifications(id);
      final loaded = <Map<String, dynamic>>[];
      final pendingSync = <String>[];

      for (final value in raw) {
        if (value is! Map) continue;
        final item = Map<String, dynamic>.from(value);
        final notificationId = _notificationId(item);
        final serverRead = _serverSaysRead(item);
        if (serverRead || _localReadIds.contains(notificationId)) {
          item['isRead'] = true;
          if (!serverRead && notificationId.isNotEmpty) {
            pendingSync.add(notificationId);
          }
        }
        loaded.add(item);
      }

      _items
        ..clear()
        ..addAll(loaded);
      _error = null;

      for (final notificationId in pendingSync) {
        unawaited(_syncRead(notificationId));
      }
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    Map<String, dynamic>? item;
    for (final candidate in _items) {
      if (_notificationId(candidate) == notificationId) {
        item = candidate;
        break;
      }
    }
    if (item == null || _isRead(item)) return;

    item['isRead'] = true;
    _localReadIds.add(notificationId);
    notifyListeners();
    await _persistLocalReadIds();
    unawaited(_syncRead(notificationId));
  }

  Future<void> markAllRead() async {
    final id = _userId;
    if (id == null || id.isEmpty || unreadCount == 0) return;

    for (final item in _items) {
      item['isRead'] = true;
      final notificationId = _notificationId(item);
      if (notificationId.isNotEmpty) _localReadIds.add(notificationId);
    }
    notifyListeners();
    await _persistLocalReadIds();

    try {
      await _api.markAllNotificationsRead(id);
    } catch (_) {
      // Local IDs remain authoritative and are retried during the next load.
    }
  }

  bool isRead(Map<String, dynamic> item) => _isRead(item);

  Future<void> _syncRead(String notificationId) async {
    try {
      await _api.markNotificationRead(notificationId);
    } catch (_) {
      // The persisted local ID prevents this notification becoming unread again.
    }
  }

  Future<void> _persistLocalReadIds() async {
    final id = _userId;
    if (id == null || id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey(id), _localReadIds.toList());
  }

  bool _isRead(Map<String, dynamic> item) {
    final notificationId = _notificationId(item);
    return _serverSaysRead(item) || _localReadIds.contains(notificationId);
  }

  bool _serverSaysRead(Map<String, dynamic> item) {
    final value = item['isRead'] ?? item['read'];
    return value == true || value == 1 || value?.toString() == '1';
  }

  String _notificationId(Map<String, dynamic> item) {
    return (item['id'] ?? item['notificationId'] ?? '').toString();
  }
}

final notificationCenter = NotificationCenter();

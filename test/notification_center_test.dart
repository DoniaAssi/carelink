import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/notification_center.dart';

class _FakeApiService extends ApiService {
  _FakeApiService(this.notifications);

  final List<Map<String, dynamic>> notifications;
  final List<String> markedRead = [];
  int markAllCalls = 0;

  @override
  Future<List<dynamic>> getNotifications(String userId) async {
    return notifications.map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    markedRead.add(notificationId);
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    markAllCalls += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'read state updates immediately and survives a server refresh',
    () async {
      final rows = [
        {'id': 'n1', 'title': 'One', 'isRead': 0},
        {'id': 'n2', 'title': 'Two', 'isRead': 0},
      ];
      final firstApi = _FakeApiService(rows);
      final firstCenter = NotificationCenter(api: firstApi);

      await firstCenter.load('patient-1', force: true);
      expect(firstCenter.unreadCount, 2);

      await firstCenter.markRead('n1');
      await Future<void>.delayed(Duration.zero);
      expect(firstCenter.unreadCount, 1);
      expect(firstApi.markedRead, contains('n1'));

      final refreshedApi = _FakeApiService(rows);
      final refreshedCenter = NotificationCenter(api: refreshedApi);
      await refreshedCenter.load('patient-1', force: true);
      await Future<void>.delayed(Duration.zero);

      expect(refreshedCenter.unreadCount, 1);
      expect(refreshedCenter.isRead(refreshedCenter.items.first), isTrue);
      expect(refreshedApi.markedRead, contains('n1'));
    },
  );

  test('mark all read updates the counter and calls the backend', () async {
    final api = _FakeApiService([
      {'id': 'n1', 'isRead': false},
      {'id': 'n2', 'isRead': false},
    ]);
    final center = NotificationCenter(api: api);

    await center.load('patient-1', force: true);
    await center.markAllRead();

    expect(center.unreadCount, 0);
    expect(api.markAllCalls, 1);
  });
}

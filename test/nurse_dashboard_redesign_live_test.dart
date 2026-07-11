// LIVE render verification of the redesigned nurse home. Requires the local
// backend on http://127.0.0.1:3000. Run with:
//   flutter test test/nurse_dashboard_redesign_live_test.dart \
//     --dart-define=API_BASE_URL=http://127.0.0.1:3000
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/features/nurse/screens/nurse_dashboard.dart';
import 'package:carelink/shared/models/user.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    HttpOverrides.global = _RealHttpOverrides();
    final fontsDir = Directory.systemTemp.createTempSync('carelink_fonts');
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => fontsDir.path,
    );
  });

  testWidgets('LIVE: redesigned nurse home renders without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.reset();
      return tester.binding.setSurfaceSize(null);
    });

    final user = User(
      id: 1,
      serverUserId: '7fe47cc7-70de-43f2-9091-1c07544d28b6',
      email: 'nurse@test.dev',
      password: '',
      fullName: 'Nurse',
      phone: '',
      role: 'nurse',
      createdAt: DateTime(2026),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: NurseDashboard(user: user)));
      await Future<void>.delayed(const Duration(seconds: 4));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final visibleTexts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .toList();
    debugPrint('--- Rendered texts: $visibleTexts');

    expect(tester.takeException(), isNull, reason: 'no overflow/render errors');
    expect(find.text('Failed to load dashboard data'), findsNothing,
        reason: 'dashboard must load real data, not the error state');
    expect(find.text('فشل تحميل بيانات لوحة التحكم'), findsNothing,
        reason: 'dashboard must load real data, not the error state');

    // The nurse's real language preference (en/ar) is loaded live, so accept
    // either localization of the redesigned labels.
    void expectEither(String en, String ar) {
      final found = find.text(en).evaluate().isNotEmpty ||
          find.text(ar).evaluate().isNotEmpty;
      expect(found, isTrue, reason: 'expected "$en" or "$ar"');
    }

    // Quick action row with live statistics.
    expectEither('My Schedule', 'جدولي');
    expectEither('Requests', 'الطلبات');
    expectEither('Patients', 'المرضى');
    expectEither('Reports', 'التقارير');
    final statTexts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .where((t) => RegExp(r'^\d+ ').hasMatch(t))
        .toList();
    expect(statTexts.length, greaterThanOrEqualTo(4),
        reason: 'each quick action shows a "<count> <label>" stat: $statTexts');
    // Upcoming visits section.
    expectEither('Upcoming Visits', 'الزيارات القادمة');
    // Dashboard summary card with real counts and Quick View.
    expectEither("Today's Schedule", 'جدول اليوم');
    expectEither("Today's appointments", 'مواعيد اليوم');
    expectEither('Pending requests', 'طلبات معلقة');
    expectEither('Completed visits', 'زيارات مكتملة');
    expectEither('Quick View', 'عرض سريع');
    // Decorative motivation card is gone.
    expect(find.text('Great Job!'), findsNothing);
    expect(find.text('عمل رائع!'), findsNothing);
  });
}

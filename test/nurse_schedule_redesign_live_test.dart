// LIVE render verification of the redesigned nurse schedule screen.
// Requires the local backend on http://127.0.0.1:3000. Run with:
//   flutter test test/nurse_schedule_redesign_live_test.dart \
//     --dart-define=API_BASE_URL=http://127.0.0.1:3000
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/features/nurse/screens/nurse_schedule_screen.dart';
import 'package:carelink/shared/models/user.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    HttpOverrides.global = _RealHttpOverrides();
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final fontsDir = Directory.systemTemp.createTempSync('carelink_fonts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => fontsDir.path,
    );
  });

  testWidgets('LIVE: redesigned nurse schedule renders without overflow', (
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
      await tester.pumpWidget(
        MaterialApp(home: NurseScheduleScreen(user: user)),
      );
      await Future<void>.delayed(const Duration(seconds: 4));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .toList();
    debugPrint('--- Rendered texts: $texts');

    expect(tester.takeException(), isNull, reason: 'no overflow/render errors');
    // Header with subtitle.
    expect(find.text('My Schedule'), findsOneWidget);
    expect(find.text('Manage your appointments with ease'), findsOneWidget);
    // Week card: all 7 day numbers of the current week rendered.
    final weekStart = DateTime.now()
        .subtract(Duration(days: DateTime.now().weekday - 1));
    for (var i = 0; i < 7; i++) {
      final d = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      expect(find.text('${d.day}'), findsWidgets);
    }
    // Filter pills (scroll the horizontal strip to reach the last one).
    for (final label in ['All', 'Upcoming', 'In Progress', 'Completed']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.dragUntilVisible(
      find.text('Cancelled'),
      find.text('Upcoming'),
      const Offset(-120, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cancelled'), findsOneWidget);
    // Day summary row shows appointment count.
    expect(
      texts.any((t) => t.contains('appointment')),
      isTrue,
      reason: 'summary count visible',
    );
    // Content area: either the premium empty state or appointment cards.
    final hasEmptyState =
        find.text('No appointments for this day').evaluate().isNotEmpty;
    if (hasEmptyState) {
      expect(
        find.text('Enjoy your day — booked appointments will appear here.'),
        findsOneWidget,
      );
      expect(find.text('View upcoming days'), findsOneWidget);
    }
  });
}

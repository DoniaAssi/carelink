// LIVE render verification of the redesigned nurse earnings screen.
// Requires the local backend on http://127.0.0.1:3000. Run with:
//   flutter test test/nurse_earnings_redesign_live_test.dart \
//     --dart-define=API_BASE_URL=http://127.0.0.1:3000
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/features/nurse/screens/nurse_earnings_screen.dart';
import 'package:carelink/features/nurse/screens/nurse_ui.dart';
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

  testWidgets('LIVE: earnings screen renders with header actions, no garbage',
      (tester) async {
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
        MaterialApp(home: NurseEarningsScreen(user: user)),
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

    expect(tester.takeException(), isNull, reason: 'no render errors');

    // No mojibake anywhere on screen.
    final garbage =
        texts.where((t) => t.contains('Ø') || t.contains('â€')).toList();
    expect(garbage, isEmpty, reason: 'corrupted labels found: $garbage');

    // Title present (either locale).
    final title = find.text('Earnings & Payments').evaluate().isNotEmpty ||
        find.text('الأرباح والمدفوعات').evaluate().isNotEmpty;
    expect(title, isTrue);

    // No hamburger menu; Patient header actions (language + theme) present.
    expect(find.byIcon(Icons.menu_rounded), findsNothing);
    expect(find.byTooltip('Arabic'), findsWidgets);
    final themeToggle = find.byTooltip('Dark mode').evaluate().isNotEmpty ||
        find.byTooltip('Light mode').evaluate().isNotEmpty;
    expect(themeToggle, isTrue, reason: 'theme toggle present');
  });

  testWidgets('LIVE: earnings screen is fully Arabic when Arabic is selected',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.reset();
      NurseUi.isArabic.value = false;
      return tester.binding.setSurfaceSize(null);
    });

    NurseUi.isArabic.value = true;

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
        MaterialApp(home: NurseEarningsScreen(user: user)),
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
    debugPrint('--- Rendered (ar) texts: $texts');

    expect(tester.takeException(), isNull);

    // Key labels must be Arabic.
    for (final ar in [
      'الأرباح والمدفوعات',
      'سعر الساعة من الأدمن',
      'الرصيد المتاح (قيد الانتظار)',
      'إجمالي الجلسات',
      'إجمالي النقاط',
      'إجمالي الأرباح',
      'إجراءات سريعة',
      'طلب دفعة',
      'سجل الأرباح',
    ]) {
      expect(find.textContaining(ar), findsWidgets,
          reason: 'expected Arabic label "$ar"');
    }

    // No leftover English UI labels (dynamic backend values excluded).
    for (final en in [
      'Admin Hourly Rate',
      'Available Balance (Pending)',
      'Total Earnings',
      'Total Points',
      'Total Sessions',
      'Request Payout',
      'Ready',
      'Quick Actions',
      'Earnings History',
      'reviews',
      'ILS',
      'per hour',
    ]) {
      final hits =
          texts.where((t) => t.contains(en)).toList();
      expect(hits, isEmpty, reason: 'English label leaked: $hits');
    }

    // RTL is active.
    expect(
      Directionality.of(tester.element(find.byType(ListView).first)),
      TextDirection.rtl,
    );
  });
}

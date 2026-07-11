import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carelink/features/nurse/screens/nurse_dashboard.dart';
import 'package:carelink/shared/models/user.dart';

void main() {
  Future<void> pumpDashboard(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.reset();
      return tester.binding.setSurfaceSize(null);
    });

    final user = User(
      id: 1,
      serverUserId: 'test-nurse',
      email: 'nurse@test.dev',
      password: '',
      fullName: 'Nurse',
      phone: '',
      role: 'nurse',
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(MaterialApp(home: NurseDashboard(user: user)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('quick action grid does not overflow at reported size', (
    tester,
  ) async {
    // Size from the reported screenshot (4-column layout).
    await pumpDashboard(tester, const Size(627, 907));
    expect(tester.takeException(), isNull);
    expect(find.text('Schedule', findRichText: true), findsNothing);
  });

  testWidgets('quick action grid does not overflow on a narrow phone', (
    tester,
  ) async {
    await pumpDashboard(tester, const Size(360, 690));
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carelink/features/patient/screens/edit_profile_screen.dart';

void main() {
  testWidgets('edit profile renders the compact reference layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: EditProfileScreen(
          userId: 'patient-1',
          userData: {
            'fullName': 'Julia Diabetes',
            'email': 'juliadiabetes@gmail.com',
            'phone': '+972 599 789 328',
            'addressText': 'Birzeit, West Bank, Palestine',
            'dateOfBirth': '2008-06-27',
            'gender': 'female',
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Tap to change photo'), findsOneWidget);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Contact Information'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

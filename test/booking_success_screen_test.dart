import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carelink/features/patient/screens/booking_success_screen.dart';

void main() {
  testWidgets('renders safely when optional booking summary data is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BookingSuccessScreen(patientUserId: 'patient-test'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BookingSuccessScreen), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    expect(find.text('Not available'), findsWidgets);
    expect(find.text('Payment completed'), findsOneWidget);
    expect(find.text('Request sent'), findsOneWidget);
    expect(find.text('Waiting for approval'), findsOneWidget);
    expect(find.text('Appointment confirmed'), findsOneWidget);
    expect(find.text('Track booking request'), findsOneWidget);
  });
}
